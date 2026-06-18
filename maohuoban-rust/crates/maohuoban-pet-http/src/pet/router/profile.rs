use axum::{
    Json,
    extract::{Path, State},
    http::HeaderMap,
    response::Response,
};
use maohuoban_pet_application::pet::RestorePetProfile;
use uuid::Uuid;

use super::{PetHttpState, auth::current_user_id};
use crate::pet::{
    diagnostics::{record_profile_http, record_profile_http_response},
    dto::{
        CreatePetProfileRequest, DeletePetProfileRequest, PetProfileData, PetProfilesData,
        TradePetImportData, TradePetImportRequest, UpdatePetProfileRequest,
    },
    response::{created_response, error_response, ok_response, unauthorized_response},
};

pub(super) async fn list_pet_profiles(
    State(state): State<PetHttpState>,
    headers: HeaderMap,
) -> Response {
    let Ok(owner_user_id) = current_user_id(&state.auth, &headers).await else {
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

pub(super) async fn load_pet_profile(
    State(state): State<PetHttpState>,
    headers: HeaderMap,
    Path(pet_id): Path<Uuid>,
) -> Response {
    let Ok(owner_user_id) = current_user_id(&state.auth, &headers).await else {
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

pub(super) async fn update_pet_profile(
    State(state): State<PetHttpState>,
    headers: HeaderMap,
    Path(pet_id): Path<Uuid>,
    Json(request): Json<UpdatePetProfileRequest>,
) -> Response {
    let Ok(owner_user_id) = current_user_id(&state.auth, &headers).await else {
        return unauthorized_response();
    };

    let input = request.into_input(pet_id, owner_user_id);
    record_profile_http(
        "http.request",
        "update",
        owner_user_id,
        Some(pet_id),
        input.breed.as_deref(),
        true,
    );
    match state.pet.update_pet_profile(input).await {
        Ok(update) => {
            let code = if update.changed {
                "pet.updated"
            } else {
                "pet.unchanged"
            };
            let message = if update.changed {
                "宠物档案已更新"
            } else {
                "宠物档案未变化"
            };
            record_profile_http_response("update", owner_user_id, &update.profile);
            ok_response(code, message, PetProfileData::from(update.profile))
        }
        Err(error) => error_response(&error),
    }
}

pub(super) async fn delete_pet_profile(
    State(state): State<PetHttpState>,
    headers: HeaderMap,
    Path(pet_id): Path<Uuid>,
    Json(request): Json<DeletePetProfileRequest>,
) -> Response {
    let Ok(owner_user_id) = current_user_id(&state.auth, &headers).await else {
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

pub(super) async fn restore_pet_profile(
    State(state): State<PetHttpState>,
    headers: HeaderMap,
    Path(pet_id): Path<Uuid>,
) -> Response {
    let Ok(owner_user_id) = current_user_id(&state.auth, &headers).await else {
        return unauthorized_response();
    };

    let input = RestorePetProfile {
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

pub(super) async fn create_pet_profile(
    State(state): State<PetHttpState>,
    headers: HeaderMap,
    Json(request): Json<CreatePetProfileRequest>,
) -> Response {
    let Ok(owner_user_id) = current_user_id(&state.auth, &headers).await else {
        return unauthorized_response();
    };

    let input = request.into_new_pet_profile(owner_user_id);
    record_profile_http(
        "http.request",
        "create",
        owner_user_id,
        None,
        input.breed.as_deref(),
        true,
    );
    match state.pet.create_pet_profile(input).await {
        Ok(profile) => {
            record_profile_http_response("create", owner_user_id, &profile);
            created_response(
                "pet.created",
                "宠物档案已创建",
                PetProfileData::from(profile),
            )
        }
        Err(error) => error_response(&error),
    }
}

pub(super) async fn import_trade_pet(
    State(state): State<PetHttpState>,
    headers: HeaderMap,
    Json(request): Json<TradePetImportRequest>,
) -> Response {
    let Ok(owner_user_id) = current_user_id(&state.auth, &headers).await else {
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
