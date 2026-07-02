use axum::{
    Json,
    http::StatusCode,
    response::{IntoResponse, Response},
};
use maohuoban_auth_domain::auth::AuthError;
use serde::Serialize;

use super::auth_error_code;

/// AuthRejection 认证提取器拒绝类型
/// 核心职责：
/// - 将领域层 AuthError 映射为稳定 HTTP 401 响应
/// - 避免 extractor 直接依赖业务 handler 的响应工具
#[derive(Debug)]
pub struct AuthRejection {
    pub error: AuthError,
}

impl From<AuthError> for AuthRejection {
    fn from(error: AuthError) -> Self {
        Self { error }
    }
}

impl IntoResponse for AuthRejection {
    fn into_response(self) -> Response {
        (
            StatusCode::UNAUTHORIZED,
            Json(AuthRejectionResponse {
                success: false,
                code: "auth.session_expired",
                message: "登录状态已过期，请重新登录".to_owned(),
                data: Option::<serde_json::Value>::None,
                auth_error_code: auth_error_code(&self.error).to_owned(),
            }),
        )
            .into_response()
    }
}

#[derive(Serialize)]
struct AuthRejectionResponse {
    success: bool,
    code: &'static str,
    message: String,
    data: Option<serde_json::Value>,
    auth_error_code: String,
}
