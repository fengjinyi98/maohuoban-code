#![allow(clippy::doc_markdown, clippy::needless_pass_by_value)]

use axum::{
    body::{Body, to_bytes},
    http::{Request, StatusCode},
};
use serde_json::{Value, json};
use tower::ServiceExt;

/// json_request 构造 JSON HTTP 请求
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

/// empty_request 构造无 body HTTP 请求
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

/// response_json 读取 JSON 响应
/// 核心职责：
/// - 校验响应 body 可解析
/// - 为契约测试提供统一断言入口
async fn response_json(response: axum::response::Response) -> Value {
    let bytes = to_bytes(response.into_body(), 1024 * 1024)
        .await
        .expect("read response body");
    serde_json::from_slice(&bytes).expect("parse response json")
}

/// login_user_id 使用真实验证码登录获取用户 id
/// 核心职责：
/// - 复用认证契约的开发验证码
/// - 为同城接口提供当前用户上下文
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
                    "device_id": "ios-simulator-samecity-contract",
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
                    "device_id": "ios-simulator-samecity-contract",
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
async fn samecity_hospital_list_returns_verified_city_hospitals() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138119").await;

    let response = app
        .router()
        .oneshot(empty_request(
            "GET",
            "/api/v1/same-city/hospitals?city=成都",
            Some(&user_id),
        ))
        .await
        .expect("list hospitals");

    assert_eq!(response.status(), StatusCode::OK);
    let body = response_json(response).await;
    assert_eq!(body["success"], true);
    assert_eq!(body["code"], "samecity.hospitals_loaded");
    assert_eq!(body["data"]["city"], "成都");
    assert_eq!(body["data"]["hospitals"][0]["city"], "成都");
    assert_eq!(
        body["data"]["hospitals"][0]["verification_status"],
        "verified"
    );
    let hospital_id = body["data"]["hospitals"][0]["id"]
        .as_str()
        .expect("hospital id");
    uuid::Uuid::parse_str(hospital_id).expect("hospital id should be uuid");
}

#[tokio::test]
async fn samecity_hospital_booking_creates_pending_appointment_for_current_pet() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138120").await;

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
    let pet_body = response_json(create_pet_response).await;
    let pet_id = pet_body["data"]["id"].as_str().expect("pet id");

    let hospitals_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            "/api/v1/same-city/hospitals?city=成都",
            Some(&user_id),
        ))
        .await
        .expect("list hospitals");
    assert_eq!(hospitals_response.status(), StatusCode::OK);
    let hospitals_body = response_json(hospitals_response).await;
    let hospital_id = hospitals_body["data"]["hospitals"][0]["id"]
        .as_str()
        .expect("hospital id");

    let response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/same-city/hospital-appointments",
            json!({
                "hospital_id": hospital_id,
                "pet_id": pet_id,
                "scheduled_at": "2026-06-15T09:30:00Z",
                "reason": "基础体检",
                "note": "希望安排上午到店"
            }),
            Some(&user_id),
        ))
        .await
        .expect("book hospital");

    assert_eq!(response.status(), StatusCode::CREATED);
    let body = response_json(response).await;
    assert_eq!(body["success"], true);
    assert_eq!(body["code"], "samecity.hospital_appointment_created");
    assert_eq!(body["message"], "医院预约已提交");
    assert_eq!(body["data"]["owner_user_id"], user_id);
    assert_eq!(body["data"]["pet_id"], pet_id);
    assert_eq!(body["data"]["hospital_id"], hospital_id);
    assert_eq!(body["data"]["scheduled_at"], "2026-06-15T09:30:00Z");
    assert_eq!(body["data"]["reason"], "基础体检");
    assert_eq!(body["data"]["note"], "希望安排上午到店");
    assert_eq!(body["data"]["status"], "pending");
    let appointment_id = body["data"]["id"].as_str().expect("appointment id");
    uuid::Uuid::parse_str(appointment_id).expect("appointment id should be uuid");
}
