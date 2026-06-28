//! response AI HTTP 响应工具
//! 核心职责：
//! - 提供统一 API 响应格式
//! - 提供 AI 错误到 HTTP 状态码的映射

use axum::{
    Json,
    http::StatusCode,
    response::{IntoResponse, Response},
};
use maohuoban_ai_domain::ai::{AiError, PROVIDER_USER_VISIBLE_FAILURE_MESSAGE};
use serde::Serialize;
use serde_json::Value;

/// ok_response 成功响应
pub fn ok_response<T>(code: &'static str, message: &'static str, data: T) -> Response
where
    T: Serialize,
{
    api_response(StatusCode::OK, true, code, message, Some(data))
}

/// unauthorized_response 未认证响应
#[must_use]
pub fn unauthorized_response() -> Response {
    api_response::<Value>(
        StatusCode::UNAUTHORIZED,
        false,
        "auth.session_expired",
        "登录状态已过期，请重新登录",
        None,
    )
}

/// ai_error_response AI 错误响应
#[must_use]
pub fn ai_error_response(error: &AiError) -> Response {
    let (status, code, message) = match error {
        AiError::InvalidInput(msg) => (StatusCode::BAD_REQUEST, "ai.invalid_input", msg.clone()),
        AiError::PetNotFound => (
            StatusCode::NOT_FOUND,
            "ai.pet_not_found",
            "宠物档案不存在或无权限".to_owned(),
        ),
        AiError::Unauthorized => (
            StatusCode::FORBIDDEN,
            "ai.unauthorized",
            "无权限访问该资源".to_owned(),
        ),
        AiError::Provider(error) => {
            let status = if matches!(
                error.category(),
                maohuoban_ai_domain::ai::ProviderErrorCategory::NotConfigured
            ) {
                StatusCode::SERVICE_UNAVAILABLE
            } else {
                StatusCode::BAD_GATEWAY
            };
            (
                status,
                match error.category() {
                    maohuoban_ai_domain::ai::ProviderErrorCategory::NotConfigured => {
                        "ai.provider.not_configured"
                    }
                    maohuoban_ai_domain::ai::ProviderErrorCategory::Timeout => {
                        "ai.provider.timeout"
                    }
                    maohuoban_ai_domain::ai::ProviderErrorCategory::RateLimited => {
                        "ai.provider.rate_limited"
                    }
                    maohuoban_ai_domain::ai::ProviderErrorCategory::Upstream => {
                        "ai.provider.upstream"
                    }
                    maohuoban_ai_domain::ai::ProviderErrorCategory::StreamInterrupted => {
                        "ai.provider.stream_interrupted"
                    }
                    maohuoban_ai_domain::ai::ProviderErrorCategory::InvalidResponse => {
                        "ai.provider.invalid_response"
                    }
                },
                PROVIDER_USER_VISIBLE_FAILURE_MESSAGE.to_owned(),
            )
        }
        AiError::ProviderNotConfigured => (
            StatusCode::SERVICE_UNAVAILABLE,
            "ai.provider_not_configured",
            "AI 服务暂未配置".to_owned(),
        ),
        AiError::ProviderRequestFailed(_) => (
            StatusCode::BAD_GATEWAY,
            "ai.provider_request_failed",
            "AI 服务暂时不可用".to_owned(),
        ),
        AiError::ProviderStreamError(_) => (
            StatusCode::BAD_GATEWAY,
            "ai.provider_stream_error",
            "AI 流式响应中断".to_owned(),
        ),
        AiError::AnswerBlocked(_) => (
            StatusCode::UNPROCESSABLE_ENTITY,
            "ai.answer_blocked",
            "回答内容未通过安全校验".to_owned(),
        ),
        AiError::Infrastructure(_) => (
            StatusCode::INTERNAL_SERVER_ERROR,
            "ai.infrastructure",
            "AI 服务暂时不可用".to_owned(),
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
