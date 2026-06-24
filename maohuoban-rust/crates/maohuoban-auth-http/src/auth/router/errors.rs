use axum::http::StatusCode;
use maohuoban_auth_domain::auth::AuthError;

/// auth_error_response_parts 认证错误响应字段映射
/// 核心职责：
/// - 按错误归属分派到具体映射函数
/// - 保持 HTTP 状态、业务码和 Toast 文案一致
pub(super) fn auth_error_response_parts(error: AuthError) -> (StatusCode, &'static str, String) {
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
