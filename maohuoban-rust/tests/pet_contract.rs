#![allow(clippy::needless_pass_by_value)]

use std::{env, fs, process::Command};

use axum::{
    body::{Body, to_bytes},
    http::{Request, StatusCode},
};
use base64::{Engine as _, engine::general_purpose::STANDARD};
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

/// `multipart_media_request` 构造媒体上传 multipart 请求
/// 核心职责：
/// - 固定媒体上传测试的 multipart 协议
/// - 同时提交 file 和 `source_client` 两个业务字段
fn multipart_media_request(
    uri: &str,
    file_name: &str,
    mime_type: &str,
    content: &[u8],
    source_client: &str,
    user_id: &str,
) -> Request<Body> {
    let boundary = format!("maohuoban-test-{}", uuid::Uuid::new_v4());
    let mut body = Vec::new();
    body.extend_from_slice(format!("--{boundary}\r\n").as_bytes());
    body.extend_from_slice(
        format!(
            "Content-Disposition: form-data; name=\"file\"; filename=\"{file_name}\"\r\n\
             Content-Type: {mime_type}\r\n\r\n"
        )
        .as_bytes(),
    );
    body.extend_from_slice(content);
    body.extend_from_slice(b"\r\n");
    body.extend_from_slice(format!("--{boundary}\r\n").as_bytes());
    body.extend_from_slice(
        format!(
            "Content-Disposition: form-data; name=\"source_client\"\r\n\r\n{source_client}\r\n"
        )
        .as_bytes(),
    );
    body.extend_from_slice(format!("--{boundary}--\r\n").as_bytes());

    Request::builder()
        .method("POST")
        .uri(uri)
        .header(
            "content-type",
            format!("multipart/form-data; boundary={boundary}"),
        )
        .header("x-maohuoban-user-id", user_id)
        .body(Body::from(body))
        .expect("build multipart media request")
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

/// `red_video_base64` 生成红色视频测试样本
/// 核心职责：
/// - 使用本机 ffmpeg 创建最小 mp4
/// - 返回接口上传所需 base64 内容
fn red_video_base64() -> Option<String> {
    let output_path =
        env::temp_dir().join(format!("maohuoban-red-video-{}.mp4", uuid::Uuid::new_v4()));
    let status = Command::new("ffmpeg")
        .arg("-v")
        .arg("error")
        .arg("-y")
        .arg("-f")
        .arg("lavfi")
        .arg("-i")
        .arg("color=c=red:s=16x16:d=1")
        .arg("-frames:v")
        .arg("1")
        .arg("-pix_fmt")
        .arg("yuv420p")
        .arg(&output_path)
        .status()
        .ok()?;
    if !status.success() {
        return None;
    }

    let content = fs::read(&output_path).ok()?;
    let _ = fs::remove_file(output_path);
    Some(STANDARD.encode(content))
}

/// `red_video_bytes` 生成红色视频测试样本
/// 核心职责：
/// - 复用当前视频 fixture 生成方式
/// - 为 multipart 视频上传提供原始二进制内容
fn red_video_bytes() -> Option<Vec<u8>> {
    red_video_base64().and_then(|content| STANDARD.decode(content).ok())
}

/// `assert_media_cleanup_state` 校验媒体清理状态
/// 核心职责：
/// - 固定资产、绑定和清理任务三项断言
/// - 降低媒体生命周期契约测试重复代码
async fn assert_media_cleanup_state(
    app: &maohuoban_rust::test_support::AuthTestApp,
    asset_id: &str,
    asset_status: &str,
    binding_status: &str,
    job_status: &str,
) {
    let cleanup_state = app.media_cleanup_state(asset_id).await;
    assert_eq!(cleanup_state.asset_status, asset_status);
    assert_eq!(cleanup_state.binding_status, binding_status);
    assert_eq!(cleanup_state.job_status, job_status);
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

#[tokio::test]
async fn pet_profile_crud_persists_extended_profile_fields() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138131").await;

    let create_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "奶盖",
                "species": "cat",
                "breed": "布偶",
                "sex": "female",
                "birthday": "2024-03-20",
                "microchip_number": "156000000000001",
                "arrival_date": "2024-05-01",
                "weight_grams": 4200,
                "neuter_status": "neutered",
                "personality_tags": ["亲人", "爱玩"],
                "note": "对鸡肉过敏"
            }),
            Some(&user_id),
        ))
        .await
        .expect("create extended pet");
    assert_eq!(create_response.status(), StatusCode::CREATED);
    let create_body = response_json(create_response).await;
    assert_eq!(
        create_body["data"]["profile_number"]
            .as_str()
            .unwrap()
            .len(),
        16
    );
    assert_eq!(create_body["data"]["microchip_number"], "156000000000001");
    assert_eq!(create_body["data"]["arrival_date"], "2024-05-01");
    assert_eq!(create_body["data"]["weight_grams"], 4200);
    assert_eq!(create_body["data"]["neuter_status"], "neutered");
    assert_eq!(create_body["data"]["personality_tags"][0], "亲人");
    assert_eq!(create_body["data"]["note"], "对鸡肉过敏");
    let pet_id = create_body["data"]["id"].as_str().expect("pet id");

    let update_response = app
        .router()
        .oneshot(json_request(
            "PATCH",
            &format!("/api/v1/pets/{pet_id}"),
            json!({
                "name": "奶盖宝",
                "breed": "布偶猫",
                "weight_grams": 4350,
                "personality_tags": ["亲人", "安静"],
                "note": "鸡肉过敏，优先喂鸭肉"
            }),
            Some(&user_id),
        ))
        .await
        .expect("update pet");
    assert_eq!(update_response.status(), StatusCode::OK);
    let update_body = response_json(update_response).await;
    assert_eq!(update_body["code"], "pet.updated");
    assert_eq!(update_body["data"]["id"], pet_id);
    assert_eq!(update_body["data"]["name"], "奶盖宝");
    assert_eq!(update_body["data"]["breed"], "布偶猫");
    assert_eq!(update_body["data"]["weight_grams"], 4350);
    assert_eq!(update_body["data"]["microchip_number"], "156000000000001");

    let detail_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/pets/{pet_id}"),
            Some(&user_id),
        ))
        .await
        .expect("load pet detail");
    assert_eq!(detail_response.status(), StatusCode::OK);
    let detail_body = response_json(detail_response).await;
    assert_eq!(detail_body["code"], "pet.loaded");
    assert_eq!(detail_body["data"]["id"], pet_id);
    assert_eq!(
        detail_body["data"]["profile_number"],
        create_body["data"]["profile_number"]
    );

    let list_response = app
        .router()
        .oneshot(empty_request("GET", "/api/v1/pets", Some(&user_id)))
        .await
        .expect("list pets");
    assert_eq!(list_response.status(), StatusCode::OK);
    let list_body = response_json(list_response).await;
    assert_eq!(list_body["code"], "pet.list_loaded");
    assert!(
        list_body["data"]["pets"]
            .as_array()
            .expect("pets")
            .iter()
            .any(|pet| pet["id"] == pet_id)
    );
}

