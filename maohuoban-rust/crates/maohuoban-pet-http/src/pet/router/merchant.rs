use axum::{
    Json,
    extract::{Path, Query, State},
    http::HeaderMap,
    response::Response,
};
use uuid::Uuid;

use super::{PetHttpState, auth::current_user_id};
use crate::pet::{
    dto::{
        CreateMerchantPetRequest, MerchantAvailableStatusData, MerchantLitterDetailData,
        MerchantPetsData, MerchantPetsQuery, PetProfileData, PublishAvailableStatusRequest,
    },
    response::{created_response, error_response, ok_response, unauthorized_response},
};

pub(super) async fn list_merchant_pets(
    State(state): State<PetHttpState>,
    headers: HeaderMap,
    Path(merchant_id): Path<Uuid>,
    Query(query): Query<MerchantPetsQuery>,
) -> Response {
    let Ok(owner_user_id) = current_user_id(&state.auth, &headers).await else {
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

pub(super) async fn create_merchant_pet(
    State(state): State<PetHttpState>,
    headers: HeaderMap,
    Path(merchant_id): Path<Uuid>,
    Json(request): Json<CreateMerchantPetRequest>,
) -> Response {
    let Ok(owner_user_id) = current_user_id(&state.auth, &headers).await else {
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

pub(super) async fn publish_available_status(
    State(state): State<PetHttpState>,
    headers: HeaderMap,
    Path((merchant_id, pet_id)): Path<(Uuid, Uuid)>,
    Json(request): Json<PublishAvailableStatusRequest>,
) -> Response {
    let Ok(owner_user_id) = current_user_id(&state.auth, &headers).await else {
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

pub(super) async fn load_merchant_litter_detail(
    State(state): State<PetHttpState>,
    headers: HeaderMap,
    Path((merchant_id, litter_id)): Path<(Uuid, Uuid)>,
) -> Response {
    let Ok(owner_user_id) = current_user_id(&state.auth, &headers).await else {
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
