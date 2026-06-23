use std::sync::Arc;

use axum::{
    Router,
    routing::{get, post},
};
use maohuoban_auth_application::auth::AuthService;
use maohuoban_profile_application::profile::ProfileService;

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
    profile: Arc<ProfileService>,
}

impl AuthHttpState {
    #[must_use]
    pub const fn new(auth: Arc<AuthService>, profile: Arc<ProfileService>) -> Self {
        Self { auth, profile }
    }
}

/// build_auth_router 构建认证路由
/// 核心职责：
/// - 注册登录、refresh、第三方 TODO 接口
/// - 将 HTTP 层限制在 DTO 和响应转换范围内
#[must_use]
pub fn build_auth_router(auth: Arc<AuthService>, profile: Arc<ProfileService>) -> Router {
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
        .route("/api/v1/account/security", get(handlers::account_security))
        .route(
            "/api/v1/account/password",
            post(handlers::set_account_password).patch(handlers::change_account_password),
        )
        .route(
            "/api/v1/account/password/change-code",
            post(handlers::send_password_change_code),
        )
        .route(
            "/api/v1/account/devices",
            get(handlers::list_account_devices),
        )
        .route(
            "/api/v1/account/devices/{session_id}",
            get(handlers::load_account_device).delete(handlers::revoke_account_device),
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
        .with_state(AuthHttpState::new(auth, profile))
}
