use axum::{
    Json,
    http::StatusCode,
    response::{IntoResponse, Response},
};
use maohuoban_pet_domain::pet::PetError;
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

pub(super) fn error_response(error: &PetError) -> Response {
    let (status, code, message) = match error {
        PetError::InvalidInput(message) => (
            StatusCode::BAD_REQUEST,
            "pet.invalid_input",
            message.clone(),
        ),
        PetError::NameEditLimitExceeded => (
            StatusCode::TOO_MANY_REQUESTS,
            "pet.name_edit_limit_exceeded",
            "30 天内最多修改 5 次宠物名字".to_owned(),
        ),
        PetError::PetNotFound => (
            StatusCode::NOT_FOUND,
            "pet.not_found",
            "宠物档案不存在".to_owned(),
        ),
        PetError::FoodInventoryNotFound => (
            StatusCode::NOT_FOUND,
            "pet.food_inventory_not_found",
            "商品不存在".to_owned(),
        ),
        PetError::DietAssignmentConflict(message) => (
            StatusCode::CONFLICT,
            "pet.diet_assignment_conflict",
            message.clone(),
        ),
        PetError::DietAssignmentNotFound => (
            StatusCode::NOT_FOUND,
            "pet.diet_assignment_not_found",
            "饮食配置不存在".to_owned(),
        ),
        PetError::Forbidden => (
            StatusCode::FORBIDDEN,
            "pet.forbidden",
            "无权访问该宠物档案".to_owned(),
        ),
        PetError::Infrastructure(_) => (
            StatusCode::INTERNAL_SERVER_ERROR,
            "pet.internal_error",
            "宠物服务暂时不可用，请稍后再试".to_owned(),
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
/// - 与认证、法务和首页接口保持一致的客户端契约
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
