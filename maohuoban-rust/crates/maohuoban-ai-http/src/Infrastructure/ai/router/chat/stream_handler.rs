use axum::{
    Json,
    extract::State,
    http::HeaderMap,
    response::{
        IntoResponse, Response,
        sse::{Event, KeepAlive, Sse},
    },
};
use chrono::Utc;
use futures_util::StreamExt;
use maohuoban_ai_application::ai::intent::AiIntentGate;
use maohuoban_ai_application::ai::ports::{AiRequestGateLog, AiToolAccessLog};
use maohuoban_ai_application::ai::runtime::{AgentRuntimeLoopEngine, AgentSession};
use maohuoban_ai_application::ai::stream::AiStreamRunContext;
use maohuoban_ai_application::ai::tools::AiToolContext;
use maohuoban_ai_domain::ai::{
    AgentId, AiFactPackage, AiGateDecision, AiIntent, AiPetDisplaySnapshot, AiPetResolution,
    AiStreamEvent, AiToolCallStatus,
};
use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};
use std::sync::Arc;
use uuid::Uuid;

use super::super::AiHttpState;
use super::super::auth::current_user_id;
use super::super::diagnostics::{
    record_chat_gate_decided, record_chat_provider_error, record_chat_provider_started,
    record_chat_stream_event_emitted, record_chat_stream_request_received,
};
use super::assistant_message_persistence::{
    AssistantMessagePersistRequest, persist_assistant_message,
};
use super::diet_confirmation_candidate_loader::load_diet_confirmation_candidate_package;
use super::diet_fact_loader::load_current_diet_fact_package;
use super::fact_package_merge::merge_fact_packages;
use super::food_inventory_hint_loader::load_food_inventory_hint_package;
use super::gated_stream_response::gated_stream_response;
use super::identity_fact_loader::load_identity_fact_package;
use super::llm_request::build_llm_request;
use super::pet_resolution_stream_response::pet_resolution_stream_response;
use super::request::ChatStreamRequest;
use super::runtime_stream::{AgentEventSseProjector, ai_error_to_sse_event};
use super::runtime_tools::build_runtime_tool_registry;
use super::session_persistence::{PetSessionContext, persist_session_and_user_message};
use super::title::build_title;
use crate::ai::response::unauthorized_response;

/// handle_chat_stream 流式聊天 SSE handler
/// 核心职责：
/// - 校验登录态并从 token 注入 actor
/// - 输出毛伙伴稳定 SSE 事件并持久化完成消息
pub async fn handle_chat_stream(
    State(state): State<AiHttpState>,
    headers: HeaderMap,
    Json(req): Json<ChatStreamRequest>,
) -> Response {
    let Ok(actor_user_id) = current_user_id(&state.auth, &headers).await else {
        return unauthorized_response();
    };

    let session_id = req.chat_session_id.unwrap_or_else(Uuid::new_v4);
    let message_id = Uuid::new_v4();
    let now = Utc::now();
    let title = build_title(&req.message);
    let gate_decision = AiIntentGate::new().classify(&req.message);
    record_stream_request_received(&req, actor_user_id, session_id);

    let pet_resolution =
        resolve_stream_target_pet(&state, &req, actor_user_id, &gate_decision).await;
    let resolved_pet_id = pet_resolution
        .as_ref()
        .and_then(AiPetResolution::resolved_pet_id);
    let target_pet = resolved_pet_snapshot(pet_resolution.as_ref());
    record_stream_gate_decided(&req, session_id, resolved_pet_id, &gate_decision);

    let pet_session_context = PetSessionContext {
        primary_pet_id: resolved_pet_id.or(req.selected_pet_id),
        pet_display_snapshot: target_pet.clone(),
    };
    persist_current_turn(
        &state,
        &req,
        actor_user_id,
        session_id,
        title.clone(),
        pet_session_context,
        now,
    )
    .await;

    insert_request_gate_log(
        &state.session_repository,
        &req,
        session_id,
        actor_user_id,
        resolved_pet_id,
        &gate_decision,
    )
    .await;

    let initial_events = load_pet_catalog_initial_events(
        &state.session_repository,
        session_id,
        actor_user_id,
        &gate_decision,
        resolved_pet_id,
        req.selected_pet_id,
        pet_resolution.as_ref(),
    )
    .await;

    if !gate_decision.enters_workbench() {
        return gated_stream_response(
            state.session_repository.clone(),
            session_id,
            message_id,
            title,
            &gate_decision,
        );
    }

    if let Some(resolution) = pet_resolution
        .as_ref()
        .filter(|resolution| !resolution.is_resolved())
    {
        return pet_resolution_stream_response(
            state.session_repository.clone(),
            session_id,
            message_id,
            title,
            resolution.clone(),
        );
    }

    provider_response_for_context(
        &state,
        &req,
        ProviderResponseInput {
            session_id,
            message_id,
            title,
            actor_user_id,
            target_pet,
            initial_events,
        },
    )
    .await
}

