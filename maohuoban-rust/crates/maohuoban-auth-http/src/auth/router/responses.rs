use axum::{
    Json,
    http::StatusCode,
    response::{IntoResponse, Response},
};
use maohuoban_auth_domain::auth::{AuthError, AuthSession, PhoneCodeChallenge};
use serde::Serialize;
use serde_json::Value;

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

pub(super) fn error_response(error: AuthError) -> Response {
    let (status, code, message) = match error {
        AuthError::InvalidPhone => (
            StatusCode::BAD_REQUEST,
            "auth.invalid_phone",
            "请输入正确的手机号".to_owned(),
        ),
        AuthError::AgreementRequired => (
            StatusCode::BAD_REQUEST,
            "auth.agreement_required",
            "请先同意用户协议和隐私政策".to_owned(),
        ),
        AuthError::InvalidCode => (
            StatusCode::BAD_REQUEST,
            "auth.invalid_code",
            "验证码错误，请重新输入".to_owned(),
        ),
        AuthError::ChallengeExpired => (
            StatusCode::BAD_REQUEST,
            "auth.code_expired",
            "验证码已过期，请重新获取".to_owned(),
        ),
        AuthError::CodeCoolingDown {
            retry_after_seconds,
        } => (
            StatusCode::TOO_MANY_REQUESTS,
            "auth.code_cooling_down",
            format!("请 {retry_after_seconds} 秒后重新获取验证码"),
        ),
        AuthError::TooManyAttempts => (
            StatusCode::TOO_MANY_REQUESTS,
            "auth.too_many_attempts",
            "验证码尝试次数过多，请重新获取".to_owned(),
        ),
        AuthError::InvalidCredentials => (
            StatusCode::UNAUTHORIZED,
            "auth.invalid_credentials",
            "手机号或密码错误".to_owned(),
        ),
        AuthError::UserNotFound => (
            StatusCode::NOT_FOUND,
            "account_recovery.user_not_found",
            "账号不存在，请先注册".to_owned(),
        ),
        AuthError::RefreshInvalid => (
            StatusCode::UNAUTHORIZED,
            "auth.refresh_invalid",
            "登录状态已失效，请重新登录".to_owned(),
        ),
        AuthError::RefreshReused => (
            StatusCode::UNAUTHORIZED,
            "auth.refresh_reused",
            "登录状态异常，请重新登录".to_owned(),
        ),
        AuthError::AccessInvalid => (
            StatusCode::UNAUTHORIZED,
            "auth.token_invalid",
            "登录状态无效，请重新登录".to_owned(),
        ),
        AuthError::SessionInvalid => (
            StatusCode::UNAUTHORIZED,
            "auth.session_expired",
            "登录状态已过期，请重新登录".to_owned(),
        ),
        AuthError::AccountDisabled => (
            StatusCode::UNAUTHORIZED,
            "auth.account_disabled",
            "账号状态异常，请联系客服".to_owned(),
        ),
        AuthError::OAuthTodo(provider) => (
            StatusCode::NOT_IMPLEMENTED,
            "auth.oauth_todo",
            format!("{} 登录暂未开放", provider.label()),
        ),
        AuthError::Password(_) | AuthError::Token(_) | AuthError::Infrastructure(_) => (
            StatusCode::INTERNAL_SERVER_ERROR,
            "auth.internal_error",
            "服务暂时不可用，请稍后再试".to_owned(),
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

/// ApiResponse 统一接口响应
/// 核心职责：
/// - 固定 success、code、message、data 格式
/// - 让 iOS toast 直接消费后端 message
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

/// PhoneCodeChallengeData 验证码响应数据
/// 核心职责：
/// - 向客户端返回 challenge id
/// - 暴露验证码有效期
#[derive(Debug, Serialize)]
pub(super) struct PhoneCodeChallengeData {
    challenge_id: String,
    expires_in_seconds: i64,
    resend_after_seconds: i64,
}

impl From<PhoneCodeChallenge> for PhoneCodeChallengeData {
    fn from(challenge: PhoneCodeChallenge) -> Self {
        Self {
            challenge_id: challenge.challenge_id,
            expires_in_seconds: challenge.expires_in_seconds,
            resend_after_seconds: challenge.resend_after_seconds,
        }
    }
}

/// LoginData 登录响应数据
/// 核心职责：
/// - 扁平化 token 字段以匹配客户端契约
/// - 返回最小用户信息
#[derive(Debug, Serialize)]
pub(super) struct LoginData {
    access_token: String,
    refresh_token: String,
    token_type: String,
    expires_in_seconds: i64,
    refresh_expires_in_seconds: i64,
    user: UserData,
}

impl From<AuthSession> for LoginData {
    fn from(session: AuthSession) -> Self {
        Self {
            access_token: session.tokens.access_token,
            refresh_token: session.tokens.refresh_token,
            token_type: session.tokens.token_type,
            expires_in_seconds: session.tokens.expires_in_seconds,
            refresh_expires_in_seconds: session.tokens.refresh_expires_in_seconds,
            user: UserData {
                id: session.user.id.to_string(),
                phone: session.user.phone,
            },
        }
    }
}

/// UserData 登录用户响应
/// 核心职责：
/// - 返回客户端首屏需要的身份字段
/// - 隔离领域用户模型和 HTTP JSON 结构
#[derive(Debug, Serialize)]
struct UserData {
    id: String,
    phone: String,
}

/// EmptyData 空响应数据
/// 核心职责：
/// - 统一无业务数据接口的 JSON data 形态
/// - 避免客户端对成功响应做特殊分支
#[derive(Debug, Serialize)]
pub(super) struct EmptyData {}
