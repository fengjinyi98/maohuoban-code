use axum::{
    Json,
    http::StatusCode,
    response::{IntoResponse, Response},
};
use serde::Serialize;
use serde_json::Value;

/// HisError Web HIS 接口错误
/// 核心职责：
/// - 表达医院端真实接口的稳定失败类型
/// - 将权限、空资源和未接入写入能力映射为明确 HTTP 响应
#[derive(Debug, thiserror::Error)]
pub enum HisError {
    #[error("forbidden")]
    Forbidden,
    #[error("not found: {0}")]
    NotFound(String),
    #[error("conflict: {0}")]
    Conflict(String),
    #[error("infrastructure: {0}")]
    Infrastructure(String),
}

/// ok_response 构造成功响应
/// 核心职责：
/// - 统一 success/code/message/data 格式
/// - 保持 Web HIS 与 App 后端响应风格一致
pub fn ok_response<T>(code: &'static str, message: &'static str, data: T) -> Response
where
    T: Serialize,
{
    api_response(StatusCode::OK, true, code, message, Some(data))
}

/// error_response 构造失败响应
/// 核心职责：
/// - 将 HIS 错误映射到稳定 HTTP 状态
/// - 避免前端收到 mock 风格错误结构
pub fn error_response(error: HisError) -> Response {
    let (status, code, message) = match error {
        HisError::Forbidden => (
            StatusCode::FORBIDDEN,
            "his.forbidden",
            "无权访问该医院 HIS".to_owned(),
        ),
        HisError::NotFound(message) => (StatusCode::NOT_FOUND, "his.not_found", message),
        HisError::Conflict(message) => (StatusCode::CONFLICT, "his.conflict", message),
        HisError::Infrastructure(_) => (
            StatusCode::INTERNAL_SERVER_ERROR,
            "his.internal_error",
            "HIS 服务暂时不可用，请稍后再试".to_owned(),
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

pub fn to_infrastructure_error(error: sqlx::Error) -> HisError {
    HisError::Infrastructure(error.to_string())
}
