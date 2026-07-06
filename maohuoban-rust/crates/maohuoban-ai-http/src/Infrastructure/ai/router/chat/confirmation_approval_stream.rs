use std::sync::Arc;

use axum::{
    Json,
    extract::{Path, State},
    response::Response,
};
use chrono::Utc;
use maohuoban_ai_application::ai::ports::{
    HomeAttentionHintRealtimeEvent, HomeAttentionHintRealtimeEventKind, HomeTimelineRealtimeEvent,
    ObservationWriteContext,
};
use maohuoban_ai_application::ai::stream::AiStreamRunContext;
use maohuoban_ai_domain::ai::{
    AgentTurnId, AiChatSession, AiConversationSurface, AiError, AiMessage, AiMessageRole,
    AiMessageStatus, AiPetDisplaySnapshot, AiSessionTurn, AiSessionTurnStatus,
};
use maohuoban_auth_http::auth::extractor::AuthenticatedUser;
use maohuoban_pet_domain::pet::{ConfirmationTaskKind, ConfirmationTaskStatus};
use serde::Deserialize;
use uuid::Uuid;

use super::super::AiHttpState;
use super::composition::request::ChatStreamRequest;
use super::composition::workbench_builder::{
    build_agent_session_workbench, load_memory_entries_for_workbench,
};
use super::loaders::history_summary_loader::load_history_and_summary;
use super::persistence::finalizer_store::HttpFinalizerStore;
use super::responses::stream_response::agent_stream_response;
use super::runtime_stream_bridge::{RuntimeAgentStreamInput, runtime_agent_stream};
use crate::ai::response::ai_error_response;

/// ApproveConfirmationTaskStreamRequest 确认写入流式请求
/// 核心职责：
/// - 承接用户授权按钮，不承载聊天消息内容
/// - 预留 surface 供客户端声明入口，默认沿用私域首页
#[derive(Debug, Clone, Deserialize)]
pub(crate) struct ApproveConfirmationTaskStreamRequest {
    #[serde(default)]
    pub surface: Option<AiConversationSurface>,
}

/// handle_approve_confirmation_task_stream 确认写入后续跑 Agent
/// 核心职责：
/// - 将用户确认建模为授权命令并提交观察记录
/// - 使用同一异常追踪会话启动内部 turn，让 Agent 基于写入结果回复
pub async fn handle_approve_confirmation_task_stream(
    State(state): State<AiHttpState>,
    actor: AuthenticatedUser,
    Path(confirmation_task_id): Path<Uuid>,
    Json(req): Json<ApproveConfirmationTaskStreamRequest>,
) -> Response {
    let actor_user_id = actor.user_id();
    let command_context = match prepare_approval_command_context(
        &state,
        actor_user_id,
        confirmation_task_id,
        req.surface,
    )
    .await
    {
        Ok(context) => context,
        Err(error) => return ai_error_response(&error),
    };

    publish_resolved_attention_hint_events(&state, actor_user_id, &command_context).await;
    publish_timeline_changed_event(&state, actor_user_id, &command_context).await;
    let session = command_context.session;
    let surface = command_context.surface;
    let turn_id = AgentTurnId::new();
    let system_message_id = Uuid::new_v4();
    let assistant_message_id = Uuid::new_v4();
    let now = Utc::now();
    let internal_prompt = approval_followup_prompt(
        command_context.approval_kind,
        confirmation_task_id,
        command_context.committed_event_id,
        command_context.episode_id,
        command_context.agent_followup_id,
        command_context.next_followup_due_at,
        &command_context.candidate_payload,
    );

    if let Err(error) = persist_internal_approval_turn(
        &state,
        InternalApprovalTurnInput {
            session_id: session.id,
            actor_user_id,
            pet_id: command_context.pet_id,
            turn_id,
            system_message_id,
            surface,
            content: internal_prompt.clone(),
            now,
        },
    )
    .await
    {
        return ai_error_response(&error);
    }

    let target_pet = match session.pet_display_snapshot.clone() {
        Some(snapshot) => Some(snapshot),
        None => authorized_pet_snapshot(&state, actor_user_id, command_context.pet_id).await,
    };
    let Some(target_pet) = target_pet else {
        return ai_error_response(&AiError::Unauthorized);
    };

    let runtime_input = match build_approval_runtime_input(
        &state,
        ApprovalRuntimeBuildInput {
            session: &session,
            actor_user_id,
            pet_id: command_context.pet_id,
            target_pet,
            surface,
            turn_id,
            assistant_message_id,
            system_message_id,
            confirmation_task_id,
            internal_prompt,
        },
    )
    .await
    {
        Ok(result) => result,
        Err(error) => return ai_error_response(&error),
    };
    let stream = runtime_agent_stream(
        &state,
        &runtime_input.stream_req,
        runtime_input.stream_input,
    );

    agent_stream_response(
        stream,
        Arc::new(HttpFinalizerStore::from_state(&state)),
        session.id,
        actor_user_id,
        runtime_input.assistant_message_id,
        runtime_input.turn_id.as_uuid(),
        state.runtime_engine_mode.as_str(),
    )
}