/// ProviderResponseInput Provider 响应构建输入
/// 核心职责：
/// - 承载 stream 主链路进入 Provider 分支所需上下文
/// - 控制 helper 参数数量并保持所有权边界清晰
struct ProviderResponseInput {
    session_id: Uuid,
    message_id: Uuid,
    title: String,
    actor_user_id: Uuid,
    target_pet: Option<AiPetDisplaySnapshot>,
    initial_events: Vec<AiStreamEvent>,
}

/// provider_response_for_context 构建 Provider SSE 响应
/// 核心职责：
/// - 加载事实包并记录 Provider 分支入口
/// - 将 LLM 请求交给 stream pipeline 生成稳定 SSE
async fn provider_response_for_context(
    state: &AiHttpState,
    req: &ChatStreamRequest,
    input: ProviderResponseInput,
) -> Response {
    let (fact_package, initial_events) = load_fact_context_and_initial_events(
        state,
        input.session_id,
        input.actor_user_id,
        input.target_pet.as_ref(),
        input.initial_events,
    )
    .await;

    record_provider_context_started(
        input.session_id,
        input.message_id,
        input.target_pet.as_ref(),
        &initial_events,
        fact_package.as_ref(),
    );

    let llm_request = build_llm_request(
        &req.message,
        input.target_pet.as_ref(),
        fact_package.as_ref(),
    );
    let stream_context = AiStreamRunContext {
        chat_session_id: input.session_id,
        message_id: input.message_id,
        title: input.title,
        target_pet: input.target_pet.clone(),
        initial_events,
        fact_package: fact_package.clone(),
    };
    let stream = match input.target_pet {
        Some(target_pet) => runtime_provider_stream(
            state,
            req,
            RuntimeProviderStreamInput {
                session_id: input.session_id,
                message_id: input.message_id,
                actor_user_id: input.actor_user_id,
                target_pet,
                fact_package,
                context: stream_context,
            },
        ),
        None => state
            .stream_pipeline
            .run_with_context(llm_request, stream_context),
    };

    provider_stream_response(
        stream,
        state.session_repository.clone(),
        input.session_id,
        input.message_id,
    )
}

/// RuntimeProviderStreamInput Runtime SSE 构建输入
/// 核心职责：
/// - 汇总 Agent Runtime 运行所需上下文
/// - 控制 runtime_provider_stream 参数数量
struct RuntimeProviderStreamInput {
    session_id: Uuid,
    message_id: Uuid,
    actor_user_id: Uuid,
    target_pet: AiPetDisplaySnapshot,
    fact_package: Option<AiFactPackage>,
    context: AiStreamRunContext,
}