#[tokio::test]
async fn pet_profile_rejects_microchip_replacement_after_it_is_locked() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138132").await;

    let create_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "汤圆",
                "species": "dog",
                "sex": "male",
                "microchip_number": "156000000000002"
            }),
            Some(&user_id),
        ))
        .await
        .expect("create pet");
    assert_eq!(create_response.status(), StatusCode::CREATED);
    let create_body = response_json(create_response).await;
    let pet_id = create_body["data"]["id"].as_str().expect("pet id");

    let update_response = app
        .router()
        .oneshot(json_request(
            "PATCH",
            &format!("/api/v1/pets/{pet_id}"),
            json!({
                "microchip_number": "156000000000099"
            }),
            Some(&user_id),
        ))
        .await
        .expect("replace chip");

    assert_eq!(update_response.status(), StatusCode::BAD_REQUEST);
    let body = response_json(update_response).await;
    assert_eq!(body["success"], false);
    assert_eq!(body["code"], "pet.invalid_input");
}

#[tokio::test]
async fn pet_avatar_upload_creates_traceable_media_binding() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138133").await;

    let create_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "摩卡",
                "species": "dog",
                "sex": "female"
            }),
            Some(&user_id),
        ))
        .await
        .expect("create pet");
    assert_eq!(create_response.status(), StatusCode::CREATED);
    let create_body = response_json(create_response).await;
    let pet_id = create_body["data"]["id"].as_str().expect("pet id");

    let upload_response = app
        .router()
        .oneshot(multipart_media_request(
            &format!("/api/v1/pets/{pet_id}/media/avatar"),
            "avatar.txt",
            "text/plain",
            b"avatar-bytes",
            "ios",
            &user_id,
        ))
        .await
        .expect("upload avatar");
    assert_eq!(upload_response.status(), StatusCode::CREATED);
    let upload_body = response_json(upload_response).await;
    assert_eq!(upload_body["code"], "pet.avatar_uploaded");
    assert_eq!(upload_body["data"]["binding"]["pet_id"], pet_id);
    assert_eq!(upload_body["data"]["binding"]["usage_kind"], "pet.avatar");
    assert_eq!(upload_body["data"]["asset"]["uploaded_by_user_id"], user_id);
    assert_eq!(upload_body["data"]["asset"]["owner_pet_id"], pet_id);
    assert_eq!(upload_body["data"]["asset"]["status"], "bound");
    assert!(
        upload_body["data"]["asset"]["sha256_hex"]
            .as_str()
            .unwrap()
            .len()
            >= 64
    );
    assert!(
        upload_body["data"]["asset"]["object_key"]
            .as_str()
            .unwrap()
            .contains(pet_id)
    );
    let bucket = upload_body["data"]["asset"]["bucket"]
        .as_str()
        .expect("asset bucket");
    let object_key = upload_body["data"]["asset"]["object_key"]
        .as_str()
        .expect("asset object key");
    assert_eq!(
        app.media_object_content(bucket, object_key),
        b"avatar-bytes"
    );
}

