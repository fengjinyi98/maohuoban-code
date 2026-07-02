use axum::{
    body::Body,
    extract::State,
    http::Request,
    middleware::Next,
    response::{IntoResponse, Response},
};
use maohuoban_auth_http::auth::extractor::{
    AuthMiddlewareState, AuthRejection, authenticate_user, auth_error_code,
    authorization_header_diagnostics,
};

use super::composition::request::ChatStreamRequest;
use super::super::diagnostics::{
    record_chat_non_stream_auth_failed, record_chat_non_stream_auth_succeeded,
    record_chat_non_stream_ingress_received, record_chat_stream_auth_failed,
    record_chat_stream_auth_succeeded, record_chat_stream_ingress_received,
};

/// `require_ai_chat_auth` AI chat 认证中间件
/// 核心职责：
/// - 在路由层统一执行 access token 鉴权
/// - 保留 AI 专属 ingress/auth 诊断，再将 AuthUser 注入 request extensions
pub async fn require_ai_chat_auth(
    State(state): State<AuthMiddlewareState>,
    mut request: Request<Body>,
    next: Next,
) -> Response {
    let Some(chat_request) = request.extensions().get::<ChatStreamRequest>().cloned() else {
        return AuthRejection::missing_extension("ai_chat_request").into_response();
    };

    let is_stream = request.uri().path().ends_with("/stream");
    if is_stream {
        record_chat_stream_ingress_received(
            chat_request.chat_session_id,
            chat_request.selected_pet_id,
            chat_request.surface,
            &chat_request.message,
        );
    } else {
        record_chat_non_stream_ingress_received(
            chat_request.chat_session_id,
            chat_request.selected_pet_id,
            chat_request.surface,
            &chat_request.message,
        );
    }

    let auth_observation = authorization_header_diagnostics(request.headers());
    match authenticate_user(&state.auth, request.headers()).await {
        Ok(user) => {
            if is_stream {
                record_chat_stream_auth_succeeded(
                    user.id,
                    chat_request.chat_session_id,
                    chat_request.selected_pet_id,
                    chat_request.surface,
                    &chat_request.message,
                );
            } else {
                record_chat_non_stream_auth_succeeded(
                    user.id,
                    chat_request.chat_session_id,
                    chat_request.selected_pet_id,
                    chat_request.surface,
                    &chat_request.message,
                );
            }
            request.extensions_mut().insert(user);
            next.run(request).await
        }
        Err(error) => {
            if is_stream {
                record_chat_stream_auth_failed(
                    chat_request.chat_session_id,
                    chat_request.selected_pet_id,
                    chat_request.surface,
                    &chat_request.message,
                    auth_observation.has_authorization,
                    auth_observation.bearer_prefix_present,
                    auth_error_code(&error),
                );
            } else {
                record_chat_non_stream_auth_failed(
                    chat_request.chat_session_id,
                    chat_request.selected_pet_id,
                    chat_request.surface,
                    &chat_request.message,
                    auth_observation.has_authorization,
                    auth_observation.bearer_prefix_present,
                    auth_error_code(&error),
                );
            }
            AuthRejection::from(error).into_response()
        }
    }
}
