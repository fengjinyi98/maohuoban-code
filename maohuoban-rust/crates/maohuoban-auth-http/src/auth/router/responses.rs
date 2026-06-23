use axum::{
    Json,
    http::StatusCode,
    response::{IntoResponse, Response},
};
use maohuoban_auth_domain::auth::{
    AccountDeviceSession, AuthError, AuthSession, AuthUser, PhoneCodeChallenge,
};
use maohuoban_profile_domain::profile::{AvatarPresentation, UserProfile};
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
    let (status, code, message) = auth_error_response_parts(error);

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

/// auth_error_response_parts 认证错误响应字段映射
/// 核心职责：
/// - 按错误归属分派到具体映射函数
/// - 保持 HTTP 状态、业务码和 Toast 文案一致
fn auth_error_response_parts(error: AuthError) -> (StatusCode, &'static str, String) {
    match error {
        AuthError::InvalidPhone
        | AuthError::AgreementRequired
        | AuthError::InvalidCode
        | AuthError::ChallengeExpired
        | AuthError::CodeCoolingDown { .. }
        | AuthError::TooManyAttempts
        | AuthError::InvalidCredentials => phone_auth_error_response_parts(error),
        AuthError::PasswordAlreadySet
        | AuthError::PasswordNotSet
        | AuthError::CurrentPasswordInvalid
        | AuthError::PasswordWeak
        | AuthError::PasswordMismatch => password_error_response_parts(error),
        AuthError::DeviceNotFound | AuthError::CurrentDeviceRemoveForbidden => {
            device_error_response_parts(error)
        }
        AuthError::RefreshInvalid
        | AuthError::RefreshReused
        | AuthError::AccessInvalid
        | AuthError::SessionInvalid
        | AuthError::AccountDisabled => session_error_response_parts(error),
        AuthError::UserNotFound => (
            StatusCode::NOT_FOUND,
            "account_recovery.user_not_found",
            "账号不存在，请先注册".to_owned(),
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
    }
}

/// phone_auth_error_response_parts 手机认证错误映射
/// 核心职责：
/// - 映射验证码发送和登录校验错误
/// - 提供前端可直接展示的认证提示
fn phone_auth_error_response_parts(error: AuthError) -> (StatusCode, &'static str, String) {
    match error {
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
        _ => unreachable!("unexpected phone auth error"),
    }
}

/// password_error_response_parts 登录密码错误映射
/// 核心职责：
/// - 映射首次设置和二次修改密码错误
/// - 固定账号安全页消费的业务码和文案
fn password_error_response_parts(error: AuthError) -> (StatusCode, &'static str, String) {
    match error {
        AuthError::PasswordAlreadySet => (
            StatusCode::CONFLICT,
            "account.password_already_set",
            "登录密码已设置".to_owned(),
        ),
        AuthError::PasswordNotSet => (
            StatusCode::BAD_REQUEST,
            "account.password_not_set",
            "请先设置登录密码".to_owned(),
        ),
        AuthError::CurrentPasswordInvalid => (
            StatusCode::UNAUTHORIZED,
            "account.current_password_invalid",
            "当前登录密码错误".to_owned(),
        ),
        AuthError::PasswordWeak => (
            StatusCode::BAD_REQUEST,
            "account.password_weak",
            "密码需为 8-20 位，且至少满足两种字符类型".to_owned(),
        ),
        AuthError::PasswordMismatch => (
            StatusCode::BAD_REQUEST,
            "account.password_mismatch",
            "两次输入的密码不一致".to_owned(),
        ),
        _ => unreachable!("unexpected password error"),
    }
}

/// device_error_response_parts 登录设备错误映射
/// 核心职责：
/// - 映射设备管理列表、详情和移除错误
/// - 固定前端 Toast 消费的业务码和文案
fn device_error_response_parts(error: AuthError) -> (StatusCode, &'static str, String) {
    match error {
        AuthError::DeviceNotFound => (
            StatusCode::NOT_FOUND,
            "account.device_not_found",
            "设备不存在或已移除".to_owned(),
        ),
        AuthError::CurrentDeviceRemoveForbidden => (
            StatusCode::BAD_REQUEST,
            "account.current_device_remove_forbidden",
            "当前设备请通过退出登录移除".to_owned(),
        ),
        _ => unreachable!("unexpected device error"),
    }
}

/// session_error_response_parts 会话错误映射
/// 核心职责：
/// - 映射 token、session 和账号状态错误
/// - 为客户端统一登录态失效处理提供稳定文案
fn session_error_response_parts(error: AuthError) -> (StatusCode, &'static str, String) {
    match error {
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
        _ => unreachable!("unexpected session error"),
    }
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

/// AccountSecurityData 账号安全摘要响应
/// 核心职责：
/// - 返回设置页账号安全入口需要的密码状态
/// - 以后端 password credentials 事实源派生展示文案
#[derive(Debug, Serialize)]
pub(super) struct AccountSecurityData {
    phone_masked: String,
    has_password: bool,
    password_status_text: &'static str,
    password_updated_at: Option<String>,
    wechat_bound: bool,
    apple_bound: bool,
    real_name_status: &'static str,
    official_verification_status: &'static str,
}

impl AccountSecurityData {
    pub(super) fn from_user(user: &AuthUser, has_password: bool) -> Self {
        Self {
            phone_masked: mask_phone(&user.phone),
            has_password,
            password_status_text: if has_password {
                "已设置"
            } else {
                "未设置"
            },
            password_updated_at: None,
            wechat_bound: false,
            apple_bound: false,
            real_name_status: "unverified",
            official_verification_status: "unverified",
        }
    }
}

/// AccountDevicesData 登录设备列表响应
/// 核心职责：
/// - 包装当前账号有效登录设备
/// - 标记 access token 对应的当前设备
#[derive(Debug, Serialize)]
pub(super) struct AccountDevicesData {
    devices: Vec<AccountDeviceSummaryData>,
}

impl AccountDevicesData {
    pub(super) fn from_sessions(
        sessions: Vec<AccountDeviceSession>,
        current_session_id: uuid::Uuid,
    ) -> Self {
        Self {
            devices: sessions
                .into_iter()
                .map(|session| AccountDeviceSummaryData::from_session(session, current_session_id))
                .collect(),
        }
    }
}

/// AccountDeviceSummaryData 登录设备摘要响应
/// 核心职责：
/// - 返回设备列表所需展示字段
/// - 避免暴露 refresh token hash 等敏感字段
#[derive(Debug, Serialize)]
pub(super) struct AccountDeviceSummaryData {
    session_id: String,
    device_id: String,
    device_name: String,
    device_model: String,
    platform: String,
    location_text: String,
    last_active_text: String,
    is_current_device: bool,
}

impl AccountDeviceSummaryData {
    fn from_session(session: AccountDeviceSession, current_session_id: uuid::Uuid) -> Self {
        let is_current_device = session.session_id == current_session_id;
        Self {
            session_id: session.session_id.to_string(),
            device_id: session.device_id,
            device_name: session.device_name.clone(),
            device_model: device_model(&session.device_name, &session.platform).to_owned(),
            platform: session.platform,
            location_text: "未知地区".to_owned(),
            last_active_text: if is_current_device {
                "当前在线".to_owned()
            } else {
                session.last_seen_at.to_rfc3339()
            },
            is_current_device,
        }
    }
}

/// AccountDeviceDetailData 登录设备详情响应
/// 核心职责：
/// - 返回单个设备会话详情
/// - 标记当前设备并保留后续 IP/地区扩展位置
#[derive(Debug, Serialize)]
pub(super) struct AccountDeviceDetailData {
    session_id: String,
    device_id: String,
    device_name: String,
    device_model: String,
    platform: String,
    os_version: String,
    app_version: String,
    location_text: String,
    ip_address: String,
    first_login_text: String,
    last_active_text: String,
    is_current_device: bool,
}

impl AccountDeviceDetailData {
    pub(super) fn from_session(
        session: AccountDeviceSession,
        current_session_id: uuid::Uuid,
    ) -> Self {
        let is_current_device = session.session_id == current_session_id;
        Self {
            session_id: session.session_id.to_string(),
            device_id: session.device_id,
            device_name: session.device_name.clone(),
            device_model: device_model(&session.device_name, &session.platform).to_owned(),
            platform: session.platform.clone(),
            os_version: session.platform,
            app_version: session.app_version,
            location_text: "未知地区".to_owned(),
            ip_address: "未知".to_owned(),
            first_login_text: session.created_at.to_rfc3339(),
            last_active_text: if is_current_device {
                "当前在线".to_owned()
            } else {
                session.last_seen_at.to_rfc3339()
            },
            is_current_device,
        }
    }
}

fn device_model(device_name: &str, platform: &str) -> &'static str {
    let device_name = device_name.to_lowercase();
    let platform = platform.to_lowercase();
    if device_name.contains("ipad") || platform.contains("ipad") {
        "iPad"
    } else if device_name.contains("mac") || platform.contains("mac") {
        "Mac"
    } else {
        "iPhone"
    }
}

/// LoginData 登录响应数据
/// 核心职责：
/// - 扁平化 token 字段以匹配客户端契约
/// - 返回当前账号安全摘要和用户资料摘要
#[derive(Debug, Serialize)]
pub(super) struct LoginData {
    access_token: String,
    refresh_token: String,
    token_type: String,
    expires_in_seconds: i64,
    refresh_expires_in_seconds: i64,
    user: UserData,
}

impl LoginData {
    pub(super) fn from_session(
        session: AuthSession,
        profile: UserProfile,
        has_password: bool,
    ) -> Self {
        Self {
            access_token: session.tokens.access_token,
            refresh_token: session.tokens.refresh_token,
            token_type: session.tokens.token_type,
            expires_in_seconds: session.tokens.expires_in_seconds,
            refresh_expires_in_seconds: session.tokens.refresh_expires_in_seconds,
            user: UserData {
                id: session.user.id.to_string(),
                phone_masked: mask_phone(&session.user.phone),
                phone: session.user.phone,
                has_password,
                profile: UserProfileSummaryData::from(profile),
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
    phone_masked: String,
    has_password: bool,
    profile: UserProfileSummaryData,
}

/// UserProfileSummaryData 登录用户资料摘要
/// 核心职责：
/// - 提供我的页首屏可缓存的用户资料字段
/// - 保持勋章、注册序号等非本阶段字段不进入登录响应
#[derive(Debug, Serialize)]
struct UserProfileSummaryData {
    maohuoban_id: String,
    display_name: String,
    avatar: Option<Value>,
    avatar_presentation: AvatarPresentation,
}

impl From<UserProfile> for UserProfileSummaryData {
    fn from(profile: UserProfile) -> Self {
        let avatar_presentation = profile.avatar_presentation();
        Self {
            maohuoban_id: profile.maohuoban_id,
            display_name: profile.display_name,
            avatar: None,
            avatar_presentation,
        }
    }
}

/// EmptyData 空响应数据
/// 核心职责：
/// - 统一无业务数据接口的 JSON data 形态
/// - 避免客户端对成功响应做特殊分支
#[derive(Debug, Serialize)]
pub(super) struct EmptyData {}

fn mask_phone(phone: &str) -> String {
    let chars: Vec<char> = phone.chars().collect();
    if chars.len() != 11 {
        return phone.to_owned();
    }

    let prefix: String = chars.iter().take(3).collect();
    let suffix: String = chars.iter().skip(7).collect();
    format!("{prefix}****{suffix}")
}
