use axum::{
    Json,
    extract::{Path, State},
    http::HeaderMap,
    response::Response,
};
use maohuoban_auth_application::auth::AuthService;
use maohuoban_auth_domain::auth::{
    AuthError, AuthResult, AuthSession, AuthUser, AuthenticatedSession, OAuthProvider,
};
use maohuoban_profile_domain::profile::ProfileError;
use serde_json::Value;
use uuid::Uuid;

use super::AuthHttpState;
use super::dto::{
    ChangeAccountPasswordRequest, LogoutRequest, PasswordLoginRequest, RefreshTokenRequest,
    ResetPasswordRequest, SendPhoneCodeRequest, SendRecoveryCodeRequest, SetAccountPasswordRequest,
    VerifyPhoneCodeRequest,
};
use super::responses::{
    AccountDeviceDetailData, AccountDevicesData, AccountSecurityData, EmptyData, LoginData,
    PhoneCodeChallengeData, error_response, ok_response,
};

pub(super) async fn send_phone_code(
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

pub(super) async fn verify_phone_code(
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
        Ok(session) => login_response(&state, "auth.login_success", "登录成功", session).await,
        Err(error) => error_response(error),
    }
}

pub(super) async fn password_login(
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
        Ok(session) => login_response(&state, "auth.login_success", "登录成功", session).await,
        Err(error) => error_response(error),
    }
}

pub(super) async fn account_security(
    State(state): State<AuthHttpState>,
    headers: HeaderMap,
) -> Response {
    let Ok(user) = current_user(&state.auth, &headers).await else {
        return error_response(AuthError::AccessInvalid);
    };
    match state.auth.has_password(user.id).await {
        Ok(has_password) => ok_response(
            "account.security_loaded",
            "账号安全信息已加载",
            AccountSecurityData::from_user(&user, has_password),
        ),
        Err(error) => error_response(error),
    }
}

pub(super) async fn set_account_password(
    State(state): State<AuthHttpState>,
    headers: HeaderMap,
    Json(request): Json<SetAccountPasswordRequest>,
) -> Response {
    let Ok(user) = current_user(&state.auth, &headers).await else {
        return error_response(AuthError::AccessInvalid);
    };
    match state
        .auth
        .set_initial_password(&user, &request.new_password, &request.confirm_password)
        .await
    {
        Ok(()) => ok_response(
            "account.password_set",
            "登录密码已设置",
            AccountSecurityData::from_user(&user, true),
        ),
        Err(error) => error_response(error),
    }
}

pub(super) async fn send_password_change_code(
    State(state): State<AuthHttpState>,
    headers: HeaderMap,
) -> Response {
    let Ok(user) = current_user(&state.auth, &headers).await else {
        return error_response(AuthError::AccessInvalid);
    };
    match state.auth.send_password_change_code(&user).await {
        Ok(challenge) => ok_response(
            "account.password_change_code_sent",
            "验证码已发送",
            PhoneCodeChallengeData::from(challenge),
        ),
        Err(error) => error_response(error),
    }
}

pub(super) async fn change_account_password(
    State(state): State<AuthHttpState>,
    headers: HeaderMap,
    Json(request): Json<ChangeAccountPasswordRequest>,
) -> Response {
    let Ok(user) = current_user(&state.auth, &headers).await else {
        return error_response(AuthError::AccessInvalid);
    };
    match state
        .auth
        .change_password(
            &user,
            &request.current_password,
            &request.challenge_id,
            &request.code,
            &request.new_password,
            &request.confirm_password,
        )
        .await
    {
        Ok(()) => ok_response(
            "account.password_changed",
            "登录密码已修改",
            AccountSecurityData::from_user(&user, true),
        ),
        Err(error) => error_response(error),
    }
}

pub(super) async fn list_account_devices(
    State(state): State<AuthHttpState>,
    headers: HeaderMap,
) -> Response {
    let Ok(context) = current_auth_context(&state.auth, &headers).await else {
        return error_response(AuthError::AccessInvalid);
    };
    match state.auth.list_account_devices(context.user.id).await {
        Ok(devices) => ok_response(
            "account.devices_loaded",
            "登录设备已加载",
            AccountDevicesData::from_sessions(devices, context.session_id),
        ),
        Err(error) => error_response(error),
    }
}

pub(super) async fn load_account_device(
    State(state): State<AuthHttpState>,
    headers: HeaderMap,
    Path(session_id): Path<Uuid>,
) -> Response {
    let Ok(context) = current_auth_context(&state.auth, &headers).await else {
        return error_response(AuthError::AccessInvalid);
    };
    match state
        .auth
        .load_account_device(context.user.id, session_id)
        .await
    {
        Ok(device) => ok_response(
            "account.device_loaded",
            "登录设备详情已加载",
            AccountDeviceDetailData::from_session(device, context.session_id),
        ),
        Err(error) => error_response(error),
    }
}

pub(super) async fn revoke_account_device(
    State(state): State<AuthHttpState>,
    headers: HeaderMap,
    Path(session_id): Path<Uuid>,
) -> Response {
    let Ok(context) = current_auth_context(&state.auth, &headers).await else {
        return error_response(AuthError::AccessInvalid);
    };
    match state
        .auth
        .revoke_account_device(context.user.id, context.session_id, session_id)
        .await
    {
        Ok(()) => ok_response("account.device_revoked", "登录设备已移除", EmptyData {}),
        Err(error) => error_response(error),
    }
}

pub(super) async fn refresh_token(
    State(state): State<AuthHttpState>,
    Json(request): Json<RefreshTokenRequest>,
) -> Response {
    match state
        .auth
        .refresh(&request.refresh_token, &request.device_id)
        .await
    {
        Ok(session) => {
            login_response(&state, "auth.refresh_success", "登录状态已刷新", session).await
        }
        Err(error) => error_response(error),
    }
}

pub(super) async fn logout(
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

pub(super) async fn send_recovery_code(
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

pub(super) async fn reset_password(
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

pub(super) async fn oauth_login(
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
        Ok(session) => login_response(&state, "auth.login_success", "登录成功", session).await,
        Err(error) => error_response(error),
    }
}

async fn login_response(
    state: &AuthHttpState,
    code: &'static str,
    message: &'static str,
    session: AuthSession,
) -> Response {
    let profile = match state.profile.ensure_default_profile(session.user.id).await {
        Ok(profile) => profile,
        Err(error) => return error_response(profile_error_to_auth_error(error)),
    };
    let has_password = match state.auth.has_password(session.user.id).await {
        Ok(has_password) => has_password,
        Err(error) => return error_response(error),
    };

    ok_response(
        code,
        message,
        LoginData::from_session(session, profile, has_password),
    )
}

fn profile_error_to_auth_error(error: ProfileError) -> AuthError {
    AuthError::Infrastructure(error.to_string())
}

async fn current_user(auth: &AuthService, headers: &HeaderMap) -> AuthResult<AuthUser> {
    let token = bearer_token(headers)?;
    auth.authenticate_access_token(token).await
}

async fn current_auth_context(
    auth: &AuthService,
    headers: &HeaderMap,
) -> AuthResult<AuthenticatedSession> {
    let token = bearer_token(headers)?;
    auth.authenticate_access_token_context(token).await
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
