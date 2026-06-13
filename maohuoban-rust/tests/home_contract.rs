#![allow(clippy::needless_pass_by_value)]

use axum::{
    body::{Body, to_bytes},
    http::{Request, StatusCode},
};
use serde_json::Value;
use tower::ServiceExt;

/// `empty_request` 构造无 body HTTP 请求
/// 核心职责：
/// - 固定首页契约测试请求形态
/// - 保持测试对路由细节的依赖最小
fn empty_request(method: &str, uri: &str) -> Request<Body> {
    Request::builder()
        .method(method)
        .uri(uri)
        .body(Body::empty())
        .expect("build test request")
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
