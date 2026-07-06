use axum::{
    Json,
    http::StatusCode,
    response::{IntoResponse, Response},
};
use maohuoban_samecity_domain::samecity::SameCityError;
use serde::Serialize;
use serde_json::Value;

pub(super) fn ok_response<T>(code: &'static str, message: &'static str, data: T) -> Response
where
    T: Serialize,
{
    api_response(StatusCode::OK, true, code, message, Some(data))
}

pub(super) fn created_response<T>(code: &'static str, message: &'static str, data: T) -> Response
where
    T: Serialize,
{
    api_response(StatusCode::CREATED, true, code, message, Some(data))
}

pub(super) fn error_response(error: &SameCityError) -> Response {
    let (status, code, message) = match error {
        SameCityError::InvalidInput(message) => (
            StatusCode::BAD_REQUEST,
            "samecity.invalid_input",
            message.clone(),
        ),
        SameCityError::HospitalNotFound => (
            StatusCode::NOT_FOUND,
            "samecity.hospital_not_found",
            "医院不存在".to_owned(),
        ),
        SameCityError::PetForbidden => (
            StatusCode::FORBIDDEN,
            "samecity.pet_forbidden",
            "无权为该宠物预约医院".to_owned(),
        ),
        SameCityError::AppointmentNotFound => (
            StatusCode::NOT_FOUND,
            "samecity.appointment_not_found",
            "预约不存在".to_owned(),
        ),
        SameCityError::AppointmentNotCancellable => (
            StatusCode::CONFLICT,
            "samecity.appointment_not_cancellable",
            "当前预约状态无法取消".to_owned(),
        ),
        SameCityError::Infrastructure(_) => (
            StatusCode::INTERNAL_SERVER_ERROR,
            "samecity.internal_error",
            "同城服务暂时不可用，请稍后再试".to_owned(),
        ),
    };

    api_response::<Value>(status, false, code, &message, None)
}

fn api_response<T>(
    status: StatusCode,
    success: bool,
    code: &'static str,
    message: &str,
    data: Option<T>,
) -> Response
where
    T: Serialize,
{
    (
        status,
        Json(ApiResponse {
            success,
            code,
            message: message.to_owned(),
            data,
        }),
    )
        .into_response()
}

/// ApiResponse 统一接口响应
/// 核心职责：
/// - 固定 success、code、message、data 格式
/// - 与认证、法务、首页和宠物接口保持一致
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
