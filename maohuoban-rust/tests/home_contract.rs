#![allow(clippy::needless_pass_by_value)]

use axum::{
    body::{Body, to_bytes},
    http::{Request, StatusCode},
};
use serde_json::{Value, json};
use tower::ServiceExt;

/// `empty_request` 构造无 body HTTP 请求
/// 核心职责：
/// - 固定首页契约测试请求形态
/// - 保持测试对路由细节的依赖最小
fn empty_request(method: &str, uri: &str) -> Request<Body> {
    contextual_empty_request(method, uri, None)
}

/// `contextual_empty_request` 构造携带用户上下文的无 body 请求
/// 核心职责：
/// - 支持首页真实聚合读取当前用户宠物数据
/// - 保持 seed 测试可继续使用无上下文请求
fn contextual_empty_request(method: &str, uri: &str, user_id: Option<&str>) -> Request<Body> {
    let mut builder = Request::builder().method(method).uri(uri);
    if let Some(user_id) = user_id {
        builder = builder.header("x-maohuoban-user-id", user_id);
    }
    builder.body(Body::empty()).expect("build test request")
}

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

/// `login_user_id` 使用真实验证码登录获取用户 id
/// 核心职责：
/// - 复用认证契约的开发验证码
/// - 为首页真实聚合提供当前用户上下文
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
                    "device_id": "ios-simulator-home-contract",
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
                    "device_id": "ios-simulator-home-contract",
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
async fn home_dashboard_returns_pet_owner_snapshot() {
    let app = maohuoban_rust::test_support::spawn_home_test_app().await;
    app.seed_pet_owner_home().await;

    let response = app
        .router()
        .oneshot(empty_request("GET", "/api/v1/home/dashboard"))
        .await
        .expect("load home dashboard");
    assert_eq!(response.status(), StatusCode::OK);

    let body = response_json(response).await;
    assert_eq!(body["success"], true);
    assert_eq!(body["code"], "home.dashboard_loaded");
    assert_eq!(body["message"], "首页已加载");
    assert_eq!(body["data"]["identity"]["kind"], "pet_owner");
    assert_eq!(body["data"]["selected_pet"]["name"], "糯米");
    assert_eq!(
        body["data"]["care_summary"]["metrics"][0]["kind"],
        "appetite"
    );
    assert_eq!(body["data"]["quick_actions"][0]["kind"], "daily_record");
    assert_eq!(
        body["data"]["partner_recommendation"]["relationship_kind"],
        "same_city"
    );
    assert_eq!(body["data"]["recent_timeline"][0]["event_kind"], "weight");
    assert!(body["data"]["merchant_dashboard"].is_null());
    assert!(body["data"]["empty_state"].is_null());
}

#[tokio::test]
async fn home_dashboard_returns_create_pet_empty_state() {
    let app = maohuoban_rust::test_support::spawn_home_test_app().await;
    app.seed_new_user_home().await;

    let response = app
        .router()
        .oneshot(empty_request("GET", "/api/v1/home/dashboard"))
        .await
        .expect("load empty home dashboard");
    assert_eq!(response.status(), StatusCode::OK);

    let body = response_json(response).await;
    assert_eq!(body["success"], true);
    assert_eq!(body["data"]["identity"]["kind"], "new_user");
    assert!(body["data"]["selected_pet"].is_null());
    assert_eq!(body["data"]["empty_state"]["kind"], "create_first_pet");
    assert_eq!(
        body["data"]["empty_state"]["primary_action"]["kind"],
        "create_pet"
    );
    assert!(body["data"]["recommended_content"].as_array().is_some());
}

#[tokio::test]
async fn home_dashboard_returns_merchant_workspace_snapshot() {
    let app = maohuoban_rust::test_support::spawn_home_test_app().await;
    app.seed_merchant_home().await;

    let response = app
        .router()
        .oneshot(empty_request("GET", "/api/v1/home/dashboard"))
        .await
        .expect("load merchant home dashboard");
    assert_eq!(response.status(), StatusCode::OK);

    let body = response_json(response).await;
    assert_eq!(body["success"], true);
    assert_eq!(body["data"]["identity"]["kind"], "certified_merchant");
    assert!(body["data"]["selected_pet"].is_null());
    assert_eq!(
        body["data"]["merchant_dashboard"]["status_counts"][0]["status"],
        "available"
    );
    assert_eq!(
        body["data"]["merchant_dashboard"]["litters"][0]["name"],
        "2026 春季 A 窝"
    );
    assert_eq!(
        body["data"]["merchant_dashboard"]["pending_tasks"][0]["kind"],
        "complete_health_record"
    );
    assert!(body["data"]["empty_state"].is_null());
}

#[tokio::test]
async fn home_dashboard_uses_current_user_pet_records_when_user_context_exists() {
    let app = maohuoban_rust::test_support::spawn_home_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138220").await;

    let empty_response = app
        .router()
        .oneshot(contextual_empty_request(
            "GET",
            "/api/v1/home/dashboard",
            Some(&user_id),
        ))
        .await
        .expect("load empty home dashboard");
    assert_eq!(empty_response.status(), StatusCode::OK);
    let empty_body = response_json(empty_response).await;
    assert_eq!(empty_body["data"]["identity"]["kind"], "new_user");
    assert_eq!(
        empty_body["data"]["empty_state"]["kind"],
        "create_first_pet"
    );

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
    let pet_id = create_pet_body["data"]["id"].as_str().expect("pet id");

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

    let dashboard_response = app
        .router()
        .oneshot(contextual_empty_request(
            "GET",
            "/api/v1/home/dashboard",
            Some(&user_id),
        ))
        .await
        .expect("load pet owner dashboard");
    assert_eq!(dashboard_response.status(), StatusCode::OK);
    let dashboard_body = response_json(dashboard_response).await;
    assert_eq!(dashboard_body["data"]["identity"]["kind"], "pet_owner");
    assert_eq!(dashboard_body["data"]["selected_pet"]["name"], "糯米");
    assert_eq!(dashboard_body["data"]["selected_pet"]["id"], pet_id);
    assert_eq!(
        dashboard_body["data"]["quick_actions"][0]["kind"],
        "daily_record"
    );
    assert_eq!(
        dashboard_body["data"]["recent_timeline"][0]["title"],
        "体重记录"
    );
    assert!(dashboard_body["data"]["empty_state"].is_null());
}
