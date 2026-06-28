#![allow(clippy::needless_pass_by_value)]

// ai_eval Agent Runtime HTTP eval 合同测试
// 核心职责：
// - 用确定性 fake / disabled provider 覆盖边界样例
// - 验证失败链路输出稳定事件和失败原因

use axum::body::{Body, to_bytes};
use axum::http::{Request, StatusCode};
use serde_json::{Value, json};
use std::sync::{Arc, OnceLock};
use tokio::sync::Mutex;
use tower::ServiceExt;

#[tokio::test]
async fn provider_not_configured_eval() {
    let _guard = ai_eval_test_lock().lock_owned().await;
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139101", "ai-eval-provider-error").await;
    let pet = create_pet(&app, &access_token, "毛球").await;
    let pet_id = pet["id"].as_str().expect("pet id");

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &access_token,
            json!({
                "message": "毛球今天拉肚子了怎么办",
                "surface": "home_private",
                "selected_pet_id": pet_id
            }),
        ))
        .await
        .expect("send provider error eval request");

    assert_eq!(response.status(), StatusCode::OK);
    let text = response_text(response).await;
    let event_names = sse_event_names(&text);

    assert!(
        event_names.starts_with(&["message_started".to_owned()]),
        "eval should start with message_started, got events {event_names:?} and body {text}"
    );
    assert!(
        event_names.contains(&"error".to_owned()),
        "eval should emit provider error, got events {event_names:?} and body {text}"
    );
    assert!(
        !event_names.contains(&"message_completed".to_owned()),
        "provider error eval must not emit normal assistant final, got body {text}"
    );

    let error = sse_event_data(&text, "error");
    assert_eq!(error["code"], "ai.provider.not_configured");
    assert_eq!(error["retryable"], false);
    assert_eq!(
        error["safe_fallback_text"],
        "暂时无法获取回答，请稍后重试。"
    );
}

#[tokio::test]
async fn unauthorized_pet_eval() {
    let _guard = ai_eval_test_lock().lock_owned().await;
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let owner_token = login_and_get_token(&app, "13800139102", "ai-eval-pet-owner").await;
    let owner_pet = create_pet(&app, &owner_token, "毛球").await;
    let owner_pet_id = owner_pet["id"].as_str().expect("owner pet id");

    let actor_token = login_and_get_token(&app, "13800139103", "ai-eval-pet-actor").await;
    let _actor_pet = create_pet(&app, &actor_token, "豆豆").await;

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &actor_token,
            json!({
                "message": "今天怎么样",
                "surface": "home_private",
                "selected_pet_id": owner_pet_id
            }),
        ))
        .await
        .expect("send unauthorized pet eval request");

    assert_eq!(response.status(), StatusCode::OK);
    let text = response_text(response).await;
    let event_names = sse_event_names(&text);

    assert_eq!(
        event_names,
        vec![
            "message_started".to_owned(),
            "pet_resolution".to_owned(),
            "message_completed".to_owned(),
        ],
        "unauthorized pet eval should skip provider, got body {text}"
    );

    let resolution = sse_event_data(&text, "pet_resolution");
    assert_eq!(
        resolution["resolution"]["status"],
        "unauthorized_or_not_found"
    );
    assert!(
        !text.contains("event: error") && !text.contains("ai.provider.not_configured"),
        "unauthorized pet eval should not call provider, got body {text}"
    );

    let row: (String, bool, Option<String>) = sqlx::query_as(
        r"
        SELECT tool_name, allowed, denied_reason
        FROM ai_tool_access_logs
        WHERE tool_name = 'list_authorized_pet_candidates'
        ORDER BY created_at DESC
        LIMIT 1
        ",
    )
    .fetch_one(app.pool())
    .await
    .expect("read latest tool access log");

    assert_eq!(row.0, "list_authorized_pet_candidates");
    assert!(!row.1);
    assert_eq!(row.2.as_deref(), Some("unauthorized_or_not_found"));
}

