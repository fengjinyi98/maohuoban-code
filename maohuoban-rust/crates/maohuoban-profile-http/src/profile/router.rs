use std::sync::Arc;

use axum::{
    Json, Router,
    extract::State,
    http::{HeaderMap, StatusCode},
    response::{IntoResponse, Response},
    routing::get,
};
use chrono::NaiveDate;
use maohuoban_auth_application::auth::AuthService;
use maohuoban_auth_domain::auth::{AuthError, AuthResult};
use maohuoban_profile_application::profile::{ProfileService, UpdateProfileInput};
use maohuoban_profile_domain::profile::{
    AvatarPresentation, ProfileError, ProfileFieldEditPolicy, UserGender, UserProfile,
};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use uuid::Uuid;

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
    avatar: Option<Value>,
    cover: Option<Value>,
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
            avatar: None,
            cover: None,
            avatar_presentation,
            display_name_edit_policy: profile.display_name_edit_policy,
            bio_edit_policy: profile.bio_edit_policy,
        }
    }
}
