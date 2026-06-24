use super::super::diagnostics::{
    ProfileMediaHttpUploadContext, record_profile_media_http_parse_failure,
    record_profile_media_http_request, record_profile_media_http_response,
};
use super::ProfileHttpState;
use super::requests::{UpdateCurrentProfileRequest, UploadProfileMediaRequest};
use super::responses::{created_response, error_response, ok_response, unauthorized_response};
use axum::{Json, extract::State, http::HeaderMap, response::Response};
use maohuoban_auth_application::auth::AuthService;
use maohuoban_auth_domain::auth::{AuthError, AuthResult};
use maohuoban_profile_application::profile::ProfileMediaKind;

pub(super) async fn get_current_profile(
    State(state): State<ProfileHttpState>,
    headers: HeaderMap,
) -> Response {
    let Ok(user) = current_user(&state.auth, &headers).await else {
        return unauthorized_response();
    };

    match state.profile.current_profile(user.id).await {
        Ok(profile) => ok_response(
            "profile.loaded",
            "个人资料已加载",
            super::mappers::CurrentProfileData::from(profile),
        ),
        Err(error) => error_response(&error),
    }
}

pub(super) async fn patch_current_profile(
    State(state): State<ProfileHttpState>,
    headers: HeaderMap,
    Json(request): Json<UpdateCurrentProfileRequest>,
) -> Response {
    let Ok(user) = current_user(&state.auth, &headers).await else {
        return unauthorized_response();
    };

    let input = match request.into_input(user.id) {
        Ok(input) => input,
        Err(error) => return error_response(&error),
    };

    match state.profile.update_current_profile(input).await {
        Ok(profile) => ok_response(
            "profile.updated",
            "个人资料已更新",
            super::mappers::CurrentProfileData::from(profile),
        ),
        Err(error) => error_response(&error),
    }
}

pub(super) async fn upload_current_profile_avatar(
    State(state): State<ProfileHttpState>,
    headers: HeaderMap,
    multipart: axum::extract::Multipart,
) -> Response {
    upload_current_profile_media(
        state,
        headers,
        multipart,
        ProfileMediaKind::Avatar,
        "profile.avatar_uploaded",
        "头像已保存",
    )
    .await
}

pub(super) async fn upload_current_profile_cover(
    State(state): State<ProfileHttpState>,
    headers: HeaderMap,
    multipart: axum::extract::Multipart,
) -> Response {
    upload_current_profile_media(
        state,
        headers,
        multipart,
        ProfileMediaKind::Cover,
        "profile.cover_uploaded",
        "主页背景已保存",
    )
    .await
}

async fn upload_current_profile_media(
    state: ProfileHttpState,
    headers: HeaderMap,
    multipart: axum::extract::Multipart,
    kind: ProfileMediaKind,
    code: &'static str,
    message: &'static str,
) -> Response {
    let Ok(user) = current_user(&state.auth, &headers).await else {
        return unauthorized_response();
    };

    let request = match UploadProfileMediaRequest::from_multipart(multipart).await {
        Ok(request) => request,
        Err(error) => {
            record_profile_media_http_parse_failure(user.id, kind, &error);
            return error_response(&error);
        }
    };
    let input = request.into_input(user.id, kind);
    let context = ProfileMediaHttpUploadContext::from_input(&input);
    record_profile_media_http_request(&context);
    let result = state.profile.upload_current_profile_media(input).await;
    match result {
        Ok(profile) => {
            record_profile_media_http_response(&context, Ok(&profile));
            created_response(
                code,
                message,
                super::mappers::CurrentProfileData::from(profile),
            )
        }
        Err(error) => {
            record_profile_media_http_response(&context, Err(&error));
            error_response(&error)
        }
    }
}

async fn current_user(
    auth: &AuthService,
    headers: &HeaderMap,
) -> AuthResult<maohuoban_auth_domain::auth::AuthUser> {
    let token = bearer_token(headers)?;
    auth.authenticate_access_token(token).await
}

fn bearer_token(headers: &HeaderMap) -> AuthResult<&str> {
    let value = headers
        .get("authorization")
        .ok_or(AuthError::AccessInvalid)?;
    let raw = value.to_str().map_err(|_| AuthError::AccessInvalid)?;
    raw.strip_prefix("Bearer ")
        .filter(|token| !token.is_empty())
        .ok_or(AuthError::AccessInvalid)
}
