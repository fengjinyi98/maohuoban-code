use axum::http::StatusCode;
use serde_json::json;
use tower::ServiceExt;

use super::super::{json_request, response_json};
use super::{authorized_get_request, device_payload, send_phone_code};

/// `GET /api/v1/profile/me` 与登录响应中的 `profile` 字段一致，无 `join_sequence`/`badges`
#[tokio::test]
async fn profile_me_returns_same_profile_created_by_login_token() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;

    let challenge_id = send_phone_code(&app, "13800138011", "ios-profile-me").await;
    let login_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/auth/phone/verify",
            json!({
                "challenge_id": challenge_id,
                "code": "123456",
                "device": device_payload("ios-profile-me")
            }),
        ))
        .await
        .expect("verify phone code");
    assert_eq!(login_response.status(), StatusCode::OK);

    let login_body = response_json(login_response).await;
    let access_token = login_body["data"]["access_token"]
        .as_str()
        .expect("access token");
    let login_profile = &login_body["data"]["user"]["profile"];

    let profile_response = app
        .router()
        .oneshot(authorized_get_request("/api/v1/profile/me", access_token))
        .await
        .expect("get profile me");
    assert_eq!(profile_response.status(), StatusCode::OK);

    let profile_body = response_json(profile_response).await;
    assert_eq!(profile_body["success"], true);
    assert_eq!(profile_body["code"], "profile.loaded");
    assert_eq!(profile_body["message"], "个人资料已加载");
    assert_eq!(
        profile_body["data"]["maohuoban_id"],
        login_profile["maohuoban_id"]
    );
    assert_eq!(
        profile_body["data"]["display_name"],
        login_profile["display_name"]
    );
    assert_eq!(
        profile_body["data"]["avatar_presentation"],
        login_profile["avatar_presentation"]
    );
    assert!(profile_body["data"].get("join_sequence").is_none());
    assert!(profile_body["data"].get("badges").is_none());
}
