use axum::http::StatusCode;
use serde_json::json;
use tower::ServiceExt;

use super::super::{json_request, response_json};
use super::{device_payload, send_phone_code};

/// 验证码登录返回正确的用户资料摘要（`phone`、`phone_masked`、`has_password`、`display_name`、`avatar_presentation`）
#[tokio::test]
async fn phone_code_login_returns_current_user_profile_summary_without_badges() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;

    let challenge_id = send_phone_code(&app, "13800138010", "ios-profile-login-summary").await;
    let response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/auth/phone/verify",
            json!({
                "challenge_id": challenge_id,
                "code": "123456",
                "device": device_payload("ios-profile-login-summary")
            }),
        ))
        .await
        .expect("verify phone code");
    assert_eq!(response.status(), StatusCode::OK);

    let body = response_json(response).await;
    let user = &body["data"]["user"];
    assert_eq!(user["phone"], "13800138010");
    assert_eq!(user["phone_masked"], "138****8010");
    assert_eq!(user["has_password"], false);
    assert!(user.get("badges").is_none());

    let profile = &user["profile"];
    assert!(profile["maohuoban_id"].as_str().is_some());
    assert!(
        profile["display_name"]
            .as_str()
            .expect("display_name")
            .starts_with("毛伙伴用户")
    );
    assert!(profile.get("join_sequence").is_none());
    assert_eq!(profile["avatar_presentation"]["sex"], "unknown");
    assert_eq!(profile["avatar_presentation"]["sex_visibility"], "hidden");
}
