use std::sync::Arc;

use axum::{
    Json, Router,
    extract::{Multipart, State},
    http::{HeaderMap, StatusCode},
    response::{IntoResponse, Response},
    routing::{get, post},
};
use chrono::NaiveDate;
use maohuoban_auth_application::auth::AuthService;
use maohuoban_auth_domain::auth::{AuthError, AuthResult};
use maohuoban_profile_application::profile::{
    ProfileMediaKind, ProfileService, UpdateProfileInput, UploadProfileMediaInput,
};
use maohuoban_profile_domain::profile::{
    AvatarPresentation, ProfileError, ProfileFieldEditPolicy, ProfileMediaAsset, UserGender,
    UserProfile,
};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use uuid::Uuid;

use super::diagnostics::{
    ProfileMediaHttpUploadContext, record_profile_media_http_parse_failure,
    record_profile_media_http_request, record_profile_media_http_response,
};

/// `ProfileHttpState` 用户资料 HTTP 状态
/// 核心职责：
/// - 持有认证服务和资料应用服务
/// - 在 HTTP 层完成登录态校验和响应映射
#[derive(Clone)]
pub struct ProfileHttpState {
    profile: Arc<ProfileService>,
    auth: Arc<AuthService>,
}

impl ProfileHttpState {
    #[must_use]
    pub const fn new(profile: Arc<ProfileService>, auth: Arc<AuthService>) -> Self {
        Self { profile, auth }
    }
}

/// `build_profile_router` 构建用户资料路由
/// 核心职责：
/// - 注册当前用户资料读取接口
/// - 保持用户资料响应来自 `ProfileService` 单一事实源
pub fn build_profile_router(profile: Arc<ProfileService>, auth: Arc<AuthService>) -> Router {
    Router::new()
        .route(
            "/api/v1/profile/me",
            get(get_current_profile).patch(patch_current_profile),
        )
        .route(
            "/api/v1/profile/me/avatar",
            post(upload_current_profile_avatar),
        )
        .route(
            "/api/v1/profile/me/cover",
            post(upload_current_profile_cover),
        )
        .with_state(ProfileHttpState::new(profile, auth))
}

async fn get_current_profile(
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
            CurrentProfileData::from(profile),
        ),
        Err(error) => error_response(&error),
    }
}

async fn patch_current_profile(
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
            CurrentProfileData::from(profile),
        ),
        Err(error) => error_response(&error),
    }
}