/// runtime_provider_stream 通过自有 Agent Runtime 构建 SSE 流
/// 核心职责：
/// - 使用 AgentSession 驱动模型、工具和二次模型调用
/// - 将 Runtime 事件映射回现有 AiStreamEvent 协议
fn runtime_provider_stream(
    state: &AiHttpState,
    req: &ChatStreamRequest,
    input: RuntimeProviderStreamInput,
) -> futures_util::stream::BoxStream<'static, Result<AiStreamEvent, maohuoban_ai_domain::ai::AiError>>
{
    let provider = state.llm_provider.clone();
    let registry = Arc::new(build_runtime_tool_registry(
        state,
        input.session_id,
        &input.target_pet,
    ));
    let tool_context = AiToolContext {
        actor_user_id: input.actor_user_id,
        authorized_pet_id: input.target_pet.pet_id,
    };
    let engine =
        AgentRuntimeLoopEngine::new(provider, registry, tool_context, input.fact_package.clone());
    let session = AgentSession::new(
        input.session_id,
        AgentId::main_pet_care_agent(),
        req.surface,
        engine,
    );
    let user_message = req.message.clone();
    let message_id = input.message_id;
    let fact_package = input.fact_package;
    let context = input.context;

    async_stream::stream! {
        let AiStreamRunContext {
            chat_session_id,
            message_id: started_message_id,
            title,
            target_pet,
            initial_events,
            ..
        } = context;
        let activity_pet_name = target_pet
            .as_ref()
            .map_or_else(|| "宠物".to_owned(), |pet| pet.pet_name.clone());

        yield Ok(AiStreamEvent::MessageStarted {
            chat_session_id,
            message_id: started_message_id,
            target_pet,
            title,
        });

        for event in initial_events {
            yield Ok(event);
        }

        let mut projector = AgentEventSseProjector::new(message_id, fact_package, &activity_pet_name);
        let mut agent_stream = session.into_prompt_stream(user_message);
        while let Some(result) = agent_stream.next().await {
            match result {
                Ok(agent_event) => {
                    for event in projector.project(agent_event) {
                        yield Ok(event);
                    }
                }
                Err(error) => {
                    yield Ok(ai_error_to_sse_event(&error));
                    break;
                }
            }
        }
    }
    .boxed()
}

/// persist_current_turn 持久化当前 stream 轮次
/// 核心职责：
/// - 保存会话、用户消息和宠物展示快照
/// - 保持 handler 主流程聚焦分支编排
async fn persist_current_turn(
    state: &AiHttpState,
    req: &ChatStreamRequest,
    actor_user_id: Uuid,
    session_id: Uuid,
    title: String,
    pet_context: PetSessionContext,
    now: chrono::DateTime<Utc>,
) {
    persist_session_and_user_message(
        &state.session_repository,
        req,
        actor_user_id,
        session_id,
        title,
        pet_context,
        now,
    )
    .await;
}

/// record_stream_request_received 记录 stream 请求入口观测
/// 核心职责：
/// - 从请求体提取脱敏诊断字段
/// - 保持主 handler 聚焦链路编排
fn record_stream_request_received(req: &ChatStreamRequest, actor_user_id: Uuid, session_id: Uuid) {
    record_chat_stream_request_received(
        actor_user_id,
        session_id,
        req.selected_pet_id,
        req.surface,
        &req.message,
    );
}

/// record_stream_gate_decided 记录 stream gate 决策观测
/// 核心职责：
/// - 关联会话、选择宠物和解析宠物
/// - 保持 gate 诊断字段集中构造
fn record_stream_gate_decided(
    req: &ChatStreamRequest,
    session_id: Uuid,
    resolved_pet_id: Option<Uuid>,
    gate_decision: &AiGateDecision,
) {
    record_chat_gate_decided(
        session_id,
        req.selected_pet_id,
        resolved_pet_id,
        gate_decision,
    );
}

