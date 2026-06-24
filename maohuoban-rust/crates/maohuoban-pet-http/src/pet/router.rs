mod auth;
mod events;
mod media;
mod merchant;
mod profile;

use std::sync::Arc;

use axum::{
    Router,
    extract::DefaultBodyLimit,
    routing::{get, post},
};
use maohuoban_auth_application::auth::AuthService;
use maohuoban_media_storage::media_upload_policy::MediaUploadPolicy;
use maohuoban_pet_application::pet::PetService;

const PET_VIDEO_UPLOAD_LIMIT_BYTES: usize = 128 * 1024 * 1024;

/// PetHttpState 宠物 HTTP 状态
/// 核心职责：
/// - 持有宠物应用服务
/// - 作为 axum handler 的共享状态
#[derive(Clone)]
pub struct PetHttpState {
    pet: Arc<PetService>,
    auth: Arc<AuthService>,
}

impl PetHttpState {
    #[must_use]
    pub const fn new(pet: Arc<PetService>, auth: Arc<AuthService>) -> Self {
        Self { pet, auth }
    }
}

/// build_pet_router 构建宠物路由
/// 核心职责：
/// - 注册宠物档案、事件追加和时间线接口
/// - 将 HTTP 层限制在 DTO、用户上下文和响应转换范围内
pub fn build_pet_router(pet: Arc<PetService>, auth: Arc<AuthService>) -> Router {
    Router::new()
        .route(
            "/api/v1/pets",
            get(profile::list_pet_profiles).post(profile::create_pet_profile),
        )
        .route(
            "/api/v1/pets/{pet_id}",
            get(profile::load_pet_profile)
                .patch(profile::update_pet_profile)
                .delete(profile::delete_pet_profile),
        )
        .route(
            "/api/v1/pets/{pet_id}/restore",
            post(profile::restore_pet_profile),
        )
        .route(
            "/api/v1/pet-media/avatar",
            post(media::upload_pending_pet_avatar).layer(DefaultBodyLimit::max(
                MediaUploadPolicy::avatar().body_limit_bytes,
            )),
        )
        .route(
            "/api/v1/pet-media/background-image",
            post(media::upload_pending_pet_background_image).layer(DefaultBodyLimit::max(
                MediaUploadPolicy::cover().body_limit_bytes,
            )),
        )
        .route(
            "/api/v1/pet-media/background-video",
            post(media::upload_pending_pet_background_video)
                .layer(DefaultBodyLimit::max(PET_VIDEO_UPLOAD_LIMIT_BYTES)),
        )
        .route(
            "/api/v1/pet-media/background-live-photo",
            post(media::upload_pending_pet_background_live_photo).layer(DefaultBodyLimit::max(
                MediaUploadPolicy::cover().body_limit_bytes + PET_VIDEO_UPLOAD_LIMIT_BYTES,
            )),
        )
        .route(
            "/api/v1/pets/{pet_id}/media-bindings",
            post(media::bind_uploaded_pet_media),
        )
        .route(
            "/api/v1/pets/imports/trade",
            post(profile::import_trade_pet),
        )
        .route(
            "/api/v1/pet-events/{event_id}",
            get(events::load_pet_event_detail),
        )
        .route(
            "/api/v1/pets/{pet_id}/events",
            post(events::create_pet_event),
        )
        .route(
            "/api/v1/pets/{pet_id}/timeline",
            get(events::load_pet_timeline),
        )
        .route(
            "/api/v1/merchants/{merchant_id}/pets",
            get(merchant::list_merchant_pets).post(merchant::create_merchant_pet),
        )
        .route(
            "/api/v1/merchants/{merchant_id}/pets/{pet_id}/available-status",
            post(merchant::publish_available_status),
        )
        .route(
            "/api/v1/merchants/{merchant_id}/litters/{litter_id}",
            get(merchant::load_merchant_litter_detail),
        )
        .with_state(PetHttpState::new(pet, auth))
}
