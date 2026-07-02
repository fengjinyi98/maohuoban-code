use axum::{
    body::Body,
    extract::State,
    http::Request,
    middleware::Next,
    response::{IntoResponse, Response},
};

use super::{
    AuthMiddlewareState, AuthRejection, authenticate_session_context, authenticate_user,
};

/// require_authenticated_user 认证用户中间件
/// 核心职责：
/// - 在路由层统一完成 access token 鉴权
/// - 将 AuthUser 注入 request extensions，供后续 extractor 读取
pub async fn require_authenticated_user(
    State(state): State<AuthMiddlewareState>,
    mut request: Request<Body>,
    next: Next,
) -> Response {
    match authenticate_user(&state.auth, request.headers()).await {
        Ok(user) => {
            request.extensions_mut().insert(user);
            next.run(request).await
        }
        Err(error) => AuthRejection::from(error).into_response(),
    }
}

/// require_authenticated_session 认证会话中间件
/// 核心职责：
/// - 在路由层统一完成带 session 语义的 access token 鉴权
/// - 将 AuthenticatedSession 注入 request extensions，供后续 extractor 读取
pub async fn require_authenticated_session(
    State(state): State<AuthMiddlewareState>,
    mut request: Request<Body>,
    next: Next,
) -> Response {
    match authenticate_session_context(&state.auth, request.headers()).await {
        Ok(session) => {
            request.extensions_mut().insert(session);
            next.run(request).await
        }
        Err(error) => AuthRejection::from(error).into_response(),
    }
}
