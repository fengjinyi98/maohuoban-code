use std::sync::Arc;

use axum::{
    Json, Router,
    extract::{Path, State},
    http::StatusCode,
    response::{IntoResponse, Response},
    routing::post,
};
use maohuoban_auth_application::auth::AuthService;
use maohuoban_auth_domain::auth::{
    AuthError, AuthSession, DeviceDescriptor, OAuthProvider, PhoneCodeChallenge,
};
use serde::{Deserialize, Serialize};
use serde_json::Value;

/// AuthHttpState 认证 HTTP 状态
/// 核心职责：
/// - 持有认证应用服务
/// - 作为 axum handler 的共享状态
#[derive(Clone)]
pub struct AuthHttpState {
    auth: Arc<AuthService>,
}

impl AuthHttpState {
    #[must_use]
    pub const fn new(auth: Arc<AuthService>) -> Self {
        Self { auth }
    }
}

/// build_auth_router 构建认证路由
/// 核心职责：
/// - 注册登录、refresh、第三方 TODO 接口
/// - 将 HTTP 层限制在 DTO 和响应转换范围内
#[must_use]
pub fn build_auth_router(auth: Arc<AuthService>) -> Router {
    Router::new()
        .route("/api/v1/auth/phone/code", post(send_phone_code))
        .route("/api/v1/auth/phone/verify", post(verify_phone_code))
        .route("/api/v1/auth/password/login", post(password_login))
        .route("/api/v1/auth/refresh", post(refresh_token))
        .route("/api/v1/auth/logout", post(logout))
        .route("/api/v1/auth/oauth/{provider}", post(oauth_login))
        .route("/api/v1/account-recovery/code", post(send_recovery_code))
        .route(
            "/api/v1/account-recovery/reset-password",
            post(reset_password),
        )
        .with_state(AuthHttpState::new(auth))
}

async fn send_phone_code(
    State(state): State<AuthHttpState>,
    Json(request): Json<SendPhoneCodeRequest>,
) -> Response {
    match state
        .auth
        .send_phone_code(&request.phone, request.agreement_accepted)
        .await
    {
        Ok(challenge) => ok_response(
            "auth.code_sent",
            "验证码已发送",
            PhoneCodeChallengeData::from(challenge),
        ),
        Err(error) => error_response(error),
    }
}

async fn verify_phone_code(
    State(state): State<AuthHttpState>,
    Json(request): Json<VerifyPhoneCodeRequest>,
) -> Response {
    match state
        .auth
        .verify_phone_code(
            &request.challenge_id,
            &request.code,
            request.device.into_device_descriptor(),
        )
        .await
    {
        Ok(session) => ok_response("auth.login_success", "登录成功", LoginData::from(session)),
        Err(error) => error_response(error),
    }
}

async fn password_login(
    State(state): State<AuthHttpState>,
    Json(request): Json<PasswordLoginRequest>,
) -> Response {
    match state
        .auth
        .password_login(
            &request.phone,
            &request.password,
            request.device.into_device_descriptor(),
        )
        .await
    {
        Ok(session) => ok_response("auth.login_success", "登录成功", LoginData::from(session)),
        Err(error) => error_response(error),
    }
}

async fn refresh_token(
    State(state): State<AuthHttpState>,
    Json(request): Json<RefreshTokenRequest>,
) -> Response {
    match state
        .auth
        .refresh(&request.refresh_token, &request.device_id)
        .await
    {
        Ok(session) => ok_response(
            "auth.refresh_success",
            "登录状态已刷新",
            LoginData::from(session),
        ),
        Err(error) => error_response(error),
    }
}

async fn logout(
    State(state): State<AuthHttpState>,
    Json(request): Json<LogoutRequest>,
) -> Response {
    match state
        .auth
        .logout(&request.refresh_token, &request.device_id)
        .await
    {
        Ok(()) => ok_response("auth.logout_success", "已退出登录", EmptyData {}),
        Err(error) => error_response(error),
    }
}

async fn send_recovery_code(
    State(state): State<AuthHttpState>,
    Json(request): Json<SendRecoveryCodeRequest>,
) -> Response {
    match state.auth.send_account_recovery_code(&request.phone).await {
        Ok(challenge) => ok_response(
            "account_recovery.code_sent",
            "验证码已发送",
            PhoneCodeChallengeData::from(challenge),
        ),
        Err(error) => error_response(error),
    }
}

