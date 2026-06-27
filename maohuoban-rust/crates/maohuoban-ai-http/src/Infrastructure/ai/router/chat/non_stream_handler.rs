use axum::{Json, extract::State, http::HeaderMap, response::Response};

use super::super::AiHttpState;
use super::super::auth::current_user_id;
use super::request::ChatStreamRequest;
use crate::ai::response::{ai_error_response, unauthorized_response};

/// handle_chat 非流式聊天 handler
/// 核心职责：
/// - 校验登录态并从 token 注入 actor
/// - 返回非流式调试响应
pub async fn handle_chat(
    State(state): State<AiHttpState>,
    headers: HeaderMap,
    Json(_req): Json<ChatStreamRequest>,
) -> Response {
    let Ok(_actor_user_id) = current_user_id(&state.auth, &headers).await else {
        return unauthorized_response();
    };

    ai_error_response(&maohuoban_ai_domain::ai::AiError::ProviderNotConfigured)
}