#[tokio::test]
async fn pet_background_uploads_support_image_and_video_media_bindings() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138135").await;

    let create_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "花卷",
                "species": "cat",
                "sex": "female"
            }),
            Some(&user_id),
        ))
        .await
        .expect("create pet");
    assert_eq!(create_response.status(), StatusCode::CREATED);
    let create_body = response_json(create_response).await;
    let pet_id = create_body["data"]["id"].as_str().expect("pet id");

    let image_response = app
        .router()
        .oneshot(multipart_media_request(
            &format!("/api/v1/pets/{pet_id}/media/background-image"),
            "background.jpg",
            "image/jpeg",
            b"image-bytes",
            "ios",
            &user_id,
        ))
        .await
        .expect("upload background image");
    assert_eq!(image_response.status(), StatusCode::CREATED);
    let image_body = response_json(image_response).await;
    assert_eq!(image_body["code"], "pet.background_uploaded");
    assert_eq!(
        image_body["data"]["binding"]["usage_kind"],
        "pet.background.image"
    );

    let video_response = app
        .router()
        .oneshot(multipart_media_request(
            &format!("/api/v1/pets/{pet_id}/media/background-video"),
            "background.mp4",
            "video/mp4",
            b"video-bytes",
            "ios",
            &user_id,
        ))
        .await
        .expect("upload background video");
    assert_eq!(video_response.status(), StatusCode::CREATED);
    let video_body = response_json(video_response).await;
    assert_eq!(video_body["code"], "pet.background_uploaded");
    assert_eq!(
        video_body["data"]["binding"]["usage_kind"],
        "pet.background.video"
    );
    assert!(
        video_body["data"]["asset"]["object_key"]
            .as_str()
            .unwrap()
            .contains("background/video")
    );
}

