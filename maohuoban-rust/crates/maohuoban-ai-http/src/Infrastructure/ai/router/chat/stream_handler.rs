use axum::{Json, extract::State, response::Response};
use maohuoban_ai_application::ai::stream::AiStreamRunContext;
use maohuoban_ai_domain::ai::{
    AiGateDecision, AiPetDisplaySnapshot, AiStreamEvent, ContextConfirmationTaskSummary,
};
use maohuoban_auth_http::auth::extractor::AuthenticatedUser;
use std::sync::Arc;
use uuid::Uuid;

use super::super::AiHttpState;
use super::super::diagnostics::{
    record_chat_gate_decided, record_chat_provider_started, record_chat_stream_request_received,
};
use super::composition::request::ChatStreamRequest;
use super::composition::workbench_builder::{
    build_agent_session_workbench, load_memory_entries_for_workbench,
};
use super::loaders::history_summary_loader::load_history_and_summary;
use super::persistence::finalizer_store::HttpFinalizerStore;
use super::responses::gated_stream_response::gated_stream_response;
use super::responses::pet_resolution_stream_response::pet_resolution_stream_response;
use super::responses::stream_response::agent_stream_response;
use super::runtime_stream_bridge::{RuntimeAgentStreamInput, runtime_agent_stream};
use super::turn_preparation::{
    load_pet_catalog_initial_events, persist_prepared_chat_turn, prepare_chat_turn_context,
};
use crate::ai::response::ai_error_response;

/// handle_chat_stream 流式聊天 SSE handler
/// 核心职责：
/// - 校验登录态并从 token 注入 actor
/// - 输出毛伙伴稳定 SSE 事件并持久化完成消息
pub async fn handle_chat_stream(
    State(state): State<AiHttpState>,
    actor: AuthenticatedUser,
    Json(req): Json<ChatStreamRequest>,
) -> Response {
    let actor_user_id = actor.user_id();

    let context = match prepare_chat_turn_context(&state, &req, actor_user_id).await {
        Ok(context) => context,
        Err(error) => return ai_error_response(&error),
    };
    record_stream_request_received(
        &req,
        actor_user_id,
        context.session_id,
        context.user_message_id,
    );
    record_stream_gate_decided(
        context.session_id,
        context.effective_selected_pet_id,
        context.resolved_pet_id,
        &context.gate_decision,
    );
    persist_prepared_chat_turn(&state, &req, actor_user_id, &context).await;

    let initial_events = load_pet_catalog_initial_events(
        &state.session_repository,
        context.session_id,
        actor_user_id,
        &context.gate_decision,
        context.resolved_pet_id,
        context.effective_selected_pet_id,
        context.pet_resolution.as_ref(),
    )
    .await;
    if !context.gate_decision.enters_workbench() {
        return gated_stream_response(
            Arc::new(HttpFinalizerStore::from_state(&state)),
            context.session_id,
            actor_user_id,
            context.turn_id.as_uuid(),
            context.assistant_message_id,
            context.title,
            &context.gate_decision,
        )
        .await;
    }

    if let Some(resolution) = context
        .pet_resolution
        .as_ref()
        .filter(|resolution| !resolution.is_resolved())
    {
        return pet_resolution_stream_response(
            Arc::new(HttpFinalizerStore::from_state(&state)),
            context.session_id,
            actor_user_id,
            context.turn_id.as_uuid(),
            context.assistant_message_id,
            context.title,
            resolution.clone(),
        )
        .await;
    }

    agent_response_for_context(
        &state,
        &req,
        AgentResponseInput {
            session_id: context.session_id,
            turn_id: context.turn_id,
            message_id: context.assistant_message_id,
            confirmation_task_id: context.confirmation_task_id,
            title: context.title,
            actor_user_id,
            target_pet: context.target_pet,
            initial_events,
            user_message_id: context.user_message_id,
        },
    )
    .await
}

/// AgentResponseInput Agent Runtime 响应构建输入
/// 核心职责：
/// - 承载 stream 主链路进入 Agent Runtime 所需上下文
/// - 控制 helper 参数数量并保持所有权边界清晰
struct AgentResponseInput {
    session_id: Uuid,
    turn_id: maohuoban_ai_domain::ai::AgentTurnId,
    message_id: Uuid,
    confirmation_task_id: Option<Uuid>,
    title: String,
    actor_user_id: Uuid,
    target_pet: Option<AiPetDisplaySnapshot>,
    initial_events: Vec<AiStreamEvent>,
    user_message_id: Uuid,
}

