pub mod handlers;
mod mappers;
mod requests;
mod responses;

use std::sync::Arc;

use axum::{
    Router,
    extract::DefaultBodyLimit,
    routing::{get, post},
};
use maohuoban_auth_application::auth::AuthService;
use maohuoban_media_storage::media_upload_policy::MediaUploadPolicy;
use maohuoban_profile_application::profile::ProfileService;

/// `ProfileHttpState` 用户资料 HTTP 状态
/// 核心职责：
/// - 持有认证服务和资料应用服务
/// - 在 HTTP 层完成登录态校验和响应映射
#[derive(Clone)]
pub struct ProfileHttpState {
    profile: Arc<ProfileService>,
    auth: Arc<AuthService>,
}

impl ProfileHttpState {
    #[must_use]
    pub const fn new(profile: Arc<ProfileService>, auth: Arc<AuthService>) -> Self {
        Self { profile, auth }
    }
}

/// `build_profile_router` 构建用户资料路由
/// 核心职责：
/// - 注册当前用户资料读取接口
/// - 保持用户资料响应来自 `ProfileService` 单一事实源
pub fn build_profile_router(profile: Arc<ProfileService>, auth: Arc<AuthService>) -> Router {
    Router::new()
        .route(
            "/api/v1/profile/me",
            get(handlers::get_current_profile).patch(handlers::patch_current_profile),
        )
        .route(
            "/api/v1/profile/me/avatar",
            post(handlers::upload_current_profile_avatar).layer(DefaultBodyLimit::max(
                MediaUploadPolicy::avatar().body_limit_bytes,
            )),
        )
        .route(
            "/api/v1/profile/me/cover",
            post(handlers::upload_current_profile_cover).layer(DefaultBodyLimit::max(
                MediaUploadPolicy::cover().body_limit_bytes,
            )),
        )
        .with_state(ProfileHttpState::new(profile, auth))
}
