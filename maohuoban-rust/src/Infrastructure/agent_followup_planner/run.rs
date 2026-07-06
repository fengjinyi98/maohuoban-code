use std::sync::Arc;

use chrono::{DateTime, Utc};
use maohuoban_ai_application::ai::ports::{
    AiSessionRepository, ObservationWriteContext, SessionTurnRepository,
};
use maohuoban_ai_application::ai::runtime::{
    AgentRuntimeEngineFactory, AgentRuntimeEngineInput, AgentRuntimeEngineMode, AgentSession,
};
use maohuoban_ai_application::ai::tools::{
    AiToolContext, ToolGatewayExecutionContext, ToolRegistry,
};
use maohuoban_ai_application::ai::turn_context::TurnContextBuilder;
use maohuoban_ai_domain::ai::{
    AgentId, AgentTurnId, AiChatSession, AiChatSessionContextStatus, AiChatSessionStatus,
    AiChatSessionVisibility, AiConversationSurface, AiMessage, AiMessageRole, AiMessageStatus,
    AiPetDisplaySnapshot, AiSessionTurn, AiSessionTurnStatus,
};
use maohuoban_ai_infrastructure::provider::LlmProviderRegistryConfig;
use maohuoban_ai_infrastructure::repository::{
    PostgresAiSessionRepository, PostgresChatTurnTransaction, PostgresSessionTurnRepository,
};
use maohuoban_pet_application::pet::PetService;
use maohuoban_pet_infrastructure::postgres::{
    PostgresAgentConfirmationTaskRepository, PostgresDietRepository,
    PostgresFoodInventoryRepository, PostgresPetAlbumRepository, PostgresPetRepository,
};
use sqlx::{PgPool, Row};
use uuid::Uuid;

use super::{AgentFollowupPlannerError, AgentFollowupPlannerRunResult};
use crate::infrastructure::ai::{
    PetServiceAbnormalEpisodeFactProvider, PetServiceAbnormalFollowupPlanProvider,
    PetServiceAuthorizedPetCatalog, PetServiceDietConfirmationCandidateProvider,
    PetServiceDietFactProvider, PetServiceFoodInventoryHintProvider,
    PetServiceHealthQuickFactProvider, PetServiceIdentityFactProvider,
    PetServiceObservationWriteProvider, build_ai_llm_provider_from_provider_config,
};
use maohuoban_ai_http::ai::router::{
    AiPetContextProviderParts, AiPetContextProviders, build_ai_runtime_tool_registry,
};

/// `AgentFollowupPlannerConfig` 异常主动追踪规划配置
/// 核心职责：
/// - 承载后台 planner 运行所需模型 provider 与 Runtime 模式
/// - 避免 planner 直接读取环境变量
#[derive(Clone)]
pub struct AgentFollowupPlannerConfig {
    pub ai_llm_provider_config: LlmProviderRegistryConfig,
    pub runtime_engine_mode: AgentRuntimeEngineMode,
}

struct PlanningTarget {
    followup_id: Uuid,
    pet_id: Uuid,
    episode_id: Uuid,
    actor_user_id: Uuid,
    pet_name: String,
    species: String,
    profile_number: String,
}

struct PlannerRuntimeContext {
    pet_service: Arc<PetService>,
    providers: AiPetContextProviders,
    session_repository: Arc<PostgresAiSessionRepository>,
    session_turn_repository: Arc<PostgresSessionTurnRepository>,
    llm_provider: Arc<dyn maohuoban_ai_application::ai::ports::LlmProvider>,
}

struct PlannerTurnIngress<'a> {
    session_id: Uuid,
    turn_id: AgentTurnId,
    message_id: Uuid,
    prompt: &'a str,
    now_at: DateTime<Utc>,
}

