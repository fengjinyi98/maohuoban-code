use std::sync::Arc;

use axum::{
    Json, Router,
    extract::{DefaultBodyLimit, Multipart, Path, Query, State},
    http::HeaderMap,
    response::Response,
    routing::{get, post},
};
use maohuoban_pet_application::pet::PetService;
use uuid::Uuid;

use super::{
    dto::{
        CreateMerchantPetRequest, CreatePetEventRequest, CreatePetProfileRequest,
        DeletePetProfileRequest, MerchantAvailableStatusData, MerchantLitterDetailData,
        MerchantPetsData, MerchantPetsQuery, PetEventData, PetMediaUploadData, PetProfileData,
        PetProfilesData, PetTimelineData, PublishAvailableStatusRequest, TradePetImportData,
        TradePetImportRequest, UpdatePetProfileRequest, UploadPetMediaRequest,
    },
    response::{created_response, error_response, ok_response, unauthorized_response},
};

const PET_IMAGE_UPLOAD_LIMIT_BYTES: usize = 16 * 1024 * 1024;
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
pub fn build_pet_router(pet: Arc<PetService>) -> Router {
    Router::new()
        .route(
            "/api/v1/pets",
            get(list_pet_profiles).post(create_pet_profile),
        )
        .route(
            "/api/v1/pets/{pet_id}",
            get(load_pet_profile)
                .patch(update_pet_profile)
                .delete(delete_pet_profile),
        )
        .route("/api/v1/pets/{pet_id}/restore", post(restore_pet_profile))
        .route(
            "/api/v1/pets/{pet_id}/media/avatar",
            post(upload_pet_avatar).layer(DefaultBodyLimit::max(PET_IMAGE_UPLOAD_LIMIT_BYTES)),
        )
        .route(
            "/api/v1/pets/{pet_id}/media/background-image",
            post(upload_pet_background_image)
                .layer(DefaultBodyLimit::max(PET_IMAGE_UPLOAD_LIMIT_BYTES)),
        )
        .route(
            "/api/v1/pets/{pet_id}/media/background-video",
            post(upload_pet_background_video)
                .layer(DefaultBodyLimit::max(PET_VIDEO_UPLOAD_LIMIT_BYTES)),
        )
        .route("/api/v1/pets/imports/trade", post(import_trade_pet))
        .route("/api/v1/pet-events/{event_id}", get(load_pet_event_detail))
        .route("/api/v1/pets/{pet_id}/events", post(create_pet_event))
        .route("/api/v1/pets/{pet_id}/timeline", get(load_pet_timeline))
        .route(
            "/api/v1/merchants/{merchant_id}/pets",
            get(list_merchant_pets).post(create_merchant_pet),
        )
        .route(
            "/api/v1/merchants/{merchant_id}/pets/{pet_id}/available-status",
            post(publish_available_status),
        )
        .route(
            "/api/v1/merchants/{merchant_id}/litters/{litter_id}",
            get(load_merchant_litter_detail),
        )
        .with_state(PetHttpState::new(pet))
}

async fn list_pet_profiles(State(state): State<PetHttpState>, headers: HeaderMap) -> Response {
    let Ok(owner_user_id) = current_user_id(&headers) else {
        return unauthorized_response();
    };

    match state.pet.list_pet_profiles(owner_user_id).await {
        Ok(profiles) => ok_response(
            "pet.list_loaded",
            "宠物档案列表已加载",
            PetProfilesData::from(profiles),
        ),
        Err(error) => error_response(&error),
    }
}

async fn load_pet_profile(
    State(state): State<PetHttpState>,
    headers: HeaderMap,
    Path(pet_id): Path<Uuid>,
) -> Response {
    let Ok(owner_user_id) = current_user_id(&headers) else {
        return unauthorized_response();
    };

    match state.pet.load_pet_profile(owner_user_id, pet_id).await {
        Ok(profile) => ok_response(
            "pet.loaded",
            "宠物档案已加载",
            PetProfileData::from(profile),
        ),
        Err(error) => error_response(&error),
    }
}

async fn update_pet_profile(
    State(state): State<PetHttpState>,
    headers: HeaderMap,
    Path(pet_id): Path<Uuid>,
    Json(request): Json<UpdatePetProfileRequest>,
) -> Response {
    let Ok(owner_user_id) = current_user_id(&headers) else {
        return unauthorized_response();
    };

    let input = request.into_input(pet_id, owner_user_id);
    match state.pet.update_pet_profile(input).await {
        Ok(profile) => ok_response(
            "pet.updated",
            "宠物档案已更新",
            PetProfileData::from(profile),
        ),
        Err(error) => error_response(&error),
    }
}

