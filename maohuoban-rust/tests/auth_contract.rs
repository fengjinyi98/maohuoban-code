#![allow(clippy::needless_pass_by_value, clippy::too_many_lines)]

use axum::{
    body::{Body, to_bytes},
    http::{Request, StatusCode},
};
use serde_json::{Value, json};
use tower::ServiceExt;

/// `json_request` 构造 JSON HTTP 请求
/// 核心职责：
/// - 固定测试请求的 Content-Type
/// - 将 JSON body 转为 axum Body
fn json_request(method: &str, uri: &str, body: Value) -> Request<Body> {
    Request::builder()
        .method(method)
        .uri(uri)
        .header("content-type", "application/json")
        .body(Body::from(body.to_string()))
        .expect("build test request")
}

/// `response_json` 读取 JSON 响应
/// 核心职责：
/// - 校验测试响应 body 可被解析为 JSON
/// - 为接口契约断言提供统一入口
async fn response_json(response: axum::response::Response) -> Value {
    let bytes = to_bytes(response.into_body(), 1024 * 1024)
        .await
        .expect("read response body");
    serde_json::from_slice(&bytes).expect("parse response json")
}

#[tokio::test]
async fn phone_code_login_uses_fixed_development_code_and_returns_dual_tokens() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;

    let send_code_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/auth/phone/code",
            json!({
                "phone": "13800138000",
                "agreement_accepted": true,
                "device": {
                    "device_id": "ios-simulator-auth-test",
                    "device_name": "iPhone 17 Pro",
                    "platform": "iOS",
                    "app_version": "1.0"
                }
            }),
        ))
        .await
        .expect("send phone code");
    assert_eq!(send_code_response.status(), StatusCode::OK);

    let send_code_body = response_json(send_code_response).await;
    assert_eq!(send_code_body["success"], true);
    assert_eq!(send_code_body["code"], "auth.code_sent");
    assert_eq!(send_code_body["message"], "验证码已发送");

    let challenge_id = send_code_body["data"]["challenge_id"]
        .as_str()
        .expect("challenge_id");

    let verify_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/auth/phone/verify",
            json!({
                "challenge_id": challenge_id,
                "code": "123456",
                "device": {
                    "device_id": "ios-simulator-auth-test",
                    "device_name": "iPhone 17 Pro",
                    "platform": "iOS",
                    "app_version": "1.0"
                }
            }),
        ))
        .await
        .expect("verify phone code");
    assert_eq!(verify_response.status(), StatusCode::OK);

    let verify_body = response_json(verify_response).await;
    assert_eq!(verify_body["success"], true);
    assert_eq!(verify_body["code"], "auth.login_success");
    assert_eq!(verify_body["message"], "登录成功");
    assert!(verify_body["data"]["access_token"].as_str().is_some());
    assert!(verify_body["data"]["refresh_token"].as_str().is_some());
    assert_eq!(verify_body["data"]["user"]["phone"], "13800138000");
}

#[tokio::test]
async fn phone_code_resend_is_limited_for_sixty_seconds() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;

    let first_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/auth/phone/code",
            json!({
                "phone": "13800138999",
                "agreement_accepted": true,
                "device": {
                    "device_id": "ios-simulator-resend-limit-test",
                    "device_name": "iPhone 17 Pro",
                    "platform": "iOS",
                    "app_version": "1.0"
                }
            }),
        ))
        .await
        .expect("send first phone code");
    assert_eq!(first_response.status(), StatusCode::OK);

    let second_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/auth/phone/code",
            json!({
                "phone": "13800138999",
                "agreement_accepted": true,
                "device": {
                    "device_id": "ios-simulator-resend-limit-test",
                    "device_name": "iPhone 17 Pro",
                    "platform": "iOS",
                    "app_version": "1.0"
                }
            }),
        ))
        .await
        .expect("send repeated phone code");
    assert_eq!(second_response.status(), StatusCode::TOO_MANY_REQUESTS);

    let body = response_json(second_response).await;
    assert_eq!(body["success"], false);
    assert_eq!(body["code"], "auth.code_cooling_down");
    assert_eq!(body["message"], "请 60 秒后重新获取验证码");
}

