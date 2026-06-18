use std::sync::Arc;

use axum::{Router, routing::post};
use maohuoban_auth_application::auth::AuthService;

mod dto;
mod handlers;
mod responses;

/// AuthHttpState 认证 HTTP 状态
/// 核心职责：
/// - 持有认证应用服务
/// - 作为 axum handler 的共享状态
#[derive(Clone)]
pub struct AuthHttpState {
    auth: Arc<AuthService>,
}

impl AuthHttpState {
    #[must_use]
    pub const fn new(auth: Arc<AuthService>) -> Self {
        Self { auth }
    }
}

/// build_auth_router 构建认证路由
/// 核心职责：
/// - 注册登录、refresh、第三方 TODO 接口
/// - 将 HTTP 层限制在 DTO 和响应转换范围内
#[must_use]
pub fn build_auth_router(auth: Arc<AuthService>) -> Router {
    Router::new()
        .route("/api/v1/auth/phone/code", post(handlers::send_phone_code))
        .route(
            "/api/v1/auth/phone/verify",
            post(handlers::verify_phone_code),
        )
        .route(
            "/api/v1/auth/password/login",
            post(handlers::password_login),
        )
        .route("/api/v1/auth/refresh", post(handlers::refresh_token))
        .route("/api/v1/auth/logout", post(handlers::logout))
        .route("/api/v1/auth/oauth/{provider}", post(handlers::oauth_login))
        .route(
            "/api/v1/account-recovery/code",
            post(handlers::send_recovery_code),
        )
        .route(
            "/api/v1/account-recovery/reset-password",
            post(handlers::reset_password),
        )
        .with_state(AuthHttpState::new(auth))
}