async fn delete_pet_profile(
    State(state): State<PetHttpState>,
    headers: HeaderMap,
    Path(pet_id): Path<Uuid>,
    Json(request): Json<DeletePetProfileRequest>,
) -> Response {
    let Ok(owner_user_id) = current_user_id(&headers) else {
        return unauthorized_response();
    };

    let input = request.into_input(pet_id, owner_user_id);
    match state.pet.delete_pet_profile(input).await {
        Ok(profile) => ok_response(
            "pet.deleted",
            "宠物档案已删除",
            PetProfileData::from(profile),
        ),
        Err(error) => error_response(&error),
    }
}

async fn restore_pet_profile(
    State(state): State<PetHttpState>,
    headers: HeaderMap,
    Path(pet_id): Path<Uuid>,
) -> Response {
    let Ok(owner_user_id) = current_user_id(&headers) else {
        return unauthorized_response();
    };

    let input = maohuoban_pet_application::pet::RestorePetProfile {
        pet_id,
        owner_user_id,
    };
    match state.pet.restore_pet_profile(input).await {
        Ok(profile) => ok_response(
            "pet.restored",
            "宠物档案已恢复",
            PetProfileData::from(profile),
        ),
        Err(error) => error_response(&error),
    }
}

async fn upload_pet_avatar(
    State(state): State<PetHttpState>,
    headers: HeaderMap,
    Path(pet_id): Path<Uuid>,
    multipart: Multipart,
) -> Response {
    let Ok(owner_user_id) = current_user_id(&headers) else {
        return unauthorized_response();
    };

    let request = match UploadPetMediaRequest::from_multipart(multipart).await {
        Ok(request) => request,
        Err(error) => return error_response(&error),
    };
    let input = match request.into_avatar_input(pet_id, owner_user_id) {
        Ok(input) => input,
        Err(error) => return error_response(&error),
    };
    match state.pet.upload_pet_media(input).await {
        Ok(upload) => created_response(
            "pet.avatar_uploaded",
            "宠物头像已上传",
            PetMediaUploadData::from(upload),
        ),
        Err(error) => error_response(&error),
    }
}

async fn upload_pet_background_image(
    State(state): State<PetHttpState>,
    headers: HeaderMap,
    Path(pet_id): Path<Uuid>,
    multipart: Multipart,
) -> Response {
    let Ok(owner_user_id) = current_user_id(&headers) else {
        return unauthorized_response();
    };

    let request = match UploadPetMediaRequest::from_multipart(multipart).await {
        Ok(request) => request,
        Err(error) => return error_response(&error),
    };
    let input = match request.into_background_image_input(pet_id, owner_user_id) {
        Ok(input) => input,
        Err(error) => return error_response(&error),
    };
    match state.pet.upload_pet_media(input).await {
        Ok(upload) => created_response(
            "pet.background_uploaded",
            "宠物背景已上传",
            PetMediaUploadData::from(upload),
        ),
        Err(error) => error_response(&error),
    }
}

async fn upload_pet_background_video(
    State(state): State<PetHttpState>,
    headers: HeaderMap,
    Path(pet_id): Path<Uuid>,
    multipart: Multipart,
) -> Response {
    let Ok(owner_user_id) = current_user_id(&headers) else {
        return unauthorized_response();
    };

    let request = match UploadPetMediaRequest::from_multipart(multipart).await {
        Ok(request) => request,
        Err(error) => return error_response(&error),
    };
    let input = match request.into_background_video_input(pet_id, owner_user_id) {
        Ok(input) => input,
        Err(error) => return error_response(&error),
    };
    match state.pet.upload_pet_media(input).await {
        Ok(upload) => created_response(
            "pet.background_uploaded",
            "宠物背景已上传",
            PetMediaUploadData::from(upload),
        ),
        Err(error) => error_response(&error),
    }
}

async fn create_pet_profile(
    State(state): State<PetHttpState>,
    headers: HeaderMap,
    Json(request): Json<CreatePetProfileRequest>,
) -> Response {
    let Ok(owner_user_id) = current_user_id(&headers) else {
        return unauthorized_response();
    };

    let input = request.into_new_pet_profile(owner_user_id);
    match state.pet.create_pet_profile(input).await {
        Ok(profile) => created_response(
            "pet.created",
            "宠物档案已创建",
            PetProfileData::from(profile),
        ),
        Err(error) => error_response(&error),
    }
}

async fn import_trade_pet(
    State(state): State<PetHttpState>,
    headers: HeaderMap,
    Json(request): Json<TradePetImportRequest>,
) -> Response {
    let Ok(owner_user_id) = current_user_id(&headers) else {
        return unauthorized_response();
    };

    let input = request.into_input(owner_user_id);
    match state.pet.import_trade_pet(input).await {
        Ok(import) => created_response(
            "pet.trade_imported",
            "交易宠物已导入",
            TradePetImportData::from(import),
        ),
        Err(error) => error_response(&error),
    }
}