#[tokio::test]
async fn password_login_returns_precise_message_for_wrong_password() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    app.seed_user_with_password("13800138001", "correct-password")
        .await;

    let response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/auth/password/login",
            json!({
                "phone": "13800138001",
                "password": "wrong-password",
                "device": {
                    "device_id": "ios-simulator-password-test",
                    "device_name": "iPhone 17 Pro",
                    "platform": "iOS",
                    "app_version": "1.0"
                }
            }),
        ))
        .await
        .expect("password login");
    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);

    let body = response_json(response).await;
    assert_eq!(body["success"], false);
    assert_eq!(body["code"], "auth.invalid_credentials");
    assert_eq!(body["message"], "手机号或密码错误");
}

#[tokio::test]
async fn refresh_rotates_refresh_token_and_rejects_old_token() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let login = app
        .seed_login_session("13800138002", "ios-simulator-refresh-test")
        .await;

    let refresh_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/auth/refresh",
            json!({
                "refresh_token": login.refresh_token,
                "device_id": "ios-simulator-refresh-test"
            }),
        ))
        .await
        .expect("refresh token");
    assert_eq!(refresh_response.status(), StatusCode::OK);

    let refresh_body = response_json(refresh_response).await;
    assert_eq!(refresh_body["success"], true);
    assert_eq!(refresh_body["message"], "登录状态已刷新");
    let new_refresh_token = refresh_body["data"]["refresh_token"]
        .as_str()
        .expect("new refresh token");
    assert_ne!(new_refresh_token, login.refresh_token);

    let replay_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/auth/refresh",
            json!({
                "refresh_token": login.refresh_token,
                "device_id": "ios-simulator-refresh-test"
            }),
        ))
        .await
        .expect("replay old refresh token");
    assert_eq!(replay_response.status(), StatusCode::UNAUTHORIZED);

    let replay_body = response_json(replay_response).await;
    assert_eq!(replay_body["success"], false);
    assert_eq!(replay_body["code"], "auth.refresh_reused");
    assert_eq!(replay_body["message"], "登录状态异常，请重新登录");
}

#[tokio::test]
async fn refresh_token_survives_backend_app_rebuild() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let login = app
        .seed_login_session("13800138008", "ios-simulator-restart-test")
        .await;
    let restarted_app =
        maohuoban_rust::build_backend_app(maohuoban_rust::BackendConfig::local_test())
            .await
            .expect("rebuild backend app");

    let refresh_response = restarted_app
        .router
        .oneshot(json_request(
            "POST",
            "/api/v1/auth/refresh",
            json!({
                "refresh_token": login.refresh_token,
                "device_id": "ios-simulator-restart-test"
            }),
        ))
        .await
        .expect("refresh token after rebuild");
    assert_eq!(refresh_response.status(), StatusCode::OK);

    let refresh_body = response_json(refresh_response).await;
    assert_eq!(refresh_body["success"], true);
    assert_eq!(refresh_body["code"], "auth.refresh_success");
    assert!(refresh_body["data"]["refresh_token"].as_str().is_some());
}

#[tokio::test]
async fn oauth_provider_endpoint_keeps_stable_todo_contract() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;

    let response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/auth/oauth/apple",
            json!({
                "identity_token": "todo-token",
                "nonce": "todo-nonce"
            }),
        ))
        .await
        .expect("apple oauth todo");
    assert_eq!(response.status(), StatusCode::NOT_IMPLEMENTED);

    let body = response_json(response).await;
    assert_eq!(body["success"], false);
    assert_eq!(body["code"], "auth.oauth_todo");
    assert_eq!(body["message"], "Apple 登录暂未开放");
}

#[tokio::test]
async fn logout_revokes_current_device_refresh_session() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let login = app
        .seed_login_session("13800138003", "ios-simulator-logout-test")
        .await;

    let logout_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/auth/logout",
            json!({
                "refresh_token": login.refresh_token,
                "device_id": "ios-simulator-logout-test"
            }),
        ))
        .await
        .expect("logout current session");
    assert_eq!(logout_response.status(), StatusCode::OK);

    let logout_body = response_json(logout_response).await;
    assert_eq!(logout_body["success"], true);
    assert_eq!(logout_body["code"], "auth.logout_success");
    assert_eq!(logout_body["message"], "已退出登录");

    let refresh_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/auth/refresh",
            json!({
                "refresh_token": login.refresh_token,
                "device_id": "ios-simulator-logout-test"
            }),
        ))
        .await
        .expect("refresh after logout");
    assert_eq!(refresh_response.status(), StatusCode::UNAUTHORIZED);

    let refresh_body = response_json(refresh_response).await;
    assert_eq!(refresh_body["code"], "auth.refresh_invalid");
    assert_eq!(refresh_body["message"], "登录状态已失效，请重新登录");
}