async fn reset_password(
    State(state): State<AuthHttpState>,
    Json(request): Json<ResetPasswordRequest>,
) -> Response {
    match state
        .auth
        .reset_password(&request.challenge_id, &request.code, &request.new_password)
        .await
    {
        Ok(()) => ok_response(
            "account_recovery.password_reset",
            "密码已重置",
            EmptyData {},
        ),
        Err(error) => error_response(error),
    }
}

async fn oauth_login(
    State(state): State<AuthHttpState>,
    Path(provider): Path<String>,
    Json(_request): Json<Value>,
) -> Response {
    let provider = match provider.as_str() {
        "apple" => OAuthProvider::Apple,
        "wechat" => OAuthProvider::Wechat,
        _ => return error_response(AuthError::OAuthTodo(OAuthProvider::Apple)),
    };
    match state.auth.oauth_login(provider) {
        Ok(session) => ok_response("auth.login_success", "登录成功", LoginData::from(session)),
        Err(error) => error_response(error),
    }
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

fn error_response(error: AuthError) -> Response {
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

/// SendPhoneCodeRequest 发送验证码请求
/// 核心职责：
/// - 接收手机号和协议确认状态
/// - 保留 device 字段以兼容设计稿和后续风控
#[derive(Debug, Deserialize)]
struct SendPhoneCodeRequest {
    phone: String,
    agreement_accepted: bool,
    #[allow(dead_code)]
    device: DevicePayload,
}

/// VerifyPhoneCodeRequest 验证码登录请求
/// 核心职责：
/// - 接收 challenge、验证码和设备信息
/// - 将 HTTP DTO 转换为应用层输入
#[derive(Debug, Deserialize)]
struct VerifyPhoneCodeRequest {
    challenge_id: String,
    code: String,
    device: DevicePayload,
}

/// PasswordLoginRequest 密码登录请求
/// 核心职责：
/// - 接收手机号、密码和设备信息
/// - 支持后续密码登录 UI 直接接入
#[derive(Debug, Deserialize)]
struct PasswordLoginRequest {
    phone: String,
    password: String,
    device: DevicePayload,
}

/// RefreshTokenRequest 刷新 token 请求
/// 核心职责：
/// - 接收 refresh token 和设备 id
/// - 支持设备维度 session 轮换
#[derive(Debug, Deserialize)]
struct RefreshTokenRequest {
    refresh_token: String,
    device_id: String,
}

/// LogoutRequest 退出登录请求
/// 核心职责：
/// - 接收当前设备 refresh token
/// - 支持服务端撤销当前设备 session
#[derive(Debug, Deserialize)]
struct LogoutRequest {
    refresh_token: String,
    device_id: String,
}

/// SendRecoveryCodeRequest 账号恢复验证码请求
/// 核心职责：
/// - 接收账号恢复手机号
/// - 保留设备字段供后续风控扩展
#[derive(Debug, Deserialize)]
struct SendRecoveryCodeRequest {
    phone: String,
    #[allow(dead_code)]
    device: DevicePayload,
}

/// ResetPasswordRequest 重置密码请求
/// 核心职责：
/// - 接收验证码 challenge 和新密码
/// - 将账号恢复流程保持在独立接口边界
#[derive(Debug, Deserialize)]
struct ResetPasswordRequest {
    challenge_id: String,
    code: String,
    new_password: String,
}

/// DevicePayload 设备请求载荷
/// 核心职责：
/// - 表达客户端设备字段
/// - 转换为领域层设备描述
#[derive(Debug, Deserialize)]
struct DevicePayload {
    device_id: String,
    device_name: String,
    platform: String,
    app_version: String,
}

impl DevicePayload {
    fn into_device_descriptor(self) -> DeviceDescriptor {
        DeviceDescriptor {
            device_id: self.device_id,
            device_name: self.device_name,
            platform: self.platform,
            app_version: self.app_version,
        }
    }
}

/// PhoneCodeChallengeData 验证码响应数据
/// 核心职责：
/// - 向客户端返回 challenge id
/// - 暴露验证码有效期
#[derive(Debug, Serialize)]
struct PhoneCodeChallengeData {
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
struct LoginData {
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
struct EmptyData {}
