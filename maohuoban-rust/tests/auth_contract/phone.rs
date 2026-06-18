use axum::http::StatusCode;
use serde_json::json;
use tower::ServiceExt;

use super::{json_request, response_json};

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