/// `run_once` 执行一次 Agent 主动追踪动态规划
/// 核心职责：
/// - 领取一条待规划 abnormal episode followup
/// - 使用现有 Agent Runtime、tool schema 和保存计划 tool 生成 scheduled plan
///
/// # Errors
/// 当数据库读取、Runtime 执行或 tool 保存失败时返回错误。
pub async fn run_once(
    config: AgentFollowupPlannerConfig,
    pool: PgPool,
    now_at: DateTime<Utc>,
) -> Result<AgentFollowupPlannerRunResult, AgentFollowupPlannerError> {
    let Some(target) = load_next_planning_target(&pool).await? else {
        return Ok(AgentFollowupPlannerRunResult { planned_count: 0 });
    };
    let runtime_context = build_planner_runtime_context(&config, &pool);
    let session_id =
        ensure_planning_session(runtime_context.session_repository.as_ref(), &target, now_at)
            .await?;
    let target_pet = AiPetDisplaySnapshot {
        pet_id: target.pet_id,
        pet_name: target.pet_name.clone(),
        pet_avatar_url: None,
        pet_species: target.species.clone(),
        profile_number: target.profile_number.clone(),
    };
    let registry = Arc::new(build_planner_tool_registry(
        &config,
        &pool,
        &runtime_context,
        session_id,
        &target_pet,
    ));
    let turn_id = AgentTurnId::new();
    let message_id = Uuid::new_v4();
    let prompt = planner_prompt(&target, now_at);
    persist_planner_turn_ingress(
        runtime_context.session_repository.as_ref(),
        runtime_context.session_turn_repository.as_ref(),
        &target,
        PlannerTurnIngress {
            session_id,
            turn_id,
            message_id,
            prompt: &prompt,
            now_at,
        },
    )
    .await?;
    let observation_write_context = ObservationWriteContext {
        chat_context_kind: Some("abnormal_episode_followup".to_owned()),
        abnormal_episode_id: Some(target.episode_id),
        source_hint_id: None,
        agent_followup_id: Some(target.followup_id),
        source_turn_id: Some(turn_id.as_uuid()),
    };
    let tool_context = AiToolContext {
        actor_user_id: target.actor_user_id,
        authorized_pet_id: target.pet_id,
        gateway_context: ToolGatewayExecutionContext {
            session_id: Some(session_id),
            turn_id: Some(turn_id.as_uuid()),
            message_id: Some(message_id),
            confirmation_task_id: None,
        },
        observation_write_context,
        gateway_observer: None,
    };
    let engine =
        AgentRuntimeEngineFactory::new(config.runtime_engine_mode).build(AgentRuntimeEngineInput {
            provider: runtime_context.llm_provider,
            registry,
            tool_context,
            fact_package: None,
        });
    let mut session = AgentSession::new(
        session_id,
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );
    let _events = session
        .prompt_with_workbench_turn_and_diagnostics_message_id(
            prompt,
            TurnContextBuilder::new(AiConversationSurface::HomePrivate)
                .with_target_pet(Some(target_pet))
                .build(),
            turn_id,
            message_id,
        )
        .await?;
    runtime_context
        .session_turn_repository
        .update_turn_status(
            turn_id.as_uuid(),
            AiSessionTurnStatus::Completed,
            None,
            Some("planner_completed"),
            None,
            None,
        )
        .await?;

    Ok(AgentFollowupPlannerRunResult { planned_count: 1 })
}

fn build_planner_runtime_context(
    config: &AgentFollowupPlannerConfig,
    pool: &PgPool,
) -> PlannerRuntimeContext {
    let pet_service = build_pet_service(pool);
    let providers = build_context_providers(&pet_service, pool);
    PlannerRuntimeContext {
        pet_service,
        providers,
        session_repository: Arc::new(PostgresAiSessionRepository::new(pool.clone())),
        session_turn_repository: Arc::new(PostgresSessionTurnRepository::new(pool.clone())),
        llm_provider: build_ai_llm_provider_from_provider_config(&config.ai_llm_provider_config),
    }
}