#[tokio::test]
async fn pet_background_image_upload_generates_derivatives_and_theme_color() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138136").await;

    let create_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "红豆",
                "species": "cat",
                "sex": "female"
            }),
            Some(&user_id),
        ))
        .await
        .expect("create pet");
    assert_eq!(create_response.status(), StatusCode::CREATED);
    let create_body = response_json(create_response).await;
    let pet_id = create_body["data"]["id"].as_str().expect("pet id");

    let upload_response = app
        .router()
        .oneshot(multipart_media_request(
            &format!("/api/v1/pets/{pet_id}/media/background-image"),
            "red.png",
            "image/png",
            &STANDARD
                .decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC")
                .expect("red png bytes"),
            "ios",
            &user_id,
        ))
        .await
        .expect("upload valid background image");
    assert_eq!(upload_response.status(), StatusCode::CREATED);
    let body = response_json(upload_response).await;
    let derivatives = body["data"]["derivatives"].as_array().expect("derivatives");

    assert!(
        derivatives
            .iter()
            .any(|item| item["derivative_kind"] == "thumbnail")
    );
    let theme = derivatives
        .iter()
        .find(|item| item["derivative_kind"] == "theme_color_frame")
        .expect("theme color derivative");
    assert_eq!(theme["metadata"]["theme_color_hex"], "#FF0000");
    assert!(
        theme["object_key"]
            .as_str()
            .expect("theme object key")
            .contains("theme_color_frame")
    );
}

#[tokio::test]
async fn pet_background_video_upload_generates_cover_frame_and_theme_color() {
    let Some(video_content) = red_video_bytes() else {
        return;
    };
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138137").await;

    let create_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "火花",
                "species": "dog",
                "sex": "male"
            }),
            Some(&user_id),
        ))
        .await
        .expect("create pet");
    assert_eq!(create_response.status(), StatusCode::CREATED);
    let create_body = response_json(create_response).await;
    let pet_id = create_body["data"]["id"].as_str().expect("pet id");

    let upload_response = app
        .router()
        .oneshot(multipart_media_request(
            &format!("/api/v1/pets/{pet_id}/media/background-video"),
            "red.mp4",
            "video/mp4",
            &video_content,
            "ios",
            &user_id,
        ))
        .await
        .expect("upload valid background video");
    assert_eq!(upload_response.status(), StatusCode::CREATED);
    let body = response_json(upload_response).await;
    let derivatives = body["data"]["derivatives"].as_array().expect("derivatives");

    assert!(
        derivatives
            .iter()
            .any(|item| item["derivative_kind"] == "video_cover_frame")
    );
    let theme = derivatives
        .iter()
        .find(|item| item["derivative_kind"] == "theme_color_frame")
        .expect("theme color derivative");
    assert_eq!(theme["metadata"]["theme_color_hex"], "#FE0000");
}