/// record_provider_context_started 记录 Provider 分支上下文状态
/// 核心职责：
/// - 在进入 Provider 前记录事实包和初始事件状态
/// - 为 provider 错误和 SSE 输出提供前置证据
fn record_provider_context_started(
    session_id: Uuid,
    message_id: Uuid,
    target_pet: Option<&AiPetDisplaySnapshot>,
    initial_events: &[AiStreamEvent],
    fact_package: Option<&AiFactPackage>,
) {
    record_chat_provider_started(
        session_id,
        message_id,
        target_pet.is_some(),
        initial_events.len(),
        fact_package.is_some(),
    );
}

/// load_fact_context_and_initial_events 加载事实上下文并拼接初始事件
/// 核心职责：
/// - 依次加载身份事实和当前饮食事实
/// - 合并工具事件，保持 Provider 前的上下文准备集中
pub(super) async fn load_fact_context_and_initial_events(
    state: &AiHttpState,
    session_id: Uuid,
    actor_user_id: Uuid,
    target_pet: Option<&AiPetDisplaySnapshot>,
    mut initial_events: Vec<AiStreamEvent>,
) -> (Option<AiFactPackage>, Vec<AiStreamEvent>) {
    let (identity_fact_package, identity_events) =
        load_identity_fact_package(state, session_id, actor_user_id, target_pet).await;
    let (diet_fact_package, diet_events) =
        load_current_diet_fact_package(state, session_id, actor_user_id, target_pet).await;
    let (food_inventory_hint_package, food_inventory_hint_events) =
        load_food_inventory_hint_package(state, session_id, actor_user_id, target_pet).await;
    let (diet_confirmation_candidate_package, diet_confirmation_candidate_events) =
        load_diet_confirmation_candidate_package(state, session_id, actor_user_id, target_pet)
            .await;
    initial_events.extend(identity_events);
    initial_events.extend(diet_events);
    initial_events.extend(food_inventory_hint_events);
    initial_events.extend(diet_confirmation_candidate_events);

    (
        merge_fact_packages(
            merge_fact_packages(identity_fact_package, diet_fact_package),
            merge_fact_packages(
                food_inventory_hint_package,
                diet_confirmation_candidate_package,
            ),
        ),
        initial_events,
    )
}

/// resolve_stream_target_pet 解析流式请求目标宠物
/// 核心职责：
/// - 只在 gate 要求加载上下文时调用后端授权宠物解析器
/// - 将解析失败降级为无宠物上下文，保持 SSE 主链路可返回安全响应
pub(super) async fn resolve_stream_target_pet(
    state: &AiHttpState,
    req: &ChatStreamRequest,
    actor_user_id: Uuid,
    gate_decision: &AiGateDecision,
) -> Option<AiPetResolution> {
    if gate_decision.context_loaded {
        state
            .pet_resolver
            .resolve(&req.message, req.selected_pet_id, actor_user_id)
            .await
            .ok()
    } else {
        None
    }
}

/// load_pet_catalog_initial_events 加载宠物候选工具初始事件
/// 核心职责：
/// - 只在需要上下文的请求中记录宠物候选工具审计
/// - 返回可在 message_started 后输出的 tool_call 事件
pub(super) async fn load_pet_catalog_initial_events(
    session_repo: &std::sync::Arc<dyn maohuoban_ai_application::ai::ports::AiSessionRepository>,
    session_id: Uuid,
    actor_user_id: Uuid,
    gate_decision: &AiGateDecision,
    resolved_pet_id: Option<Uuid>,
    selected_pet_id: Option<Uuid>,
    pet_resolution: Option<&AiPetResolution>,
) -> Vec<AiStreamEvent> {
    if gate_decision.context_loaded {
        insert_pet_catalog_tool_log(
            session_repo,
            session_id,
            actor_user_id,
            resolved_pet_id,
            selected_pet_id,
            pet_resolution,
        )
        .await
    } else {
        Vec::new()
    }
}