async fn upload_current_profile_avatar(
    State(state): State<ProfileHttpState>,
    headers: HeaderMap,
    multipart: Multipart,
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

async fn upload_current_profile_cover(
    State(state): State<ProfileHttpState>,
    headers: HeaderMap,
    multipart: Multipart,
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
    multipart: Multipart,
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
            created_response(code, message, CurrentProfileData::from(profile))
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

fn ok_response<T>(code: &'static str, message: &'static str, data: T) -> Response
where
    T: Serialize,
{
    (
        StatusCode::OK,
        Json(ApiResponse {
            success: true,
            code,
            message: message.to_owned(),
            data: Some(data),
        }),
    )
        .into_response()
}

fn created_response<T>(code: &'static str, message: &'static str, data: T) -> Response
where
    T: Serialize,
{
    (
        StatusCode::CREATED,
        Json(ApiResponse {
            success: true,
            code,
            message: message.to_owned(),
            data: Some(data),
        }),
    )
        .into_response()
}

fn error_response(error: &ProfileError) -> Response {
    let (status, code, message) = match error {
        ProfileError::NotFound => (
            StatusCode::NOT_FOUND,
            "profile.not_found",
            "个人资料不存在".to_owned(),
        ),
        ProfileError::DisplayNameInvalid => (
            StatusCode::BAD_REQUEST,
            "profile.display_name_invalid",
            "昵称格式不符合要求".to_owned(),
        ),
        ProfileError::DisplayNameEditLimitExceeded => (
            StatusCode::TOO_MANY_REQUESTS,
            "profile.display_name_edit_limit_exceeded",
            "昵称修改次数已用完，请稍后再试".to_owned(),
        ),
        ProfileError::BioInvalid => (
            StatusCode::BAD_REQUEST,
            "profile.bio_invalid",
            "简介最多 100 字".to_owned(),
        ),
        ProfileError::BioEditLimitExceeded => (
            StatusCode::TOO_MANY_REQUESTS,
            "profile.bio_edit_limit_exceeded",
            "简介修改次数已用完，请稍后再试".to_owned(),
        ),
        ProfileError::GenderInvalid => (
            StatusCode::BAD_REQUEST,
            "profile.gender_invalid",
            "性别参数无效".to_owned(),
        ),
        ProfileError::BirthdayInvalid => (
            StatusCode::BAD_REQUEST,
            "profile.birthday_invalid",
            "生日日期无效".to_owned(),
        ),
        ProfileError::MediaFileRequired => (
            StatusCode::BAD_REQUEST,
            "profile.media_file_required",
            "请先选择图片".to_owned(),
        ),
        ProfileError::MediaTypeInvalid => (
            StatusCode::BAD_REQUEST,
            "profile.media_type_invalid",
            "仅支持 JPG、PNG 或 WebP 图片".to_owned(),
        ),
        ProfileError::MediaTooLarge => (
            StatusCode::PAYLOAD_TOO_LARGE,
            "profile.media_too_large",
            "图片过大，请重新选择".to_owned(),
        ),
        ProfileError::MediaDecodeFailed => (
            StatusCode::BAD_REQUEST,
            "profile.media_decode_failed",
            "图片文件无法识别".to_owned(),
        ),
        ProfileError::Infrastructure(_) => (
            StatusCode::INTERNAL_SERVER_ERROR,
            "profile.internal_error",
            "个人资料暂时不可用，请稍后再试".to_owned(),
        ),
    };

    (
        status,
        Json(ApiResponse::<Value> {
            success: false,
            code,
            message,
            data: None,
        }),
    )
        .into_response()
}

fn unauthorized_response() -> Response {
    (
        StatusCode::UNAUTHORIZED,
        Json(ApiResponse::<Value> {
            success: false,
            code: "auth.session_expired",
            message: "登录状态已过期，请重新登录".to_owned(),
            data: None,
        }),
    )
        .into_response()
}

/// `UploadProfileMediaRequest` 用户资料媒体上传请求
/// 核心职责：
/// - 承接 multipart 解包后的图片字段
/// - 转换为应用层用户资料媒体上传命令
#[derive(Debug)]
struct UploadProfileMediaRequest {
    file_name: String,
    mime_type: String,
    content: Vec<u8>,
    source_client: Option<String>,
}

impl UploadProfileMediaRequest {
    async fn from_multipart(mut multipart: Multipart) -> Result<Self, ProfileError> {
        let mut file_name = None;
        let mut mime_type = None;
        let mut content = None;
        let mut source_client = None;

        while let Some(field) = multipart
            .next_field()
            .await
            .map_err(|_| ProfileError::MediaFileRequired)?
        {
            match field.name() {
                Some("file") => {
                    file_name = Some(
                        field
                            .file_name()
                            .filter(|value| !value.trim().is_empty())
                            .unwrap_or("profile-media.bin")
                            .to_owned(),
                    );
                    mime_type = Some(
                        field
                            .content_type()
                            .filter(|value| !value.trim().is_empty())
                            .unwrap_or("application/octet-stream")
                            .to_owned(),
                    );
                    let bytes = field
                        .bytes()
                        .await
                        .map_err(|_| ProfileError::MediaFileRequired)?;
                    content = Some(bytes.to_vec());
                }
                Some("source_client") => {
                    let value = field
                        .text()
                        .await
                        .map_err(|_| ProfileError::MediaFileRequired)?;
                    let trimmed = value.trim();
                    if !trimmed.is_empty() {
                        source_client = Some(trimmed.to_owned());
                    }
                }
                _ => {}
            }
        }

        Ok(Self {
            file_name: file_name.unwrap_or_else(|| "profile-media.bin".to_owned()),
            mime_type: mime_type.unwrap_or_else(|| "application/octet-stream".to_owned()),
            content: content.ok_or(ProfileError::MediaFileRequired)?,
            source_client,
        })
    }

    fn into_input(self, user_id: Uuid, kind: ProfileMediaKind) -> UploadProfileMediaInput {
        UploadProfileMediaInput {
            user_id,
            kind,
            file_name: self.file_name,
            mime_type: self.mime_type,
            content: self.content,
            source_client: self.source_client,
        }
    }
}

/// `UpdateCurrentProfileRequest` 当前用户资料更新请求
/// 核心职责：
/// - 接收个人资料页可编辑字段的局部更新
/// - 将 HTTP 字符串字段转换为应用层输入
#[derive(Debug, Deserialize)]
struct UpdateCurrentProfileRequest {
    display_name: Option<String>,
    bio: Option<String>,
    gender: Option<String>,
    is_gender_visible: Option<bool>,
    birthday: Option<String>,
}

impl UpdateCurrentProfileRequest {
    fn into_input(self, user_id: Uuid) -> Result<UpdateProfileInput, ProfileError> {
        Ok(UpdateProfileInput {
            user_id,
            display_name: self.display_name,
            bio: self.bio,
            gender: self
                .gender
                .map(|gender| parse_gender(&gender))
                .transpose()?,
            is_gender_visible: self.is_gender_visible,
            birthday: self
                .birthday
                .map(|birthday| parse_birthday(&birthday))
                .transpose()?,
        })
    }
}

fn parse_gender(value: &str) -> Result<UserGender, ProfileError> {
    match value {
        "male" => Ok(UserGender::Male),
        "female" => Ok(UserGender::Female),
        "unknown" => Ok(UserGender::Unknown),
        _ => Err(ProfileError::GenderInvalid),
    }
}

fn parse_birthday(value: &str) -> Result<NaiveDate, ProfileError> {
    NaiveDate::parse_from_str(value, "%Y-%m-%d").map_err(|_| ProfileError::BirthdayInvalid)
}

/// `ApiResponse` 统一接口响应
/// 核心职责：
/// - 固定 success、code、message、data 格式
/// - 与认证接口保持一致的客户端契约
#[derive(Debug, Serialize)]
struct ApiResponse<T>
where
    T: Serialize,
{
    success: bool,
    code: &'static str,
    message: String,
    data: Option<T>,
}

/// `CurrentProfileData` 当前用户资料响应
/// 核心职责：
/// - 返回编辑资料页和我的页所需的资料字段
/// - 避免公开注册序号和勋章数组
#[derive(Debug, Serialize)]
struct CurrentProfileData {
    user_id: String,
    maohuoban_id: String,
    display_name: String,
    default_display_name: String,
    bio: Option<String>,
    gender: &'static str,
    is_gender_visible: bool,
    birthday: Option<String>,
    birthday_display_text: Option<String>,
    avatar: Option<ProfileMediaData>,
    cover: Option<ProfileMediaData>,
    avatar_presentation: AvatarPresentation,
    display_name_edit_policy: Option<ProfileFieldEditPolicy>,
    bio_edit_policy: Option<ProfileFieldEditPolicy>,
}

impl From<UserProfile> for CurrentProfileData {
    fn from(profile: UserProfile) -> Self {
        let avatar_presentation = profile.avatar_presentation();
        let birthday = profile.birthday.map(|date| date.to_string());
        Self {
            user_id: profile.user_id.to_string(),
            maohuoban_id: profile.maohuoban_id,
            display_name: profile.display_name,
            default_display_name: profile.default_display_name,
            bio: profile.bio,
            gender: profile.gender.as_str(),
            is_gender_visible: profile.is_gender_visible,
            birthday: birthday.clone(),
            birthday_display_text: birthday,
            avatar: profile.avatar.map(ProfileMediaData::from),
            cover: profile.cover.map(ProfileMediaData::from),
            avatar_presentation,
            display_name_edit_policy: profile.display_name_edit_policy,
            bio_edit_policy: profile.bio_edit_policy,
        }
    }
}

/// `ProfileMediaData` 用户资料媒体响应
/// 核心职责：
/// - 向前端输出可直接展示的媒资字段
/// - 保持响应字段名和 iOS 解码模型稳定
#[derive(Debug, Serialize)]
struct ProfileMediaData {
    asset_id: String,
    url: String,
    width: Option<i32>,
    height: Option<i32>,
    mime_type: String,
    updated_at: chrono::DateTime<chrono::Utc>,
}

impl From<ProfileMediaAsset> for ProfileMediaData {
    fn from(asset: ProfileMediaAsset) -> Self {
        Self {
            asset_id: asset.asset_id.to_string(),
            url: asset.url,
            width: asset.width,
            height: asset.height,
            mime_type: asset.mime_type,
            updated_at: asset.updated_at,
        }
    }
}
