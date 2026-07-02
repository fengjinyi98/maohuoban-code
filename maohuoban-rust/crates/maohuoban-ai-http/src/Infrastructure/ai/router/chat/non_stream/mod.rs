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
use super::super::auth::{auth_error_code, authenticate_user, authorization_header_diagnostics};
use super::super::diagnostics::{
    record_chat_gate_decided, record_chat_non_stream_auth_failed,
    record_chat_non_stream_auth_succeeded, record_chat_non_stream_ingress_received,
    record_chat_provider_started,
};
use super::composition::request::ChatStreamRequest;
use super::responses::gated_stream_response::gated_message_text;
use super::responses::pet_resolution_stream_response::pet_resolution_message_text;
use super::turn_preparation::{
    load_pet_catalog_initial_events, persist_prepared_chat_turn, prepare_chat_turn_context,
};
use crate::ai::response::{ai_error_response, ok_response, unauthorized_response};

use complete::complete_with_runtime;
use persistence::{complete_boundary_turn, persist_finalizer};
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
    record_chat_non_stream_ingress_received(
        req.chat_session_id,
        req.selected_pet_id,
        req.surface,
        &req.message,
    );
    let auth_observation = authorization_header_diagnostics(&headers);
    let actor_user_id = match authenticate_user(&state.auth, &headers).await {
        Ok(actor) => {
            record_chat_non_stream_auth_succeeded(
                actor.id,
                req.chat_session_id,
                req.selected_pet_id,
                req.surface,
                &req.message,
            );
            actor.id
        }
        Err(error) => {
            record_chat_non_stream_auth_failed(
                req.chat_session_id,
                req.selected_pet_id,
                req.surface,
                &req.message,
                auth_observation.has_authorization,
                auth_observation.bearer_prefix_present,
                auth_error_code(&error),
            );
            return unauthorized_response();
        }
    };

    let context = match prepare_chat_turn_context(&state, &req, actor_user_id).await {
        Ok(context) => context,
        Err(error) => return ai_error_response(&error),
    };
    record_chat_gate_decided(
        context.session_id,
        context.effective_selected_pet_id,
        context.resolved_pet_id,
        &context.gate_decision,
    );
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
            actor_user_id,
            &context,
            gated_message_text(&context.gate_decision).to_owned(),
            "gate_skipped_main_agent",
        )
        .await;
    }

    if let Some(resolution) = context.pet_resolution.as_ref().filter(|r| !r.is_resolved()) {
        return complete_boundary_turn(
            &state,
            actor_user_id,
            &context,
            pet_resolution_message_text(resolution).to_owned(),
            "pet_resolution_skipped_main_agent",
        )
        .await;
    }

    record_chat_provider_started(
        context.session_id,
        context.assistant_message_id,
        state.runtime_engine_mode.as_str(),
        context.target_pet.is_some(),
        0,
        false,
    );

    let complete_result = complete_with_runtime(
        &state,
        &req,
        actor_user_id,
        &context,
        context.target_pet.clone(),
        None,
    )
    .await;
    let complete = match complete_result {
        Ok(result) => result,
        Err(error) => return ai_error_response(&error),
    };

    if let Err(error) = persist_finalizer(
        &state,
        actor_user_id,
        context.assistant_message_id,
        context.session_id,
        context.turn_id.as_uuid(),
        &complete,
    )
    .await
    {
        return ai_error_response(&error);
    }

    ok_response(
        "ai.chat_completed",
        "AI 回答已完成",
        ChatCompleteResponse {
            chat_session_id: context.session_id,
            message_id: context.assistant_message_id,
            title: context.title,
            target_pet: context.target_pet,
            final_text: complete.final_text,
            content_blocks: complete.content_blocks,
            citations: complete.citations,
            usage: complete.usage,
            finish_reason: complete.finish_reason,
            verification: complete.verification,
        },
    )
}