/// insert_request_gate_log 写入请求 gate 审计
/// 核心职责：
/// - 持久化意图、上下文加载状态和宠物解析结果
/// - 避免在主 handler 中展开审计表字段细节
pub(super) async fn insert_request_gate_log(
    session_repo: &std::sync::Arc<dyn maohuoban_ai_application::ai::ports::AiSessionRepository>,
    req: &ChatStreamRequest,
    session_id: Uuid,
    actor_user_id: Uuid,
    resolved_pet_id: Option<Uuid>,
    gate_decision: &AiGateDecision,
) {
    let _ = session_repo
        .insert_request_gate_log(&AiRequestGateLog {
            session_id: Some(session_id),
            actor_user_id,
            intent: intent_code(gate_decision.intent).to_owned(),
            gate_decision: gate_decision_code(gate_decision).to_owned(),
            context_loaded: gate_decision.context_loaded,
            request_hash: request_hash(&req.message),
            resolved_pet_id,
            selected_pet_id: req.selected_pet_id,
            risk_signal: gate_decision.risk_signal.clone(),
            estimated_input_tokens: i32::try_from(req.message.chars().count()).unwrap_or(i32::MAX),
        })
        .await;
}

/// insert_pet_catalog_tool_log 写入授权宠物候选工具审计
/// 核心职责：
/// - 记录 list_authorized_pet_candidates 工具读取
/// - 为解析成功的请求返回 tool_call 初始事件
async fn insert_pet_catalog_tool_log(
    session_repo: &std::sync::Arc<dyn maohuoban_ai_application::ai::ports::AiSessionRepository>,
    session_id: Uuid,
    actor_user_id: Uuid,
    resolved_pet_id: Option<Uuid>,
    selected_pet_id: Option<Uuid>,
    pet_resolution: Option<&AiPetResolution>,
) -> Vec<AiStreamEvent> {
    let allowed = pet_resolution.is_some_and(AiPetResolution::is_resolved);
    let target_pet_id = resolved_pet_id.or(selected_pet_id);
    let returned_ref_ids = if allowed {
        target_pet_id
            .map(|id| vec![id.to_string()])
            .unwrap_or_default()
    } else {
        vec![]
    };
    let denied_reason = pet_resolution.and_then(pet_resolution_denied_reason);

    let _ = session_repo
        .insert_tool_access_log(&AiToolAccessLog {
            session_id: Some(session_id),
            actor_user_id,
            tool_name: "list_authorized_pet_candidates".to_owned(),
            requested_scope: "actor_pet_candidates".to_owned(),
            target_pet_id,
            allowed,
            denied_reason,
            returned_ref_ids,
            duration_ms: 0,
            risk_signal: None,
        })
        .await;

    if allowed {
        vec![AiStreamEvent::ToolCall {
            tool_name: "list_authorized_pet_candidates".to_owned(),
            status: AiToolCallStatus::Allowed,
            citation_count: 0,
        }]
    } else {
        Vec::new()
    }
}

/// pet_resolution_denied_reason 返回工具审计拒绝原因
/// 核心职责：
/// - 使用稳定原因码记录解析未完成原因
fn pet_resolution_denied_reason(resolution: &AiPetResolution) -> Option<String> {
    match resolution {
        AiPetResolution::Resolved { .. } => None,
        AiPetResolution::NeedsSelection { .. } => Some("needs_pet_selection".to_owned()),
        AiPetResolution::UnauthorizedOrNotFound => Some("unauthorized_or_not_found".to_owned()),
        AiPetResolution::NoPetContext => Some("no_pet_context".to_owned()),
    }
}

