use axum::http::HeaderMap;
use maohuoban_auth_application::auth::AuthService;
use maohuoban_auth_domain::auth::{AuthError, AuthResult, AuthUser, AuthenticatedSession};

use super::AuthorizationHeaderDiagnostics;

/// authenticate_user 统一执行 access token 鉴权
/// 核心职责：
/// - 从 Authorization header 提取 Bearer token
/// - 返回当前已鉴权用户
pub async fn authenticate_user(auth: &AuthService, headers: &HeaderMap) -> AuthResult<AuthUser> {
    let token = bearer_token(headers)?;
    auth.authenticate_access_token(token).await
}

/// authenticate_session_context 统一执行带 session 语义的 access token 鉴权
/// 核心职责：
/// - 从 Authorization header 提取 Bearer token
/// - 返回用户与当前 session 的组合上下文
pub async fn authenticate_session_context(
    auth: &AuthService,
    headers: &HeaderMap,
) -> AuthResult<AuthenticatedSession> {
    let token = bearer_token(headers)?;
    auth.authenticate_access_token_context(token).await
}

/// authorization_header_diagnostics 返回 Authorization 头基础观测
pub fn authorization_header_diagnostics(headers: &HeaderMap) -> AuthorizationHeaderDiagnostics {
    let raw = headers
        .get("authorization")
        .and_then(|value| value.to_str().ok());
    AuthorizationHeaderDiagnostics {
        has_authorization: raw.is_some(),
        bearer_prefix_present: raw.is_some_and(|value| value.starts_with("Bearer ")),
    }
}

/// auth_error_code 返回稳定认证错误码
pub const fn auth_error_code(error: &AuthError) -> &'static str {
    match error {
        AuthError::InvalidPhone => "invalid_phone",
        AuthError::AgreementRequired => "agreement_required",
        AuthError::InvalidCode => "invalid_code",
        AuthError::ChallengeExpired => "challenge_expired",
        AuthError::CodeCoolingDown { .. } => "code_cooling_down",
        AuthError::TooManyAttempts => "too_many_attempts",
        AuthError::InvalidCredentials => "invalid_credentials",
        AuthError::PasswordAlreadySet => "password_already_set",
        AuthError::PasswordNotSet => "password_not_set",
        AuthError::CurrentPasswordInvalid => "current_password_invalid",
        AuthError::PasswordWeak => "password_weak",
        AuthError::PasswordMismatch => "password_mismatch",
        AuthError::DeviceNotFound => "device_not_found",
        AuthError::CurrentDeviceRemoveForbidden => "current_device_remove_forbidden",
        AuthError::UserNotFound => "user_not_found",
        AuthError::AccessInvalid => "access_invalid",
        AuthError::SessionInvalid => "session_invalid",
        AuthError::AccountDisabled => "account_disabled",
        AuthError::RefreshInvalid => "refresh_invalid",
        AuthError::RefreshReused => "refresh_reused",
        AuthError::OAuthTodo(_) => "oauth_todo",
        AuthError::Password(_) => "password_error",
        AuthError::Token(_) => "token_error",
        AuthError::Infrastructure(_) => "infrastructure_error",
    }
}

fn bearer_token(headers: &HeaderMap) -> AuthResult<&str> {
    let value = headers
        .get("authorization")
        .ok_or(AuthError::AccessInvalid)?;
    let raw = value.to_str().map_err(|_| AuthError::AccessInvalid)?;
    raw.strip_prefix("Bearer ")
        .filter(|token| !token.is_empty())
        .ok_or(AuthError::AccessInvalid)
}