fn build_planner_tool_registry(
    config: &AgentFollowupPlannerConfig,
    pool: &PgPool,
    runtime_context: &PlannerRuntimeContext,
    session_id: Uuid,
    target_pet: &AiPetDisplaySnapshot,
) -> ToolRegistry {
    build_ai_runtime_tool_registry(
        &maohuoban_ai_http::ai::router::AiHttpState {
            llm_provider: runtime_context.llm_provider.clone(),
            runtime_engine_mode: config.runtime_engine_mode,
            session_repository: runtime_context.session_repository.clone(),
            session_turn_repository: runtime_context.session_turn_repository.clone(),
            chat_turn_transaction: Arc::new(PostgresChatTurnTransaction::new(pool.clone())),
            session_summary_repository: Arc::new(
                maohuoban_ai_infrastructure::repository::PostgresSessionSummaryRepository::new(
                    pool.clone(),
                ),
            ),
            memory_repository: Arc::new(
                maohuoban_ai_infrastructure::repository::PostgresMemoryRepository::new(
                    pool.clone(),
                ),
            ),
            pet_resolver: Arc::new(
                maohuoban_ai_application::ai::pet_resolver::AiPetResolver::new(
                    PetServiceAuthorizedPetCatalog::new(runtime_context.pet_service.clone()),
                ),
            ),
            pet_context_providers: runtime_context.providers.clone(),
            observation_write_provider: runtime_context
                .providers
                .observation_write_provider
                .clone(),
        },
        session_id,
        target_pet,
    )
}

async fn persist_planner_turn_ingress(
    session_repository: &PostgresAiSessionRepository,
    session_turn_repository: &PostgresSessionTurnRepository,
    target: &PlanningTarget,
    ingress: PlannerTurnIngress<'_>,
) -> Result<(), AgentFollowupPlannerError> {
    let user_message = AiMessage {
        id: ingress.message_id,
        session_id: ingress.session_id,
        turn_id: None,
        role: AiMessageRole::System,
        content: ingress.prompt.to_owned(),
        content_blocks: Vec::new(),
        status: AiMessageStatus::Completed,
        citations: vec![],
        model: None,
        provider: None,
        finish_reason: None,
        usage_input_tokens: None,
        usage_output_tokens: None,
        verification: None,
        created_at: ingress.now_at,
    };
    session_repository.insert_message(&user_message).await?;

    let turn = AiSessionTurn {
        id: ingress.turn_id.as_uuid(),
        session_id: ingress.session_id,
        actor_user_id: target.actor_user_id,
        user_message_id: ingress.message_id,
        assistant_message_id: None,
        intent: "abnormal_episode_followup_planning".to_owned(),
        gate_decision: "allow".to_owned(),
        resolved_pet_id: Some(target.pet_id),
        engine_mode: "self_hosted".to_owned(),
        surface: AiConversationSurface::HomePrivate,
        status: AiSessionTurnStatus::Running,
        finish_reason: None,
        error_code: None,
        retryable: None,
        started_at: ingress.now_at,
        finished_at: None,
    };
    session_turn_repository.insert_turn(&turn).await?;
    session_repository
        .update_message_turn_id(ingress.message_id, ingress.turn_id.as_uuid())
        .await?;

    Ok(())
}

async fn load_next_planning_target(
    pool: &PgPool,
) -> Result<Option<PlanningTarget>, AgentFollowupPlannerError> {
    let row = sqlx::query(
        r"
        SELECT f.id AS followup_id,
               f.pet_id,
               f.episode_id,
               p.owner_user_id AS actor_user_id,
               p.name AS pet_name,
               p.species,
               p.profile_number
        FROM agent_proactive_followups f
        JOIN pet_profiles p ON p.id = f.pet_id
        WHERE f.status = 'planning'
        ORDER BY f.created_at ASC
        LIMIT 1
        ",
    )
    .fetch_optional(pool)
    .await?;

    Ok(row.map(|row| PlanningTarget {
        followup_id: row.get("followup_id"),
        pet_id: row.get("pet_id"),
        episode_id: row.get("episode_id"),
        actor_user_id: row.get("actor_user_id"),
        pet_name: row.get("pet_name"),
        species: row.get("species"),
        profile_number: row.get("profile_number"),
    }))
}