async fn agent_response_for_context(
    state: &AiHttpState,
    req: &ChatStreamRequest,
    input: AgentResponseInput,
) -> Response {
    record_provider_context_started(
        input.session_id,
        input.message_id,
        state.runtime_engine_mode.as_str(),
        input.target_pet.as_ref(),
        &input.initial_events,
        false,
    );

    let stream_context = AiStreamRunContext {
        chat_session_id: input.session_id,
        message_id: input.message_id,
        title: input.title,
        target_pet: input.target_pet.clone(),
        initial_events: input.initial_events,
        fact_package: None,
    };
    let (recent_conversation, session_summary) = match load_history_and_summary(
        state,
        input.actor_user_id,
        input.session_id,
        input.user_message_id,
    )
    .await
    {
        Ok(result) => result,
        Err(error) => {
            return agent_stream_response(
                futures_util::stream::iter(vec![Err(error)]),
                Arc::new(HttpFinalizerStore::from_state(state)),
                input.session_id,
                input.actor_user_id,
                input.message_id,
                input.turn_id.as_uuid(),
                state.runtime_engine_mode.as_str(),
            );
        }
    };
    let memory_entries = match load_memory_entries_for_workbench(
        state,
        input.actor_user_id,
        input.session_id,
        input.target_pet.as_ref(),
    )
    .await
    {
        Ok(entries) => entries,
        Err(error) => {
            return agent_stream_response(
                futures_util::stream::iter(vec![Err(error)]),
                Arc::new(HttpFinalizerStore::from_state(state)),
                input.session_id,
                input.actor_user_id,
                input.message_id,
                input.turn_id.as_uuid(),
                state.runtime_engine_mode.as_str(),
            );
        }
    };

    let workbench = build_agent_session_workbench(
        req.surface,
        input.target_pet.as_ref(),
        session_summary,
        input
            .confirmation_task_id
            .map(|task_id| ContextConfirmationTaskSummary {
                confirmation_task_id: task_id,
                tool_name: "commit_pet_observation_write".to_owned(),
                question_text: "是否确认写入这条观察记录？".to_owned(),
            }),
        memory_entries,
        recent_conversation,
    );
    let stream = runtime_agent_stream(
        state,
        req,
        RuntimeAgentStreamInput {
            session_id: input.session_id,
            turn_id: input.turn_id,
            message_id: input.message_id,
            confirmation_task_id: input.confirmation_task_id,
            actor_user_id: input.actor_user_id,
            target_pet: input.target_pet,
            fact_package: None,
            context: stream_context,
            workbench,
        },
    );

    agent_stream_response(
        stream,
        Arc::new(HttpFinalizerStore::from_state(state)),
        input.session_id,
        input.actor_user_id,
        input.message_id,
        input.turn_id.as_uuid(),
        state.runtime_engine_mode.as_str(),
    )
}

fn record_stream_request_received(
    req: &ChatStreamRequest,
    actor_user_id: Uuid,
    session_id: Uuid,
    message_id: Uuid,
) {
    record_chat_stream_request_received(
        actor_user_id,
        session_id,
        message_id,
        req.selected_pet_id,
        req.surface,
        &req.message,
    );
}

fn record_stream_gate_decided(
    session_id: Uuid,
    selected_pet_id: Option<Uuid>,
    resolved_pet_id: Option<Uuid>,
    gate_decision: &AiGateDecision,
) {
    record_chat_gate_decided(session_id, selected_pet_id, resolved_pet_id, gate_decision);
}

fn record_provider_context_started(
    session_id: Uuid,
    message_id: Uuid,
    engine_mode: &str,
    target_pet: Option<&AiPetDisplaySnapshot>,
    initial_events: &[AiStreamEvent],
    fact_package_loaded: bool,
) {
    record_chat_provider_started(
        session_id,
        message_id,
        engine_mode,
        target_pet.is_some(),
        initial_events.len(),
        fact_package_loaded,
    );
}
