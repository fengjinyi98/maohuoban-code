use axum::http::StatusCode;
use serde_json::json;
use tower::ServiceExt;

use super::{json_request, response_json};

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
