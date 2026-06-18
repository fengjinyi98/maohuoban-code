use axum::{
    Json,
    extract::{Path, State},
    http::HeaderMap,
    response::Response,
};
use uuid::Uuid;

use super::{PetHttpState, auth::current_user_id};
use crate::pet::{
    dto::{CreatePetEventRequest, PetEventData, PetTimelineData},
    response::{created_response, error_response, ok_response, unauthorized_response},
};

pub(super) async fn create_pet_event(
    State(state): State<PetHttpState>,
    headers: HeaderMap,
    Path(pet_id): Path<Uuid>,
    Json(request): Json<CreatePetEventRequest>,
) -> Response {
    let Ok(actor_user_id) = current_user_id(&state.auth, &headers).await else {
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

pub(super) async fn load_pet_timeline(
    State(state): State<PetHttpState>,
    headers: HeaderMap,
    Path(pet_id): Path<Uuid>,
) -> Response {
    let Ok(owner_user_id) = current_user_id(&state.auth, &headers).await else {
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

pub(super) async fn load_pet_event_detail(
    State(state): State<PetHttpState>,
    headers: HeaderMap,
    Path(event_id): Path<Uuid>,
) -> Response {
    let Ok(owner_user_id) = current_user_id(&state.auth, &headers).await else {
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
