use axum::http::StatusCode;
use serde_json::json;
use tower::ServiceExt;

use super::{json_request, response_json};

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
