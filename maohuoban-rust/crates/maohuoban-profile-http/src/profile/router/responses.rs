use axum::{
    Json,
    http::StatusCode,
    response::{IntoResponse, Response},
};
use maohuoban_profile_domain::profile::ProfileError;
use serde::Serialize;
use serde_json::Value;

/// `ApiResponse` 统一接口响应
/// 核心职责：
/// - 固定 success、code、message、data 格式
/// - 与认证接口保持一致的客户端契约
#[derive(Debug, Serialize)]
pub(super) struct ApiResponse<T>
where
    T: Serialize,
{
    success: bool,
    code: &'static str,
    message: String,
    data: Option<T>,
}

pub(super) fn ok_response<T>(code: &'static str, message: &'static str, data: T) -> Response
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

pub(super) fn created_response<T>(code: &'static str, message: &'static str, data: T) -> Response
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

pub(super) fn error_response(error: &ProfileError) -> Response {
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
        ProfileError::MediaBodyTooLarge => (
            StatusCode::PAYLOAD_TOO_LARGE,
            "profile.media_body_too_large",
            "图片太大，请选择较小的图片".to_owned(),
        ),
        ProfileError::MediaMultipartInvalid => (
            StatusCode::BAD_REQUEST,
            "profile.media_multipart_invalid",
            "图片上传数据无效，请重试".to_owned(),
        ),
        ProfileError::MediaTypeInvalid => (
            StatusCode::UNSUPPORTED_MEDIA_TYPE,
            "profile.media_type_invalid",
            "仅支持 JPG、PNG 或 WebP 图片".to_owned(),
        ),
        ProfileError::MediaTooLarge => (
            StatusCode::PAYLOAD_TOO_LARGE,
            "profile.media_too_large",
            "图片过大，请重新选择".to_owned(),
        ),
        ProfileError::MediaDecodeFailed => (
            StatusCode::UNPROCESSABLE_ENTITY,
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