fn build_pet_service(pool: &PgPool) -> Arc<PetService> {
    let pet_repository = PostgresPetRepository::new(pool.clone());
    Arc::new(PetService::new(
        Arc::new(pet_repository.clone()),
        Arc::new(PostgresPetAlbumRepository::new(pool.clone())),
        Arc::new(pet_repository),
        Arc::new(PostgresFoodInventoryRepository::new(pool.clone())),
        Arc::new(PostgresDietRepository::new(pool.clone())),
    ))
}

fn build_context_providers(pet_service: &Arc<PetService>, pool: &PgPool) -> AiPetContextProviders {
    let confirmation_tasks = Arc::new(PostgresAgentConfirmationTaskRepository::new(pool.clone()));
    AiPetContextProviders::new(AiPetContextProviderParts {
        identity_fact_provider: Arc::new(PetServiceIdentityFactProvider::new(pet_service.clone())),
        abnormal_episode_fact_provider: Arc::new(PetServiceAbnormalEpisodeFactProvider::new(
            pet_service.clone(),
        )),
        diet_fact_provider: Arc::new(PetServiceDietFactProvider::new(pet_service.clone())),
        health_quick_fact_provider: Arc::new(PetServiceHealthQuickFactProvider::new(
            pet_service.clone(),
        )),
        food_inventory_hint_provider: Arc::new(PetServiceFoodInventoryHintProvider::new(
            pet_service.clone(),
        )),
        diet_confirmation_candidate_provider: Arc::new(
            PetServiceDietConfirmationCandidateProvider::new(pet_service.clone()),
        ),
        observation_write_provider: Arc::new(PetServiceObservationWriteProvider::new(
            pet_service.clone(),
            confirmation_tasks,
        )),
        abnormal_followup_plan_provider: Arc::new(PetServiceAbnormalFollowupPlanProvider::new(
            pet_service.clone(),
        )),
    })
}

async fn ensure_planning_session(
    session_repository: &PostgresAiSessionRepository,
    target: &PlanningTarget,
    now_at: DateTime<Utc>,
) -> Result<Uuid, AgentFollowupPlannerError> {
    if let Some(session) = maohuoban_ai_application::ai::ports::AiSessionRepository::find_active_abnormal_episode_session(
        session_repository,
        target.actor_user_id,
        target.episode_id,
    )
    .await?
    {
        return Ok(session.id);
    }
    let session_id = Uuid::new_v4();
    maohuoban_ai_application::ai::ports::AiSessionRepository::upsert_session(
        session_repository,
        &AiChatSession {
            id: session_id,
            actor_user_id: target.actor_user_id,
            primary_pet_id: Some(target.pet_id),
            surface: AiConversationSurface::HomePrivate,
            source_hint_id: None,
            source_task_id: None,
            chat_context_kind: Some("abnormal_episode_followup".to_owned()),
            abnormal_episode_id: Some(target.episode_id),
            agent_followup_id: Some(target.followup_id),
            title: format!("{}的异常追踪", target.pet_name),
            is_pinned: false,
            pet_display_snapshot: Some(AiPetDisplaySnapshot {
                pet_id: target.pet_id,
                pet_name: target.pet_name.clone(),
                pet_avatar_url: None,
                pet_species: target.species.clone(),
                profile_number: target.profile_number.clone(),
            }),
            status: AiChatSessionStatus::Active,
            session_visibility: AiChatSessionVisibility::Background,
            context_status: AiChatSessionContextStatus::Active,
            activated_at: None,
            created_at: now_at,
            updated_at: now_at,
        },
    )
    .await?;
    Ok(session_id)
}

fn planner_prompt(target: &PlanningTarget, now_at: DateTime<Utc>) -> String {
    format!(
        "异常主动追踪 planning：请为宠物 {} 的异常 episode {} 生成下一次站内轻提醒计划。当前时间 {}。必须先读取异常 episode、近期便便/精神/食欲、当前饮食和储物柜线索；然后调用 save_abnormal_episode_followup_plan 保存 due_at、message_title、message_body、rationale 和 recommended_actions。",
        target.pet_name,
        target.episode_id,
        now_at.to_rfc3339()
    )
}
