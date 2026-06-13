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
async fn pet_event_detail_returns_current_user_event() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138114").await;

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
    let pet_id = create_pet_body["data"]["id"]
        .as_str()
        .expect("pet id")
        .to_owned();

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
    let event_id = create_event_body["data"]["id"]
        .as_str()
        .expect("event id")
        .to_owned();

    let detail_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/pet-events/{event_id}"),
            Some(&user_id),
        ))
        .await
        .expect("load event detail");

    assert_eq!(detail_response.status(), StatusCode::OK);
    let body = response_json(detail_response).await;
    assert_eq!(body["success"], true);
    assert_eq!(body["code"], "pet.event_loaded");
    assert_eq!(body["message"], "宠物事件已加载");
    assert_eq!(body["data"]["id"], event_id);
    assert_eq!(body["data"]["pet_id"], pet_id);
    assert_eq!(body["data"]["title"], "体重记录");
    assert_eq!(body["data"]["summary"], "5.2kg，较上次稳定");
    assert_eq!(body["data"]["event_kind"], "health");
    assert_eq!(body["data"]["record_revision"], 1);
}

#[tokio::test]
async fn trade_pet_import_creates_pet_and_trade_event() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138118").await;

    let response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets/imports/trade",
            json!({
                "name": "奶盖",
                "species": "cat",
                "breed": "布偶",
                "sex": "female",
                "birthday": "2024-03-20",
                "seller_name": "安心猫舍",
                "trade_reference": "offline-contract-001",
                "summary": "线下交易完成，已完成基础体检",
                "occurred_at": "2026-06-13T10:00:00Z"
            }),
            Some(&user_id),
        ))
        .await
        .expect("import trade pet");

    assert_eq!(response.status(), StatusCode::CREATED);
    let body = response_json(response).await;
    assert_eq!(body["success"], true);
    assert_eq!(body["code"], "pet.trade_imported");
    assert_eq!(body["message"], "交易宠物已导入");
    assert_eq!(body["data"]["pet"]["name"], "奶盖");
    assert_eq!(body["data"]["pet"]["owner_user_id"], user_id);
    assert_eq!(body["data"]["pet"]["source_kind"], "trade_imported");
    assert_eq!(body["data"]["pet"]["managed_status"], "family");
    let pet_id = body["data"]["pet"]["id"].as_str().expect("pet id");
    uuid::Uuid::parse_str(pet_id).expect("pet id should be uuid");

    assert_eq!(body["data"]["event"]["pet_id"], pet_id);
    assert_eq!(body["data"]["event"]["event_kind"], "trade");
    assert_eq!(body["data"]["event"]["event_subkind"], "trade_imported");
    assert_eq!(body["data"]["event"]["title"], "交易宠物导入");
    assert_eq!(
        body["data"]["event"]["summary"],
        "线下交易完成，已完成基础体检"
    );
    assert_eq!(body["data"]["event"]["visibility"], "private");
    assert_eq!(
        body["data"]["event"]["event_payload"]["seller_name"],
        "安心猫舍"
    );
    assert_eq!(
        body["data"]["event"]["event_payload"]["trade_reference"],
        "offline-contract-001"
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

#[tokio::test]
async fn merchant_pet_list_returns_status_filtered_managed_pets() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138111").await;
    let merchant_id = app.seed_merchant_tracking_workspace(&user_id).await;

    let response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/merchants/{merchant_id}/pets?status=available"),
            Some(&user_id),
        ))
        .await
        .expect("load merchant pets");

    assert_eq!(response.status(), StatusCode::OK);
    let body = response_json(response).await;
    assert_eq!(body["success"], true);
    assert_eq!(body["code"], "merchant.pets_loaded");
    assert_eq!(body["message"], "商家宠物列表已加载");
    assert_eq!(body["data"]["merchant_id"], merchant_id);
    assert_eq!(body["data"]["status"], "available");
    assert_eq!(body["data"]["pets"][0]["name"], "小橘");
    assert_eq!(body["data"]["pets"][0]["managed_status"], "available");
    assert_eq!(body["data"]["pets"][1]["name"], "小灰");
    assert_eq!(body["data"]["pets"].as_array().expect("pets").len(), 2);
}

#[tokio::test]
async fn merchant_pet_create_persists_managed_pet_for_verified_merchant() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138112").await;
    let merchant_id = app.seed_merchant_tracking_workspace(&user_id).await;

    let create_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/merchants/{merchant_id}/pets"),
            json!({
                "name": "奶糖",
                "species": "cat",
                "breed": "布偶猫",
                "sex": "female",
                "birthday": "2026-04-01",
                "managed_status": "needs_record"
            }),
            Some(&user_id),
        ))
        .await
        .expect("create merchant pet");

    assert_eq!(create_response.status(), StatusCode::CREATED);
    let create_body = response_json(create_response).await;
    assert_eq!(create_body["success"], true);
    assert_eq!(create_body["code"], "merchant.pet_created");
    assert_eq!(create_body["message"], "商家宠物已新增");
    assert_eq!(create_body["data"]["name"], "奶糖");
    assert_eq!(create_body["data"]["merchant_id"], merchant_id);
    assert_eq!(create_body["data"]["owner_user_id"], Value::Null);
    assert_eq!(create_body["data"]["managed_status"], "needs_record");
    assert_eq!(create_body["data"]["source_kind"], "merchant_managed");
    let pet_id = create_body["data"]["id"].as_str().expect("pet id");
    uuid::Uuid::parse_str(pet_id).expect("merchant pet id should be uuid");

    let list_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/merchants/{merchant_id}/pets?status=needs_record"),
            Some(&user_id),
        ))
        .await
        .expect("load needs record merchant pets");
    assert_eq!(list_response.status(), StatusCode::OK);
    let list_body = response_json(list_response).await;
    let pets = list_body["data"]["pets"].as_array().expect("pets");
    assert!(pets.iter().any(|pet| pet["id"] == pet_id));
}