/// provider_stream_response 构建 Provider 流式响应
/// 核心职责：
/// - 将 AiStreamEvent 转换为 SSE Event
/// - 在 message_completed 时持久化助手消息
fn provider_stream_response<S>(
    stream: S,
    session_repo: std::sync::Arc<dyn maohuoban_ai_application::ai::ports::AiSessionRepository>,
    session_id: Uuid,
    message_id: Uuid,
) -> Response
where
    S: futures_util::Stream<Item = Result<AiStreamEvent, maohuoban_ai_domain::ai::AiError>>
        + Send
        + 'static,
{
    let sse_stream = stream.then(move |result| {
        let session_repo = session_repo.clone();
        async move {
            let event = match result {
                Ok(e) => e,
                Err(err) => AiStreamEvent::Error {
                    code: err.stable_code().to_owned(),
                    message: err.user_visible_message().to_owned(),
                    retryable: err.is_retryable(),
                    blocked_reason: None,
                    safe_fallback_text: Some("暂时无法获取回答，请稍后重试。".to_owned()),
                },
            };

            if let AiStreamEvent::Error {
                code,
                retryable,
                safe_fallback_text,
                ..
            } = &event
            {
                record_chat_provider_error(
                    session_id,
                    code,
                    *retryable,
                    safe_fallback_text.as_deref(),
                );
            }

            if let AiStreamEvent::MessageCompleted {
                final_text,
                usage,
                finish_reason,
                citations,
                ..
            } = &event
            {
                persist_assistant_message(
                    &session_repo,
                    AssistantMessagePersistRequest::new(
                        message_id,
                        session_id,
                        final_text.clone(),
                        citations.clone(),
                        usage.input_tokens,
                        usage.output_tokens,
                        format!("{finish_reason:?}"),
                    ),
                )
                .await;
            }

            if let AiStreamEvent::ProposedAction { action } = &event {
                let repo = session_repo.clone();
                let mut action = action.clone();
                if action.source_message_id.is_none() {
                    action.source_message_id = Some(message_id);
                }
                tokio::spawn(async move {
                    let _ = repo.insert_proposed_action(session_id, &action).await;
                });
            }

            record_chat_stream_event_emitted(session_id, &event);
            let json = serde_json::to_string(&event).unwrap_or_else(|_| "{}".to_owned());
            Ok::<Event, std::convert::Infallible>(
                Event::default().event(event.event_name()).data(json),
            )
        }
    });

    Sse::new(sse_stream)
        .keep_alive(KeepAlive::default())
        .into_response()
}

/// resolved_pet_snapshot 提取已解析宠物快照
/// 核心职责：
/// - 只在 AiPetResolution::Resolved 时返回后端宠物展示快照
pub(super) fn resolved_pet_snapshot(
    pet_resolution: Option<&AiPetResolution>,
) -> Option<AiPetDisplaySnapshot> {
    match pet_resolution {
        Some(AiPetResolution::Resolved { snapshot, .. }) => Some(snapshot.clone()),
        _ => None,
    }
}

/// intent_code 返回审计用意图编码
/// 核心职责：
/// - 使用稳定 snake_case 字符串写入审计表
fn intent_code(intent: AiIntent) -> &'static str {
    match intent {
        AiIntent::PetCare => "pet_care",
        AiIntent::PetRecordQuery => "pet_record_query",
        AiIntent::PetFood => "pet_food",
        AiIntent::PetHealthRisk => "pet_health_risk",
        AiIntent::EmotionalPetContext => "emotional_pet_context",
        AiIntent::AppSupport => "app_support",
        AiIntent::OffTopic => "off_topic",
        AiIntent::PromptInjection => "prompt_injection",
        AiIntent::CostAbuse => "cost_abuse",
    }
}

/// gate_decision_code 返回审计用 gate 决策编码
/// 核心职责：
/// - 区分加载上下文、跳过主 Agent 和安全阻断
fn gate_decision_code(gate_decision: &AiGateDecision) -> &'static str {
    if !gate_decision.enters_workbench() {
        "blocked"
    } else if gate_decision.context_loaded {
        "load_context"
    } else {
        "enter_workbench"
    }
}

/// request_hash 生成审计用请求哈希
/// 核心职责：
/// - 避免审计表保存完整用户原文
fn request_hash(message: &str) -> String {
    let mut hasher = DefaultHasher::new();
    message.hash(&mut hasher);
    format!("{:016x}", hasher.finish())
}
