//! non_stream 非流式聊天 handler
//! 核心职责：
//! - handle_chat：校验登录态、宠物解析、事实包、回答校验和消息持久化
//! - 子模块按职责拆分：complete（Runtime完成）、response（响应体）、persistence（持久化）、history_loader（历史加载）

mod complete;
mod history_loader;
mod persistence;
mod response;

#[cfg(test)]
mod tests;

use axum::{Json, extract::State, http::HeaderMap, response::Response};

use super::super::AiHttpState;
use super::super::auth::current_user_id;
use super::composition::request::ChatStreamRequest;
use super::responses::gated_stream_response::gated_message_text;
use super::responses::pet_resolution_stream_response::pet_resolution_message_text;
use super::stream_handler::load_fact_context_and_initial_events;
use super::turn_preparation::{
    load_pet_catalog_initial_events, persist_prepared_chat_turn, prepare_chat_turn_context,
};
use crate::ai::response::{ai_error_response, ok_response, unauthorized_response};

use complete::complete_with_runtime;
use persistence::{complete_boundary_turn, persist_finalizer_tx};
use response::ChatCompleteResponse;

/// handle_chat 非流式聊天 handler
/// 核心职责：
/// - 校验登录态并从 token 注入 actor
/// - 复用流式链路的宠物解析、事实包、回答校验和消息持久化
pub async fn handle_chat(
    State(state): State<AiHttpState>,
    headers: HeaderMap,
    Json(req): Json<ChatStreamRequest>,
) -> Response {
    let Ok(actor_user_id) = current_user_id(&state.auth, &headers).await else {
        return unauthorized_response();
    };

    let context = prepare_chat_turn_context(&state, &req, actor_user_id).await;
    persist_prepared_chat_turn(&state, &req, actor_user_id, &context).await;

    let _ = load_pet_catalog_initial_events(
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
        return complete_boundary_turn(
            &state,
            &context,
            gated_message_text(&context.gate_decision).to_owned(),
            "gate_skipped_main_agent",
        )
        .await;
    }

    if let Some(resolution) = context.pet_resolution.as_ref().filter(|r| !r.is_resolved()) {
        return complete_boundary_turn(
            &state,
            &context,
            pet_resolution_message_text(resolution).to_owned(),
            "pet_resolution_skipped_main_agent",
        )
        .await;
    }

    let (fact_package, _initial_events) = load_fact_context_and_initial_events(
        &state,
        context.session_id,
        actor_user_id,
        context.target_pet.as_ref(),
        Vec::new(),
    )
    .await;

    let complete_result = complete_with_runtime(
        &state,
        &req,
        actor_user_id,
        &context,
        context.target_pet.clone(),
        fact_package,
    )
    .await;
    let complete = match complete_result {
        Ok(result) => result,
        Err(error) => return ai_error_response(&error),
    };

    persist_finalizer_tx(
        &state,
        context.assistant_message_id,
        context.session_id,
        context.turn_id.as_uuid(),
        &complete,
    )
    .await;

    ok_response(
        "ai.chat_completed",
        "AI 回答已完成",
        ChatCompleteResponse {
            chat_session_id: context.session_id,
            message_id: context.assistant_message_id,
            title: context.title,
            target_pet: context.target_pet,
            final_text: complete.final_text,
            citations: complete.citations,
            usage: complete.usage,
            finish_reason: complete.finish_reason,
            verification: complete.verification,
        },
    )
}
