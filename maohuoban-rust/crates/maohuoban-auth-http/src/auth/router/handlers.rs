use axum::{
    Json,
    extract::{Path, State},
    response::Response,
};
use maohuoban_auth_domain::auth::{AuthError, OAuthProvider};
use serde_json::Value;

use super::AuthHttpState;
use super::dto::{
    LogoutRequest, PasswordLoginRequest, RefreshTokenRequest, ResetPasswordRequest,
    SendPhoneCodeRequest, SendRecoveryCodeRequest, VerifyPhoneCodeRequest,
};
use super::responses::{EmptyData, LoginData, PhoneCodeChallengeData, error_response, ok_response};

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
        Ok(session) => ok_response("auth.login_success", "登录成功", LoginData::from(session)),
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
        Ok(session) => ok_response("auth.login_success", "登录成功", LoginData::from(session)),
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
        Ok(session) => ok_response(
            "auth.refresh_success",
            "登录状态已刷新",
            LoginData::from(session),
        ),
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
        Ok(session) => ok_response("auth.login_success", "登录成功", LoginData::from(session)),
        Err(error) => error_response(error),
    }
}
