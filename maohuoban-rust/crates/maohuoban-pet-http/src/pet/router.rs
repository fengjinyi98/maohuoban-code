mod agent_diet;
mod diet_assignment;
mod events;
mod food_inventory;
mod media;
mod merchant;
mod profile;

use std::sync::Arc;

use axum::{
    Router,
    extract::DefaultBodyLimit,
    routing::{delete, get, post},
};
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
}

impl PetHttpState {
    #[must_use]
    pub const fn new(pet: Arc<PetService>) -> Self {
        Self { pet }
    }
}

/// build_pet_router 构建宠物路由
/// 核心职责：
/// - 注册宠物档案、事件追加和时间线接口
/// - 将 HTTP 层限制在 DTO、用户上下文和响应转换范围内
#[allow(clippy::too_many_lines)]
pub fn build_pet_router(pet: Arc<PetService>) -> Router {
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
            "/api/v1/pets/{pet_id}/diet-context",
            get(agent_diet::get_pet_current_diet_context),
        )
        .route(
            "/api/v1/pets/{pet_id}/diet-confirmation-candidates",
            get(agent_diet::get_pet_diet_confirmation_candidates),
        )
        .route(
            "/api/v1/pets/{pet_id}/diet-confirmations",
            post(agent_diet::confirm_pet_diet_candidate),
        )
        .route(
            "/api/v1/food-inventory/change-hints",
            get(agent_diet::get_food_inventory_change_hints),
        )
        .route(
            "/api/v1/food-inventory/items",
            get(food_inventory::list_food_inventory_items)
                .post(food_inventory::create_food_inventory_item),
        )
        .route(
            "/api/v1/food-inventory/items/{item_id}",
            get(food_inventory::get_food_inventory_item)
                .patch(food_inventory::update_food_inventory_item)
                .delete(food_inventory::archive_food_inventory_item),
        )
        .route(
            "/api/v1/food-inventory/items/{item_id}/archive",
            post(food_inventory::archive_food_inventory_item),
        )
        .route(
            "/api/v1/food-inventory/items/{item_id}/restore",
            post(food_inventory::restore_food_inventory_item),
        )
        .route(
            "/api/v1/food-inventory/items/{item_id}/restock",
            post(food_inventory::restock_food_inventory_item),
        )
        .route(
            "/api/v1/pets/{pet_id}/diet/staple",
            post(diet_assignment::set_pet_current_staple),
        )
        .route(
            "/api/v1/pets/{pet_id}/diet/assignments",
            get(diet_assignment::list_active_diet_assignments)
                .post(diet_assignment::set_pet_diet_assignment),
        )
        .route(
            "/api/v1/pets/{pet_id}/diet/assignments/{assignment_id}",
            delete(diet_assignment::end_diet_assignment),
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
            "/api/v1/pets/{pet_id}/identity-context",
            get(profile::load_identity_context),
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
        .with_state(PetHttpState::new(pet))
}