async fn publish_resolved_attention_hint_events(
    state: &AiHttpState,
    actor_user_id: Uuid,
    context: &ApprovalCommandContext,
) {
    let Some(hint_id) = context.source_hint_id else {
        return;
    };
    state
        .home_realtime_event_publisher
        .publish_attention_hint_event(HomeAttentionHintRealtimeEvent {
            actor_user_id,
            pet_id: context.pet_id,
            hint_id,
            kind: HomeAttentionHintRealtimeEventKind::Resolved,
            source_ref_type: "agent_proactive_followup".to_owned(),
            source_ref_id: context.agent_followup_id,
            occurred_at: Utc::now(),
        })
        .await;
}

async fn publish_timeline_changed_event(
    state: &AiHttpState,
    actor_user_id: Uuid,
    context: &ApprovalCommandContext,
) {
    state
        .home_realtime_event_publisher
        .publish_timeline_event(HomeTimelineRealtimeEvent {
            actor_user_id,
            pet_id: context.pet_id,
            event_id: context.committed_event_id,
            occurred_at: Utc::now(),
        })
        .await;
}

/// ApprovalCommandContext 授权命令执行结果
/// 核心职责：
/// - 承载确认任务校验、真实写入和异常会话解析结果
/// - 为 Agent 续跑提供已提交事件与原始候选载荷
struct ApprovalCommandContext {
    pet_id: Uuid,
    session: AiChatSession,
    candidate_payload: serde_json::Value,
    episode_id: Uuid,
    agent_followup_id: Uuid,
    source_hint_id: Option<Uuid>,
    next_followup_due_at: Option<chrono::DateTime<Utc>>,
    committed_event_id: Uuid,
    surface: AiConversationSurface,
    approval_kind: ApprovalCommandKind,
}

#[derive(Debug, Clone, Copy)]
enum ApprovalCommandKind {
    ObservationWrite,
    AbnormalCreation,
    AbnormalRecovery,
}

async fn prepare_approval_command_context(
    state: &AiHttpState,
    actor_user_id: Uuid,
    confirmation_task_id: Uuid,
    requested_surface: Option<AiConversationSurface>,
) -> Result<ApprovalCommandContext, AiError> {
    let Ok(task) = state
        .confirmation_task_repository
        .get_by_id(confirmation_task_id)
        .await
    else {
        return Err(AiError::NotFound("confirmation task".to_owned()));
    };

    authorize_confirmation_task(state, actor_user_id, task.pet_id).await?;
    if task.status != ConfirmationTaskStatus::Pending {
        return Err(AiError::Conflict(
            "confirmation task is not pending".to_owned(),
        ));
    }

    let candidate_payload = task.candidate_payload.clone().unwrap_or_default();
    match task.task_kind {
        ConfirmationTaskKind::SymptomFollowup => {
            prepare_symptom_followup_approval_context(
                state,
                actor_user_id,
                task.pet_id,
                confirmation_task_id,
                candidate_payload,
                requested_surface,
            )
            .await
        }
        ConfirmationTaskKind::AbnormalSymptomCreation => {
            prepare_abnormal_creation_approval_context(
                state,
                actor_user_id,
                task.pet_id,
                confirmation_task_id,
                candidate_payload,
                requested_surface,
            )
            .await
        }
        ConfirmationTaskKind::AbnormalRecovery => {
            prepare_abnormal_recovery_approval_context(
                state,
                actor_user_id,
                task.pet_id,
                confirmation_task_id,
                candidate_payload,
                requested_surface,
            )
            .await
        }
        _ => Err(AiError::InvalidInput(
            "confirmation task kind does not support approval stream".to_owned(),
        )),
    }
}

