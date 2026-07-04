use axum::{
    Json,
    extract::{Path, State},
    response::Response,
};
use maohuoban_auth_http::auth::extractor::AuthenticatedUser;
use uuid::Uuid;

use super::PetHttpState;
use crate::pet::{
    dto::{CreatePetEventRequest, DeletedPetEventData, PetEventData, PetTimelineData},
    response::{created_response, error_response, ok_response},
};
use maohuoban_pet_application::pet::DeletePetEvent;

pub(super) async fn create_pet_event(
    State(state): State<PetHttpState>,
    Path(pet_id): Path<Uuid>,
    actor: AuthenticatedUser,
    Json(request): Json<CreatePetEventRequest>,
) -> Response {
    let actor_user_id = actor.user_id();

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

pub(super) async fn load_pet_timeline(
    State(state): State<PetHttpState>,
    Path(pet_id): Path<Uuid>,
    actor: AuthenticatedUser,
) -> Response {
    let owner_user_id = actor.user_id();

    match state.pet.load_pet_timeline(owner_user_id, pet_id).await {
        Ok(timeline) => ok_response(
            "pet.timeline_loaded",
            "宠物时间线已加载",
            PetTimelineData::from(timeline),
        ),
        Err(error) => error_response(&error),
    }
}

pub(super) async fn load_pet_event_detail(
    State(state): State<PetHttpState>,
    Path(event_id): Path<Uuid>,
    actor: AuthenticatedUser,
) -> Response {
    let owner_user_id = actor.user_id();

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

pub(super) async fn delete_pet_event(
    State(state): State<PetHttpState>,
    Path(event_id): Path<Uuid>,
    actor: AuthenticatedUser,
) -> Response {
    let actor_user_id = actor.user_id();

    match state
        .pet
        .delete_pet_event(DeletePetEvent {
            event_id,
            actor_user_id,
        })
        .await
    {
        Ok(event) => ok_response(
            "pet.event_deleted",
            "宠物事件已删除",
            DeletedPetEventData::from(event),
        ),
        Err(error) => error_response(&error),
    }
}