#[tokio::test]
async fn replacing_avatar_queues_previous_media_for_cleanup() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138136").await;

    let create_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "芝麻",
                "species": "dog",
                "sex": "male"
            }),
            Some(&user_id),
        ))
        .await
        .expect("create pet");
    assert_eq!(create_response.status(), StatusCode::CREATED);
    let create_body = response_json(create_response).await;
    let pet_id = create_body["data"]["id"].as_str().expect("pet id");

    let first_response = app
        .router()
        .oneshot(multipart_media_request(
            &format!("/api/v1/pets/{pet_id}/media/avatar"),
            "avatar-1.txt",
            "text/plain",
            b"avatar-one",
            "ios",
            &user_id,
        ))
        .await
        .expect("upload first avatar");
    assert_eq!(first_response.status(), StatusCode::CREATED);
    let first_body = response_json(first_response).await;
    let old_asset_id = first_body["data"]["asset"]["id"]
        .as_str()
        .expect("asset id");

    let second_response = app
        .router()
        .oneshot(multipart_media_request(
            &format!("/api/v1/pets/{pet_id}/media/avatar"),
            "avatar-2.txt",
            "text/plain",
            b"avatar-two",
            "ios",
            &user_id,
        ))
        .await
        .expect("upload replacement avatar");
    assert_eq!(second_response.status(), StatusCode::CREATED);

    assert_media_cleanup_state(&app, old_asset_id, "cleanup_pending", "replaced", "queued").await;
}

#[tokio::test]
async fn pet_profile_delete_is_soft_and_recoverable() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138134").await;

    let create_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "豆包",
                "species": "cat",
                "sex": "unknown"
            }),
            Some(&user_id),
        ))
        .await
        .expect("create pet");
    assert_eq!(create_response.status(), StatusCode::CREATED);
    let create_body = response_json(create_response).await;
    let pet_id = create_body["data"]["id"].as_str().expect("pet id");

    let upload_response = app
        .router()
        .oneshot(multipart_media_request(
            &format!("/api/v1/pets/{pet_id}/media/avatar"),
            "restore-avatar.txt",
            "text/plain",
            b"avatar-before-delete",
            "ios",
            &user_id,
        ))
        .await
        .expect("upload avatar before delete");
    assert_eq!(upload_response.status(), StatusCode::CREATED);
    let upload_body = response_json(upload_response).await;
    let asset_id = upload_body["data"]["asset"]["id"]
        .as_str()
        .expect("asset id");

    let delete_response = app
        .router()
        .oneshot(json_request(
            "DELETE",
            &format!("/api/v1/pets/{pet_id}"),
            json!({
                "reason": "用户主动删除"
            }),
            Some(&user_id),
        ))
        .await
        .expect("delete pet");
    assert_eq!(delete_response.status(), StatusCode::OK);
    let delete_body = response_json(delete_response).await;
    assert_eq!(delete_body["code"], "pet.deleted");
    assert_eq!(delete_body["data"]["id"], pet_id);
    assert!(delete_body["data"]["deleted_at"].as_str().is_some());
    assert_eq!(delete_body["data"]["delete_requested_by_user_id"], user_id);
    assert!(delete_body["data"]["recoverable_until"].as_str().is_some());

    assert_media_cleanup_state(&app, asset_id, "cleanup_pending", "deleted", "queued").await;

    let timeline_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/pets/{pet_id}/timeline"),
            Some(&user_id),
        ))
        .await
        .expect("load deleted pet timeline");
    assert_eq!(timeline_response.status(), StatusCode::NOT_FOUND);

    let restore_response = app
        .router()
        .oneshot(empty_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/restore"),
            Some(&user_id),
        ))
        .await
        .expect("restore pet");
    assert_eq!(restore_response.status(), StatusCode::OK);
    let restore_body = response_json(restore_response).await;
    assert_eq!(restore_body["code"], "pet.restored");
    assert_eq!(restore_body["data"]["id"], pet_id);
    assert!(restore_body["data"]["deleted_at"].is_null());
    assert!(restore_body["data"]["delete_requested_by_user_id"].is_null());
    assert!(restore_body["data"]["recoverable_until"].is_null());

    assert_media_cleanup_state(&app, asset_id, "bound", "active", "none").await;

    let list_response = app
        .router()
        .oneshot(empty_request("GET", "/api/v1/pets", Some(&user_id)))
        .await
        .expect("list restored pets");
    assert_eq!(list_response.status(), StatusCode::OK);
    let list_body = response_json(list_response).await;
    assert_eq!(list_body["data"]["pets"][0]["id"], pet_id);
}