async fn prepare_symptom_followup_approval_context(
    state: &AiHttpState,
    actor_user_id: Uuid,
    pet_id: Uuid,
    confirmation_task_id: Uuid,
    candidate_payload: serde_json::Value,
    requested_surface: Option<AiConversationSurface>,
) -> Result<ApprovalCommandContext, AiError> {
    let Some(episode_id) = candidate_payload
        .get("episode_id")
        .and_then(serde_json::Value::as_str)
        .and_then(|value| Uuid::parse_str(value).ok())
    else {
        return Err(AiError::InvalidInput(
            "confirmation task missing abnormal episode context".to_owned(),
        ));
    };

    let session = state
        .session_repository
        .find_active_abnormal_episode_session(actor_user_id, episode_id)
        .await?
        .ok_or_else(|| AiError::NotFound("ai chat session".to_owned()))?;
    let committed = state
        .observation_write_provider
        .commit_observation_write(actor_user_id, pet_id, confirmation_task_id)
        .await
        .map_err(|error| AiError::Infrastructure(error.to_string()))?;
    let agent_followup_id = session.agent_followup_id.ok_or_else(|| {
        AiError::InvalidInput("abnormal episode session missing followup context".to_owned())
    })?;
    let source_hint_id = session.source_hint_id;

    Ok(ApprovalCommandContext {
        pet_id,
        surface: requested_surface.unwrap_or(session.surface),
        session,
        candidate_payload,
        episode_id,
        agent_followup_id,
        source_hint_id,
        next_followup_due_at: None,
        committed_event_id: committed.event_id,
        approval_kind: ApprovalCommandKind::ObservationWrite,
    })
}

async fn prepare_abnormal_recovery_approval_context(
    state: &AiHttpState,
    actor_user_id: Uuid,
    pet_id: Uuid,
    confirmation_task_id: Uuid,
    candidate_payload: serde_json::Value,
    requested_surface: Option<AiConversationSurface>,
) -> Result<ApprovalCommandContext, AiError> {
    let Some(episode_id) = candidate_payload
        .get("episode_id")
        .and_then(serde_json::Value::as_str)
        .and_then(|value| Uuid::parse_str(value).ok())
    else {
        return Err(AiError::InvalidInput(
            "confirmation task missing abnormal episode context".to_owned(),
        ));
    };

    let session = state
        .session_repository
        .find_active_abnormal_episode_session(actor_user_id, episode_id)
        .await?
        .ok_or_else(|| AiError::NotFound("ai chat session".to_owned()))?;
    let committed = state
        .observation_write_provider
        .commit_abnormal_recovery_write(actor_user_id, pet_id, confirmation_task_id)
        .await
        .map_err(|error| AiError::Infrastructure(error.to_string()))?;
    let agent_followup_id = session.agent_followup_id.ok_or_else(|| {
        AiError::InvalidInput("abnormal episode session missing followup context".to_owned())
    })?;
    let source_hint_id = session.source_hint_id;

    Ok(ApprovalCommandContext {
        pet_id,
        surface: requested_surface.unwrap_or(session.surface),
        session,
        candidate_payload,
        episode_id,
        agent_followup_id,
        source_hint_id,
        next_followup_due_at: None,
        committed_event_id: committed.event_id,
        approval_kind: ApprovalCommandKind::AbnormalRecovery,
    })
}

async fn prepare_abnormal_creation_approval_context(
    state: &AiHttpState,
    actor_user_id: Uuid,
    pet_id: Uuid,
    confirmation_task_id: Uuid,
    candidate_payload: serde_json::Value,
    requested_surface: Option<AiConversationSurface>,
) -> Result<ApprovalCommandContext, AiError> {
    let session_id = candidate_payload
        .get("chat_session_id")
        .and_then(serde_json::Value::as_str)
        .and_then(|value| Uuid::parse_str(value).ok())
        .ok_or_else(|| {
            AiError::InvalidInput("confirmation task missing chat session".to_owned())
        })?;
    let session = state
        .session_repository
        .get_session(session_id)
        .await?
        .filter(|session| session.actor_user_id == actor_user_id)
        .ok_or_else(|| AiError::NotFound("ai chat session".to_owned()))?;
    let committed = state
        .abnormal_symptom_creation_provider
        .commit_abnormal_symptom_creation(actor_user_id, pet_id, confirmation_task_id)
        .await
        .map_err(|error| AiError::Infrastructure(error.to_string()))?;
    let bound_session = state
        .session_repository
        .bind_session_to_abnormal_episode_followup(
            session.id,
            actor_user_id,
            committed.episode_id,
            committed.agent_followup_id,
        )
        .await?
        .ok_or_else(|| AiError::NotFound("ai chat session".to_owned()))?;
    let source_hint_id = bound_session.source_hint_id;

    Ok(ApprovalCommandContext {
        pet_id,
        surface: requested_surface.unwrap_or(bound_session.surface),
        session: bound_session,
        candidate_payload,
        episode_id: committed.episode_id,
        agent_followup_id: committed.agent_followup_id,
        source_hint_id,
        next_followup_due_at: Some(committed.next_followup_due_at),
        committed_event_id: committed.event_id,
        approval_kind: ApprovalCommandKind::AbnormalCreation,
    })
}

