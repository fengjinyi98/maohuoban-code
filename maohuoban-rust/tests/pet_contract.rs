#![allow(clippy::needless_pass_by_value)]

use axum::{
    body::{Body, to_bytes},
    http::{Request, StatusCode},
};
use serde_json::{Value, json};
use tower::ServiceExt;

/// `json_request` 构造 JSON HTTP 请求
/// 核心职责：
/// - 固定测试请求的 Content-Type
/// - 支持附加用户上下文请求头
fn json_request(method: &str, uri: &str, body: Value, user_id: Option<&str>) -> Request<Body> {
    let mut builder = Request::builder()
        .method(method)
        .uri(uri)
        .header("content-type", "application/json");
    if let Some(user_id) = user_id {
        builder = builder.header("x-maohuoban-user-id", user_id);
    }
    builder
        .body(Body::from(body.to_string()))
        .expect("build json request")
}

/// `empty_request` 构造无 body HTTP 请求
/// 核心职责：
/// - 固定 GET 请求形态
/// - 支持附加用户上下文请求头
fn empty_request(method: &str, uri: &str, user_id: Option<&str>) -> Request<Body> {
    let mut builder = Request::builder().method(method).uri(uri);
    if let Some(user_id) = user_id {
        builder = builder.header("x-maohuoban-user-id", user_id);
    }
    builder.body(Body::empty()).expect("build empty request")
}

/// `response_json` 读取 JSON 响应
/// 核心职责：
/// - 校验响应 body 可解析
/// - 为契约测试提供统一断言入口
async fn response_json(response: axum::response::Response) -> Value {
    let bytes = to_bytes(response.into_body(), 1024 * 1024)
        .await
        .expect("read response body");
    serde_json::from_slice(&bytes).expect("parse response json")
}

/// `login_user_id` 使用真实验证码登录获取用户 id
/// 核心职责：
/// - 复用认证契约的开发验证码
/// - 为 pet 接口提供当前用户上下文
async fn login_user_id(app: &maohuoban_rust::test_support::AuthTestApp, phone: &str) -> String {
    let send_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/auth/phone/code",
            json!({
                "phone": phone,
                "agreement_accepted": true,
                "device": {
                    "device_id": "ios-simulator-pet-contract",
                    "device_name": "iPhone 17 Pro",
                    "platform": "iOS",
                    "app_version": "1.0"
                }
            }),
            None,
        ))
        .await
        .expect("send phone code");
    assert_eq!(send_response.status(), StatusCode::OK);
    let send_body = response_json(send_response).await;
    let challenge_id = send_body["data"]["challenge_id"]
        .as_str()
        .expect("challenge id");

    let verify_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/auth/phone/verify",
            json!({
                "challenge_id": challenge_id,
                "code": "123456",
                "device": {
                    "device_id": "ios-simulator-pet-contract",
                    "device_name": "iPhone 17 Pro",
                    "platform": "iOS",
                    "app_version": "1.0"
                }
            }),
            None,
        ))
        .await
        .expect("verify phone code");
    assert_eq!(verify_response.status(), StatusCode::OK);
    let verify_body = response_json(verify_response).await;
    verify_body["data"]["user"]["id"]
        .as_str()
        .expect("user id")
        .to_owned()
}

#[tokio::test]
async fn pet_profile_event_and_timeline_are_persisted() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138110").await;

    let create_pet_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "糯米",
                "species": "dog",
                "breed": "比熊犬",
                "sex": "female",
                "birthday": "2024-04-01"
            }),
            Some(&user_id),
        ))
        .await
        .expect("create pet");
    assert_eq!(create_pet_response.status(), StatusCode::CREATED);
    let create_pet_body = response_json(create_pet_response).await;
    assert_eq!(create_pet_body["success"], true);
    assert_eq!(create_pet_body["code"], "pet.created");
    assert_eq!(create_pet_body["message"], "宠物档案已创建");
    assert_eq!(create_pet_body["data"]["name"], "糯米");
    assert_eq!(create_pet_body["data"]["owner_user_id"], user_id);
    let pet_id = create_pet_body["data"]["id"]
        .as_str()
        .expect("pet id")
        .to_owned();
    uuid::Uuid::parse_str(&pet_id).expect("pet id should be uuid");

    let create_event_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/events"),
            json!({
                "event_kind": "health",
                "event_subkind": "weight",
                "title": "体重记录",
                "summary": "5.2kg，较上次稳定",
                "visibility": "private",
                "occurred_at": "2026-06-13T09:20:00Z",
                "event_payload": {
                    "weight_kg": 5.2
                }
            }),
            Some(&user_id),
        ))
        .await
        .expect("create pet event");
    assert_eq!(create_event_response.status(), StatusCode::CREATED);
    let create_event_body = response_json(create_event_response).await;
    assert_eq!(create_event_body["success"], true);
    assert_eq!(create_event_body["code"], "pet.event_created");
    assert_eq!(create_event_body["data"]["pet_id"], pet_id);
    assert_eq!(create_event_body["data"]["event_kind"], "health");
    assert_eq!(create_event_body["data"]["event_subkind"], "weight");
    assert_eq!(create_event_body["data"]["record_revision"], 1);

    let timeline_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/pets/{pet_id}/timeline"),
            Some(&user_id),
        ))
        .await
        .expect("load pet timeline");
    assert_eq!(timeline_response.status(), StatusCode::OK);
    let timeline_body = response_json(timeline_response).await;
    assert_eq!(timeline_body["success"], true);
    assert_eq!(timeline_body["code"], "pet.timeline_loaded");
    assert_eq!(timeline_body["data"]["pet_id"], pet_id);
    assert_eq!(timeline_body["data"]["events"][0]["title"], "体重记录");
    assert_eq!(
        timeline_body["data"]["events"][0]["summary"],
        "5.2kg，较上次稳定"
    );
}

#[tokio::test]
async fn pet_endpoints_require_user_context() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;

    let response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "糯米",
                "species": "dog"
            }),
            None,
        ))
        .await
        .expect("create pet without user context");
    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
    let body = response_json(response).await;
    assert_eq!(body["success"], false);
    assert_eq!(body["code"], "pet.unauthorized");
    assert_eq!(body["message"], "请先登录");
}
