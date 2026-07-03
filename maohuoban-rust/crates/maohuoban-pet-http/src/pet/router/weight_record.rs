use axum::{
    Json,
    extract::{Path, State},
    response::Response,
};
use maohuoban_auth_http::auth::extractor::AuthenticatedUser;
use maohuoban_pet_application::pet::DeletePetWeightRecord;
use uuid::Uuid;

use super::PetHttpState;
use crate::pet::{
    dto::{
        CreatePetWeightRecordRequest, DeletedPetWeightRecordData, PetWeightRecordData,
        PetWeightRecordListData, UpdatePetWeightRecordRequest,
    },
    response::{created_response, error_response, ok_response},
};

pub(super) async fn create_pet_weight_record(
    State(state): State<PetHttpState>,
    Path(pet_id): Path<Uuid>,
    actor: AuthenticatedUser,
    Json(request): Json<CreatePetWeightRecordRequest>,
) -> Response {
    let actor_user_id = actor.user_id();
    let input = request.into_input(pet_id, actor_user_id);
    match state.pet.create_pet_weight_record(input).await {
        Ok(record) => created_response(
            "pet.weight_record_created",
            "体重记录已保存",
            PetWeightRecordData::from(record),
        ),
        Err(error) => error_response(&error),
    }
}

pub(super) async fn list_pet_weight_records(
    State(state): State<PetHttpState>,
    Path(pet_id): Path<Uuid>,
    actor: AuthenticatedUser,
) -> Response {
    let owner_user_id = actor.user_id();
    match state
        .pet
        .list_pet_weight_records(owner_user_id, pet_id)
        .await
    {
        Ok(records) => ok_response(
            "pet.weight_records_loaded",
            "体重记录已加载",
            PetWeightRecordListData::from(records),
        ),
        Err(error) => error_response(&error),
    }
}

pub(super) async fn load_pet_weight_record(
    State(state): State<PetHttpState>,
    Path(record_id): Path<Uuid>,
    actor: AuthenticatedUser,
) -> Response {
    let owner_user_id = actor.user_id();
    match state
        .pet
        .load_pet_weight_record(owner_user_id, record_id)
        .await
    {
        Ok(record) => ok_response(
            "pet.weight_record_loaded",
            "体重记录已加载",
            PetWeightRecordData::from(record),
        ),
        Err(error) => error_response(&error),
    }
}

pub(super) async fn update_pet_weight_record(
    State(state): State<PetHttpState>,
    Path(record_id): Path<Uuid>,
    actor: AuthenticatedUser,
    Json(request): Json<UpdatePetWeightRecordRequest>,
) -> Response {
    let actor_user_id = actor.user_id();
    let input = request.into_input(record_id, actor_user_id);
    match state.pet.update_pet_weight_record(input).await {
        Ok(record) => ok_response(
            "pet.weight_record_updated",
            "体重记录已更新",
            PetWeightRecordData::from(record),
        ),
        Err(error) => error_response(&error),
    }
}

pub(super) async fn delete_pet_weight_record(
    State(state): State<PetHttpState>,
    Path(record_id): Path<Uuid>,
    actor: AuthenticatedUser,
) -> Response {
    let actor_user_id = actor.user_id();
    match state
        .pet
        .delete_pet_weight_record(DeletePetWeightRecord {
            record_id,
            actor_user_id,
        })
        .await
    {
        Ok(record) => ok_response(
            "pet.weight_record_deleted",
            "体重记录已删除",
            DeletedPetWeightRecordData::from(record),
        ),
        Err(error) => error_response(&error),
    }
}