#[tokio::test]
async fn account_recovery_resets_password_and_revokes_old_sessions() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    app.seed_user_with_password("13800138004", "old-password")
        .await;
    let old_login = app
        .seed_login_session("13800138004", "ios-simulator-recovery-test")
        .await;

    let code_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/account-recovery/code",
            json!({
                "phone": "13800138004",
                "device": {
                    "device_id": "ios-simulator-recovery-test",
                    "device_name": "iPhone 17 Pro",
                    "platform": "iOS",
                    "app_version": "1.0"
                }
            }),
        ))
        .await
        .expect("send recovery code");
    assert_eq!(code_response.status(), StatusCode::OK);

    let code_body = response_json(code_response).await;
    assert_eq!(code_body["success"], true);
    assert_eq!(code_body["code"], "account_recovery.code_sent");
    assert_eq!(code_body["message"], "验证码已发送");
    let challenge_id = code_body["data"]["challenge_id"]
        .as_str()
        .expect("challenge id");

    let reset_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/account-recovery/reset-password",
            json!({
                "challenge_id": challenge_id,
                "code": "123456",
                "new_password": "new-password"
            }),
        ))
        .await
        .expect("reset password");
    assert_eq!(reset_response.status(), StatusCode::OK);

    let reset_body = response_json(reset_response).await;
    assert_eq!(reset_body["success"], true);
    assert_eq!(reset_body["code"], "account_recovery.password_reset");
    assert_eq!(reset_body["message"], "密码已重置");

    let old_password_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/auth/password/login",
            json!({
                "phone": "13800138004",
                "password": "old-password",
                "device": {
                    "device_id": "ios-simulator-recovery-test",
                    "device_name": "iPhone 17 Pro",
                    "platform": "iOS",
                    "app_version": "1.0"
                }
            }),
        ))
        .await
        .expect("old password login");
    assert_eq!(old_password_response.status(), StatusCode::UNAUTHORIZED);

    let new_password_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/auth/password/login",
            json!({
                "phone": "13800138004",
                "password": "new-password",
                "device": {
                    "device_id": "ios-simulator-recovery-new-test",
                    "device_name": "iPhone 17 Pro",
                    "platform": "iOS",
                    "app_version": "1.0"
                }
            }),
        ))
        .await
        .expect("new password login");
    assert_eq!(new_password_response.status(), StatusCode::OK);

    let refresh_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/auth/refresh",
            json!({
                "refresh_token": old_login.refresh_token,
                "device_id": "ios-simulator-recovery-test"
            }),
        ))
        .await
        .expect("refresh old session after reset");
    assert_eq!(refresh_response.status(), StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn auth_flow_writes_audit_events_for_observability() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;

    let initial_count = app.audit_event_count().await;
    assert_eq!(initial_count, 0);

    let send_code_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/auth/phone/code",
            json!({
                "phone": "13800138005",
                "agreement_accepted": true,
                "device": {
                    "device_id": "ios-simulator-audit-test",
                    "device_name": "iPhone 17 Pro",
                    "platform": "iOS",
                    "app_version": "1.0"
                }
            }),
        ))
        .await
        .expect("send phone code");
    assert_eq!(send_code_response.status(), StatusCode::OK);
    let send_code_body = response_json(send_code_response).await;
    let challenge_id = send_code_body["data"]["challenge_id"]
        .as_str()
        .expect("challenge_id");

    let verify_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/auth/phone/verify",
            json!({
                "challenge_id": challenge_id,
                "code": "123456",
                "device": {
                    "device_id": "ios-simulator-audit-test",
                    "device_name": "iPhone 17 Pro",
                    "platform": "iOS",
                    "app_version": "1.0"
                }
            }),
        ))
        .await
        .expect("verify phone code");
    assert_eq!(verify_response.status(), StatusCode::OK);

    assert!(app.audit_event_count().await >= 2);
}