#[tokio::test]
async fn merchant_publish_available_status_updates_pet_and_records_event() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138115").await;
    let merchant_id = app.seed_merchant_tracking_workspace(&user_id).await;
    let pet_id = "69f4570a-aea8-4197-a98c-33ed56c6ff78";

    let publish_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/merchants/{merchant_id}/pets/{pet_id}/available-status"),
            json!({
                "summary": "已完成基础健康记录，可预约到店看猫。",
                "occurred_at": "2026-06-14T10:00:00Z"
            }),
            Some(&user_id),
        ))
        .await
        .expect("publish available status");

    assert_eq!(publish_response.status(), StatusCode::OK);
    let publish_body = response_json(publish_response).await;
    assert_eq!(publish_body["success"], true);
    assert_eq!(publish_body["code"], "merchant.available_status_published");
    assert_eq!(publish_body["message"], "可售状态已发布");
    assert_eq!(publish_body["data"]["pet"]["id"], pet_id);
    assert_eq!(publish_body["data"]["pet"]["managed_status"], "available");
    assert_eq!(publish_body["data"]["event"]["pet_id"], pet_id);
    assert_eq!(publish_body["data"]["event"]["event_kind"], "merchant");
    assert_eq!(
        publish_body["data"]["event"]["event_subkind"],
        "available_status"
    );
    assert_eq!(publish_body["data"]["event"]["visibility"], "buyer_visible");
    assert_eq!(
        publish_body["data"]["event"]["summary"],
        "已完成基础健康记录，可预约到店看猫。"
    );

    let available_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/merchants/{merchant_id}/pets?status=available"),
            Some(&user_id),
        ))
        .await
        .expect("load available merchant pets");
    assert_eq!(available_response.status(), StatusCode::OK);
    let available_body = response_json(available_response).await;
    let pets = available_body["data"]["pets"].as_array().expect("pets");
    assert!(pets.iter().any(|pet| pet["id"] == pet_id));
}

#[tokio::test]
async fn merchant_litter_detail_returns_traceable_family_context() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138113").await;
    let merchant_id = app.seed_merchant_tracking_workspace(&user_id).await;

    let dashboard_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            "/api/v1/home/dashboard",
            Some(&user_id),
        ))
        .await
        .expect("load home dashboard");
    assert_eq!(dashboard_response.status(), StatusCode::OK);
    let dashboard_body = response_json(dashboard_response).await;
    let litter_id = dashboard_body["data"]["merchant_dashboard"]["litters"][0]["id"]
        .as_str()
        .expect("litter id");

    let detail_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/merchants/{merchant_id}/litters/{litter_id}"),
            Some(&user_id),
        ))
        .await
        .expect("load merchant litter detail");

    assert_eq!(detail_response.status(), StatusCode::OK);
    let body = response_json(detail_response).await;
    assert_eq!(body["success"], true);
    assert_eq!(body["code"], "merchant.litter_loaded");
    assert_eq!(body["message"], "窝次详情已加载");
    assert_eq!(body["data"]["id"], litter_id);
    assert_eq!(body["data"]["merchant_id"], merchant_id);
    assert_eq!(body["data"]["name"], "2026 春季 A 窝");
    assert_eq!(body["data"]["born_count"], 3);
    assert_eq!(body["data"]["alive_count"], 3);
    assert_eq!(body["data"]["available_count"], 2);
    assert_eq!(body["data"]["sire_pet"]["name"], "Leo");
    assert_eq!(body["data"]["dam_pet"]["name"], "Luna");
    assert_eq!(
        body["data"]["children"].as_array().expect("children").len(),
        3
    );
    assert_eq!(body["data"]["recent_events"][0]["title"], "A 窝出生记录");
    assert!(
        body["data"]["relationships"]
            .as_array()
            .expect("relationships")
            .iter()
            .any(|relationship| relationship["relationship_kind"] == "same_litter")
    );
}

#[tokio::test]
async fn merchant_pet_list_requires_user_context() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;

    let response = app
        .router()
        .oneshot(empty_request(
            "GET",
            "/api/v1/merchants/3a85d5e7-1d03-41a1-9f8f-7c34a1e5a71f/pets?status=available",
            None,
        ))
        .await
        .expect("load merchant pets without user context");

    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
    let body = response_json(response).await;
    assert_eq!(body["success"], false);
    assert_eq!(body["code"], "pet.unauthorized");
    assert_eq!(body["message"], "请先登录");
}