fn json_request(method: &str, uri: &str, body: Value) -> Request<Body> {
    Request::builder()
        .method(method)
        .uri(uri)
        .header("content-type", "application/json")
        .body(Body::from(body.to_string()))
        .expect("build test request")
}

fn authorized_json_request(
    method: &str,
    uri: &str,
    access_token: &str,
    body: Value,
) -> Request<Body> {
    Request::builder()
        .method(method)
        .uri(uri)
        .header("authorization", format!("Bearer {access_token}"))
        .header("content-type", "application/json")
        .body(Body::from(body.to_string()))
        .expect("build authorized json request")
}

async fn response_json(response: axum::response::Response) -> Value {
    let bytes = to_bytes(response.into_body(), 1024 * 1024)
        .await
        .expect("read response body");
    serde_json::from_slice(&bytes).expect("parse response json")
}

async fn response_text(response: axum::response::Response) -> String {
    let bytes = to_bytes(response.into_body(), 1024 * 1024)
        .await
        .expect("read response body");
    String::from_utf8(bytes.to_vec()).expect("parse response text")
}

async fn login_and_get_token(
    app: &maohuoban_rust::test_support::AuthTestApp,
    phone: &str,
    device_id: &str,
) -> String {
    let response = app
        .router()
        .clone()
        .oneshot(json_request(
            "POST",
            "/api/v1/auth/phone/code",
            json!({
                "phone": phone,
                "agreement_accepted": true,
                "device": {
                    "device_id": device_id,
                    "device_name": "iPhone 17 Pro",
                    "platform": "iOS",
                    "app_version": "1.0"
                }
            }),
        ))
        .await
        .expect("send phone code");
    assert_eq!(response.status(), StatusCode::OK);
    let body = response_json(response).await;
    let challenge_id = body["data"]["challenge_id"].as_str().expect("challenge_id");

    let response = app
        .router()
        .clone()
        .oneshot(json_request(
            "POST",
            "/api/v1/auth/phone/verify",
            json!({
                "challenge_id": challenge_id,
                "code": "123456",
                "device": {
                    "device_id": device_id,
                    "device_name": "iPhone 17 Pro",
                    "platform": "iOS",
                    "app_version": "1.0"
                }
            }),
        ))
        .await
        .expect("verify phone code");
    assert_eq!(response.status(), StatusCode::OK);
    let body = response_json(response).await;
    body["data"]["access_token"]
        .as_str()
        .expect("access token")
        .to_owned()
}

async fn create_pet(
    app: &maohuoban_rust::test_support::AuthTestApp,
    access_token: &str,
    name: &str,
) -> Value {
    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/pets",
            access_token,
            json!({
                "name": name,
                "species": "cat",
                "breed": "英短",
                "sex": "male",
                "birthday": "2024-01-01",
                "arrival_date": "2024-03-01"
            }),
        ))
        .await
        .expect("create pet");

    assert_eq!(response.status(), StatusCode::CREATED);
    response_json(response).await["data"].clone()
}

fn ai_eval_test_lock() -> Arc<Mutex<()>> {
    static LOCK: OnceLock<Arc<Mutex<()>>> = OnceLock::new();
    LOCK.get_or_init(|| Arc::new(Mutex::new(()))).clone()
}

fn sse_event_names(text: &str) -> Vec<String> {
    text.lines()
        .filter_map(|line| line.strip_prefix("event: "))
        .map(ToOwned::to_owned)
        .collect()
}

fn sse_event_data(text: &str, event_name: &str) -> Value {
    let mut lines = text.lines();
    while let Some(line) = lines.next() {
        if line.trim() == format!("event: {event_name}") {
            for data_line in lines.by_ref() {
                if let Some(data) = data_line.strip_prefix("data: ") {
                    return serde_json::from_str(data).expect("parse sse data");
                }
            }
        }
    }

    panic!("missing SSE event {event_name}, got: {text}");
}