/// ApprovalRuntimeBuildInput 授权续跑 Runtime 构建输入
/// 核心职责：
/// - 聚合构建 workbench 与 runtime stream 需要的上下文字段
/// - 让 handler 保持校验和响应编排职责
struct ApprovalRuntimeBuildInput<'a> {
    session: &'a maohuoban_ai_domain::ai::AiChatSession,
    actor_user_id: Uuid,
    pet_id: Uuid,
    target_pet: AiPetDisplaySnapshot,
    surface: AiConversationSurface,
    turn_id: AgentTurnId,
    assistant_message_id: Uuid,
    system_message_id: Uuid,
    confirmation_task_id: Uuid,
    internal_prompt: String,
}

/// ApprovalRuntimeInput 授权续跑 Runtime 输入
/// 核心职责：
/// - 同时持有 ChatStreamRequest 和 RuntimeAgentStreamInput
/// - 避免 stream request 生命周期与 runtime input 分散构造
struct ApprovalRuntimeInput {
    stream_req: ChatStreamRequest,
    stream_input: RuntimeAgentStreamInput,
    assistant_message_id: Uuid,
    turn_id: AgentTurnId,
}

async fn build_approval_runtime_input(
    state: &AiHttpState,
    input: ApprovalRuntimeBuildInput<'_>,
) -> Result<ApprovalRuntimeInput, AiError> {
    let (recent_conversation, session_summary) = load_history_and_summary(
        state,
        input.actor_user_id,
        input.session.id,
        input.system_message_id,
    )
    .await?;
    let memory_entries = load_memory_entries_for_workbench(
        state,
        input.actor_user_id,
        input.session.id,
        Some(&input.target_pet),
    )
    .await?;
    let workbench = build_agent_session_workbench(
        input.surface,
        Some(&input.target_pet),
        session_summary,
        None,
        memory_entries,
        recent_conversation,
    );
    let stream_context = AiStreamRunContext {
        chat_session_id: input.session.id,
        message_id: input.assistant_message_id,
        title: input.session.title.clone(),
        target_pet: Some(input.target_pet.clone()),
        initial_events: Vec::new(),
        fact_package: None,
    };
    let observation_write_context = ObservationWriteContext {
        chat_context_kind: input.session.chat_context_kind.clone(),
        abnormal_episode_id: input.session.abnormal_episode_id,
        source_hint_id: input.session.source_hint_id,
        agent_followup_id: input.session.agent_followup_id,
        source_turn_id: Some(input.turn_id.as_uuid()),
    };
    let stream_req = ChatStreamRequest {
        message: input.internal_prompt,
        selected_pet_id: Some(input.pet_id),
        surface: input.surface,
        chat_session_id: Some(input.session.id),
        source_hint_id: input.session.source_hint_id,
        chat_context_kind: input.session.chat_context_kind.clone(),
        abnormal_episode_id: input.session.abnormal_episode_id,
        agent_followup_id: input.session.agent_followup_id,
        confirmation_task_id: Some(input.confirmation_task_id),
        client_message_id: None,
    };
    let stream_input = RuntimeAgentStreamInput {
        session_id: input.session.id,
        turn_id: input.turn_id,
        message_id: input.assistant_message_id,
        confirmation_task_id: Some(input.confirmation_task_id),
        observation_write_context,
        actor_user_id: input.actor_user_id,
        target_pet: Some(input.target_pet),
        fact_package: None,
        context: stream_context,
        workbench,
    };

    Ok(ApprovalRuntimeInput {
        stream_req,
        stream_input,
        assistant_message_id: input.assistant_message_id,
        turn_id: input.turn_id,
    })
}

/// InternalApprovalTurnInput 内部授权续跑 turn 输入
/// 核心职责：
/// - 收敛 system message 与 turn 持久化所需字段
/// - 保持授权命令不创建用户消息
struct InternalApprovalTurnInput {
    session_id: Uuid,
    actor_user_id: Uuid,
    pet_id: Uuid,
    turn_id: AgentTurnId,
    system_message_id: Uuid,
    surface: AiConversationSurface,
    content: String,
    now: chrono::DateTime<Utc>,
}

