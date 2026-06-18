use axum::http::StatusCode;
use serde_json::json;
use tower::ServiceExt;

use super::{json_request, response_json};

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
