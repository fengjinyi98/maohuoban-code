use axum::{
    Json,
    extract::{Multipart, Path, State},
    response::Response,
};
use maohuoban_auth_http::auth::extractor::AuthenticatedUser;
use uuid::Uuid;

use super::PetHttpState;
use crate::pet::{
    diagnostics::{
        record_binding_http_request, record_binding_http_response, record_upload_http_request,
        record_upload_http_response,
    },
    dto::{
        BindUploadedPetMediaRequest, PetMediaUploadData, UploadPetLivePhotoRequest,
        UploadPetMediaRequest,
    },
    response::{created_response, error_response},
};

pub(super) async fn upload_pending_pet_avatar(
    State(state): State<PetHttpState>,
    actor: AuthenticatedUser,
    multipart: Multipart,
) -> Response {
    let owner_user_id = actor.user_id();

    let request = match UploadPetMediaRequest::from_multipart(multipart).await {
        Ok(request) => request,
        Err(error) => return error_response(&error),
    };
    let input = request.into_pending_avatar_input(owner_user_id);
    record_upload_http_request(&input);
    match state.pet.upload_pending_pet_media(input).await {
        Ok(upload) => {
            record_upload_http_response(owner_user_id, &upload);
            created_response(
                "pet.media_uploaded",
                "媒体已上传",
                PetMediaUploadData::from(upload),
            )
        }
        Err(error) => error_response(&error),
    }
}

pub(super) async fn bind_uploaded_pet_media(
    State(state): State<PetHttpState>,
    Path(pet_id): Path<Uuid>,
    actor: AuthenticatedUser,
    Json(request): Json<BindUploadedPetMediaRequest>,
) -> Response {
    let owner_user_id = actor.user_id();

    let input = request.into_input(pet_id, owner_user_id);
    record_binding_http_request(&input);
    match state.pet.bind_uploaded_pet_media(input).await {
        Ok(upload) => {
            record_binding_http_response(owner_user_id, pet_id, &upload);
            created_response(
                "pet.media_bound",
                "宠物媒体已保存",
                PetMediaUploadData::from(upload),
            )
        }
        Err(error) => error_response(&error),
    }
}

pub(super) async fn upload_pending_pet_background_image(
    State(state): State<PetHttpState>,
    actor: AuthenticatedUser,
    multipart: Multipart,
) -> Response {
    let owner_user_id = actor.user_id();

    let request = match UploadPetMediaRequest::from_multipart(multipart).await {
        Ok(request) => request,
        Err(error) => return error_response(&error),
    };
    let input = request.into_pending_background_image_input(owner_user_id);
    record_upload_http_request(&input);
    match state.pet.upload_pending_pet_media(input).await {
        Ok(upload) => {
            record_upload_http_response(owner_user_id, &upload);
            created_response(
                "pet.media_uploaded",
                "媒体已上传",
                PetMediaUploadData::from(upload),
            )
        }
        Err(error) => error_response(&error),
    }
}

pub(super) async fn upload_pending_pet_background_video(
    State(state): State<PetHttpState>,
    actor: AuthenticatedUser,
    multipart: Multipart,
) -> Response {
    let owner_user_id = actor.user_id();

    let request = match UploadPetMediaRequest::from_multipart(multipart).await {
        Ok(request) => request,
        Err(error) => return error_response(&error),
    };
    let input = request.into_pending_background_video_input(owner_user_id);
    record_upload_http_request(&input);
    match state.pet.upload_pending_pet_media(input).await {
        Ok(upload) => {
            record_upload_http_response(owner_user_id, &upload);
            created_response(
                "pet.media_uploaded",
                "媒体已上传",
                PetMediaUploadData::from(upload),
            )
        }
        Err(error) => error_response(&error),
    }
}

pub(super) async fn upload_pending_pet_background_live_photo(
    State(state): State<PetHttpState>,
    actor: AuthenticatedUser,
    multipart: Multipart,
) -> Response {
    let owner_user_id = actor.user_id();

    let request = match UploadPetLivePhotoRequest::from_multipart(multipart).await {
        Ok(request) => request,
        Err(error) => return error_response(&error),
    };
    let input = request.into_pending_live_photo_input(owner_user_id);
    match state.pet.upload_pending_pet_live_photo(input).await {
        Ok(upload) => created_response(
            "pet.media_uploaded",
            "媒体已上传",
            PetMediaUploadData::from(upload),
        ),
        Err(error) => error_response(&error),
    }
}