async fn persist_internal_approval_turn(
    state: &AiHttpState,
    input: InternalApprovalTurnInput,
) -> Result<(), AiError> {
    let system_message = AiMessage {
        id: input.system_message_id,
        session_id: input.session_id,
        turn_id: None,
        role: AiMessageRole::System,
        content: input.content,
        content_blocks: Vec::new(),
        status: AiMessageStatus::Completed,
        citations: Vec::new(),
        model: None,
        provider: None,
        finish_reason: None,
        usage_input_tokens: None,
        usage_output_tokens: None,
        verification: None,
        created_at: input.now,
    };
    state
        .session_repository
        .insert_message(&system_message)
        .await?;

    let turn = AiSessionTurn {
        id: input.turn_id.as_uuid(),
        session_id: input.session_id,
        actor_user_id: input.actor_user_id,
        user_message_id: input.system_message_id,
        assistant_message_id: None,
        intent: "private_pet_care".to_owned(),
        gate_decision: "allow".to_owned(),
        resolved_pet_id: Some(input.pet_id),
        engine_mode: state.runtime_engine_mode.as_str().to_owned(),
        surface: input.surface,
        status: AiSessionTurnStatus::Running,
        finish_reason: None,
        error_code: None,
        retryable: None,
        started_at: input.now,
        finished_at: None,
    };
    state.session_turn_repository.insert_turn(&turn).await?;
    state
        .session_repository
        .update_message_turn_id(input.system_message_id, input.turn_id.as_uuid())
        .await
}

async fn authorize_confirmation_task(
    state: &AiHttpState,
    actor_user_id: Uuid,
    pet_id: Uuid,
) -> Result<(), AiError> {
    let candidates = state
        .pet_resolver
        .list_authorized_candidates(actor_user_id)
        .await?;
    if candidates
        .iter()
        .any(|candidate| candidate.pet_id == pet_id)
    {
        Ok(())
    } else {
        Err(AiError::Unauthorized)
    }
}

async fn authorized_pet_snapshot(
    state: &AiHttpState,
    actor_user_id: Uuid,
    pet_id: Uuid,
) -> Option<AiPetDisplaySnapshot> {
    state
        .pet_resolver
        .list_authorized_candidates(actor_user_id)
        .await
        .ok()
        .and_then(|candidates| {
            candidates
                .into_iter()
                .find(|candidate| candidate.pet_id == pet_id)
                .map(|candidate| AiPetDisplaySnapshot::from(&candidate))
        })
}

fn approval_followup_prompt(
    approval_kind: ApprovalCommandKind,
    confirmation_task_id: Uuid,
    event_id: Uuid,
    episode_id: Uuid,
    agent_followup_id: Uuid,
    next_followup_due_at: Option<chrono::DateTime<Utc>>,
    candidate_payload: &serde_json::Value,
) -> String {
    let note = candidate_payload
        .get("note")
        .and_then(serde_json::Value::as_str)
        .unwrap_or("用户确认写入了一条异常观察更新");
    let recovery_note = candidate_payload
        .get("recovery_note")
        .and_then(serde_json::Value::as_str)
        .unwrap_or("用户确认本次异常已经恢复");
    if matches!(approval_kind, ApprovalCommandKind::AbnormalRecovery) {
        return format!(
            "后端已完成用户授权的异常恢复写入。confirmation_task_id={confirmation_task_id}; resolved_event_id={event_id}; episode_id={episode_id}; agent_followup_id={agent_followup_id}; episode_status=recovered; 本次异常主动追踪已关闭，相关站内轻提醒和后续计划已由后端状态机清理。恢复内容：{recovery_note}。当前会话仍绑定到这个异常追踪上下文，但上下文状态表示该异常已经恢复。请基于这些已完成事实自然回复用户：说明恢复记录已经完成，本次主动追踪已停止；可以提示如果之后再次出现异常可重新告诉你。不要把这段系统事实逐字复述给用户，不要声称识别图片或做出医疗诊断。"
        );
    }
    let plan_fact = next_followup_due_at.map_or_else(
        || "下一次追踪计划会由后台 planning 根据本次写入后的 episode 状态继续生成。".to_owned(),
        |due_at| format!("next_followup_due_at={};", due_at.to_rfc3339()),
    );
    format!(
        "后端已完成用户授权的异常相关写入。confirmation_task_id={confirmation_task_id}; resolved_event_id={event_id}; episode_id={episode_id}; agent_followup_id={agent_followup_id}; {plan_fact} 写入内容：{note}。当前会话已经绑定到这个异常追踪上下文。请基于这些已完成事实自然回复用户：说明异常记录或观察更新已经完成；如果已经提供 next_followup_due_at，可以结合主动追踪计划说明你后续会在合适时间提醒用户更新宠物实际情况。不要把这段系统事实逐字复述给用户，不要声称识别图片或做出医疗诊断。"
    )
}
