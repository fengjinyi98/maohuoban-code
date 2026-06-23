use axum::http::StatusCode;
use serde_json::json;
use tower::ServiceExt;

use super::{json_request, response_json};

#[tokio::test]
#[allow(clippy::too_many_lines)]
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