async fn create_pet_event(
    State(state): State<PetHttpState>,
    headers: HeaderMap,
    Path(pet_id): Path<Uuid>,
    Json(request): Json<CreatePetEventRequest>,
) -> Response {
    let Ok(actor_user_id) = current_user_id(&headers) else {
        return unauthorized_response();
    };

    let input = request.into_new_pet_event(pet_id, actor_user_id);
    match state.pet.create_pet_event(input).await {
        Ok(event) => created_response(
            "pet.event_created",
            "宠物事件已记录",
            PetEventData::from(event),
        ),
        Err(error) => error_response(&error),
    }
}

async fn load_pet_timeline(
    State(state): State<PetHttpState>,
    headers: HeaderMap,
    Path(pet_id): Path<Uuid>,
) -> Response {
    let Ok(owner_user_id) = current_user_id(&headers) else {
        return unauthorized_response();
    };

    match state.pet.load_pet_timeline(owner_user_id, pet_id).await {
        Ok(timeline) => ok_response(
            "pet.timeline_loaded",
            "宠物时间线已加载",
            PetTimelineData::from(timeline),
        ),
        Err(error) => error_response(&error),
    }
}

async fn load_pet_event_detail(
    State(state): State<PetHttpState>,
    headers: HeaderMap,
    Path(event_id): Path<Uuid>,
) -> Response {
    let Ok(owner_user_id) = current_user_id(&headers) else {
        return unauthorized_response();
    };

    match state
        .pet
        .load_pet_event_detail(owner_user_id, event_id)
        .await
    {
        Ok(event) => ok_response(
            "pet.event_loaded",
            "宠物事件已加载",
            PetEventData::from(event),
        ),
        Err(error) => error_response(&error),
    }
}

async fn list_merchant_pets(
    State(state): State<PetHttpState>,
    headers: HeaderMap,
    Path(merchant_id): Path<Uuid>,
    Query(query): Query<MerchantPetsQuery>,
) -> Response {
    let Ok(owner_user_id) = current_user_id(&headers) else {
        return unauthorized_response();
    };

    match state
        .pet
        .list_merchant_pets(owner_user_id, merchant_id, query.status)
        .await
    {
        Ok(pets) => ok_response(
            "merchant.pets_loaded",
            "商家宠物列表已加载",
            MerchantPetsData::new(merchant_id, query.status, pets),
        ),
        Err(error) => error_response(&error),
    }
}

async fn create_merchant_pet(
    State(state): State<PetHttpState>,
    headers: HeaderMap,
    Path(merchant_id): Path<Uuid>,
    Json(request): Json<CreateMerchantPetRequest>,
) -> Response {
    let Ok(owner_user_id) = current_user_id(&headers) else {
        return unauthorized_response();
    };

    let input = request.into_new_merchant_pet(merchant_id);
    match state.pet.create_merchant_pet(owner_user_id, input).await {
        Ok(profile) => created_response(
            "merchant.pet_created",
            "商家宠物已新增",
            PetProfileData::from(profile),
        ),
        Err(error) => error_response(&error),
    }
}

async fn publish_available_status(
    State(state): State<PetHttpState>,
    headers: HeaderMap,
    Path((merchant_id, pet_id)): Path<(Uuid, Uuid)>,
    Json(request): Json<PublishAvailableStatusRequest>,
) -> Response {
    let Ok(owner_user_id) = current_user_id(&headers) else {
        return unauthorized_response();
    };

    let input = request.into_input(merchant_id, pet_id, owner_user_id);
    match state
        .pet
        .publish_available_status(owner_user_id, input)
        .await
    {
        Ok(publication) => ok_response(
            "merchant.available_status_published",
            "可售状态已发布",
            MerchantAvailableStatusData::from(publication),
        ),
        Err(error) => error_response(&error),
    }
}

async fn load_merchant_litter_detail(
    State(state): State<PetHttpState>,
    headers: HeaderMap,
    Path((merchant_id, litter_id)): Path<(Uuid, Uuid)>,
) -> Response {
    let Ok(owner_user_id) = current_user_id(&headers) else {
        return unauthorized_response();
    };

    match state
        .pet
        .load_merchant_litter_detail(owner_user_id, merchant_id, litter_id)
        .await
    {
        Ok(detail) => ok_response(
            "merchant.litter_loaded",
            "窝次详情已加载",
            MerchantLitterDetailData::from(detail),
        ),
        Err(error) => error_response(&error),
    }
}

fn current_user_id(headers: &HeaderMap) -> Result<Uuid, ()> {
    let Some(value) = headers.get("x-maohuoban-user-id") else {
        return Err(());
    };
    let Ok(raw_user_id) = value.to_str() else {
        return Err(());
    };
    Uuid::parse_str(raw_user_id).map_err(|_| ())
}
