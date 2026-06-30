use axum::{Json, extract::State, http::HeaderMap, response::Response};
use maohuoban_ai_application::ai::stream::AiStreamRunContext;
use maohuoban_ai_domain::ai::{AiFactPackage, AiGateDecision, AiPetDisplaySnapshot, AiStreamEvent};
use uuid::Uuid;

use super::super::AiHttpState;
use super::super::auth::current_user_id;
use super::super::diagnostics::{
    record_chat_gate_decided, record_chat_provider_started, record_chat_stream_request_received,
};
use super::composition::fact_package_merge::merge_fact_packages;
use super::composition::request::ChatStreamRequest;
use super::composition::workbench_builder::build_agent_session_workbench;
use super::loaders::diet_confirmation_candidate_loader::load_diet_confirmation_candidate_package;
use super::loaders::diet_fact_loader::load_current_diet_fact_package;
use super::loaders::food_inventory_hint_loader::load_food_inventory_hint_package;
use super::loaders::history_summary_loader::load_history_and_summary;
use super::loaders::identity_fact_loader::load_identity_fact_package;
use super::responses::gated_stream_response::gated_stream_response;
use super::responses::pet_resolution_stream_response::pet_resolution_stream_response;
use super::responses::stream_response::provider_stream_response;
use super::runtime_stream_bridge::{RuntimeProviderStreamInput, runtime_provider_stream};
use super::turn_preparation::{
    load_pet_catalog_initial_events, persist_prepared_chat_turn, prepare_chat_turn_context,
};
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

    let context = prepare_chat_turn_context(&state, &req, actor_user_id).await;
    record_stream_request_received(&req, actor_user_id, context.session_id);
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
            state.session_repository.clone(),
            context.session_id,
            context.assistant_message_id,
            context.title,
            &context.gate_decision,
        );
    }

    if let Some(resolution) = context
        .pet_resolution
        .as_ref()
        .filter(|resolution| !resolution.is_resolved())
    {
        return pet_resolution_stream_response(
            state.session_repository.clone(),
            context.session_id,
            context.assistant_message_id,
            context.title,
            resolution.clone(),
        );
    }

    provider_response_for_context(
        &state,
        &req,
        ProviderResponseInput {
            session_id: context.session_id,
            message_id: context.assistant_message_id,
            title: context.title,
            actor_user_id,
            target_pet: context.target_pet,
            initial_events,
            user_message_id: context.user_message_id,
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
    user_message_id: Uuid,
}

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
        state.runtime_engine_mode.as_str(),
        input.target_pet.as_ref(),
        &initial_events,
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
    let (recent_conversation, session_summary) = load_history_and_summary(
        state,
        input.actor_user_id,
        input.session_id,
        input.user_message_id,
    )
    .await;

    let workbench = build_agent_session_workbench(
        req.surface,
        input.target_pet.as_ref(),
        session_summary,
        Vec::new(),
        recent_conversation,
    );
    let stream = runtime_provider_stream(
        state,
        req,
        RuntimeProviderStreamInput {
            session_id: input.session_id,
            message_id: input.message_id,
            actor_user_id: input.actor_user_id,
            target_pet: input.target_pet,
            fact_package,
            context: stream_context,
            workbench,
        },
    );

    provider_stream_response(
        stream,
        state.session_repository.clone(),
        input.session_id,
        input.message_id,
        state.runtime_engine_mode.as_str(),
    )
}

fn record_stream_request_received(req: &ChatStreamRequest, actor_user_id: Uuid, session_id: Uuid) {
    record_chat_stream_request_received(
        actor_user_id,
        session_id,
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
    fact_package: Option<&AiFactPackage>,
) {
    record_chat_provider_started(
        session_id,
        message_id,
        engine_mode,
        target_pet.is_some(),
        initial_events.len(),
        fact_package.is_some(),
    );
}

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

    let merged = merge_fact_packages(
        merge_fact_packages(identity_fact_package, diet_fact_package),
        merge_fact_packages(
            food_inventory_hint_package,
            diet_confirmation_candidate_package,
        ),
    );

    (merged, initial_events)
}
