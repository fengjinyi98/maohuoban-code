#![allow(clippy::needless_pass_by_value)]

use axum::{
    body::{Body, to_bytes},
    http::{Request, StatusCode},
};
use base64::{Engine as _, engine::general_purpose::STANDARD};
use serde_json::{Value, json};
use tower::ServiceExt;

/// `multipart_media_request` 构造媒体上传 multipart 请求
/// 核心职责：
/// - 固定媒体上传测试的 multipart 协议
/// - 同时提交 `file` 和 `source_client` 字段
fn multipart_media_request(
    uri: &str,
    file_name: &str,
    mime_type: &str,
    content: &[u8],
    source_client: &str,
    user_id: &str,
) -> Request<Body> {
    let boundary = format!("maohuoban-home-test-{}", uuid::Uuid::new_v4());
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

/// `create_home_test_pet` 创建首页契约测试宠物
/// 核心职责：
/// - 复用标准宠物档案输入
/// - 返回后续事件和首页断言需要的宠物 ID
async fn create_home_test_pet(
    app: &maohuoban_rust::test_support::AuthTestApp,
    user_id: &str,
) -> String {
    create_named_home_test_pet(app, user_id, "糯米").await
}

/// `create_named_home_test_pet` 创建指定名称的测试宠物
/// 核心职责：
/// - 支持首页推荐契约区分当前宠物和伙伴宠物
/// - 复用标准宠物档案输入
async fn create_named_home_test_pet(
    app: &maohuoban_rust::test_support::AuthTestApp,
    user_id: &str,
    name: &str,
) -> String {
    let response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": name,
                "species": "dog",
                "breed": "比熊犬",
                "sex": "female",
                "birthday": "2024-04-01"
            }),
            Some(user_id),
        ))
        .await
        .expect("create pet");
    assert_eq!(response.status(), StatusCode::CREATED);
    let body = response_json(response).await;
    body["data"]["id"].as_str().expect("pet id").to_owned()
}

/// `append_home_test_event` 写入首页契约测试宠物事件
/// 核心职责：
/// - 固定事件写入请求路径
/// - 让首页派生测试聚焦响应契约
async fn append_home_test_event(
    app: &maohuoban_rust::test_support::AuthTestApp,
    user_id: &str,
    pet_id: &str,
    event: Value,
) {
    let response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/events"),
            event,
            Some(user_id),
        ))
        .await
        .expect("create pet event");
    assert_eq!(response.status(), StatusCode::CREATED);
}

/// `load_user_home_dashboard` 读取带用户上下文的首页快照
/// 核心职责：
/// - 固定首页读取请求
/// - 返回已解析 JSON 供契约断言
async fn load_user_home_dashboard(
    app: &maohuoban_rust::test_support::AuthTestApp,
    user_id: &str,
) -> Value {
    let response = app
        .router()
        .oneshot(contextual_empty_request(
            "GET",
            "/api/v1/home/dashboard",
            Some(user_id),
        ))
        .await
        .expect("load pet owner dashboard");
    assert_eq!(response.status(), StatusCode::OK);
    response_json(response).await
}

/// `load_user_home_dashboard_for_pet` 读取指定宠物上下文的首页快照
/// 核心职责：
/// - 固定多宠切换查询参数
/// - 验证首页聚合可按用户选择切换当前宠物
async fn load_user_home_dashboard_for_pet(
    app: &maohuoban_rust::test_support::AuthTestApp,
    user_id: &str,
    selected_pet_id: &str,
) -> Value {
    let response = app
        .router()
        .oneshot(contextual_empty_request(
            "GET",
            &format!("/api/v1/home/dashboard?selected_pet_id={selected_pet_id}"),
            Some(user_id),
        ))
        .await
        .expect("load selected pet dashboard");
    assert_eq!(response.status(), StatusCode::OK);
    response_json(response).await
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

    let pet_id = create_home_test_pet(&app, &user_id).await;
    append_home_test_event(
        &app,
        &user_id,
        &pet_id,
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
    )
    .await;

    let dashboard_body = load_user_home_dashboard(&app, &user_id).await;
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

#[tokio::test]
async fn home_dashboard_uses_selected_pet_id_for_multi_pet_switching() {
    let app = maohuoban_rust::test_support::spawn_home_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138227").await;
    let first_pet_id = create_named_home_test_pet(&app, &user_id, "糯米").await;
    let second_pet_id = create_named_home_test_pet(&app, &user_id, "奶油").await;
    append_home_test_event(
        &app,
        &user_id,
        &second_pet_id,
        json!({
            "event_kind": "daily",
            "event_subkind": "appetite",
            "title": "奶油早餐记录",
            "summary": "第二只宠物的首页时间线",
            "visibility": "private",
            "occurred_at": "2026-06-13T08:30:00Z",
            "event_payload": {
                "value_text": "正常"
            }
        }),
    )
    .await;

    let dashboard_body = load_user_home_dashboard_for_pet(&app, &user_id, &second_pet_id).await;

    assert_eq!(dashboard_body["data"]["selected_pet"]["id"], second_pet_id);
    assert_eq!(dashboard_body["data"]["selected_pet"]["name"], "奶油");
    assert_eq!(
        dashboard_body["data"]["pet_switcher"][0]["id"],
        first_pet_id
    );
    assert_eq!(
        dashboard_body["data"]["pet_switcher"][0]["is_selected"],
        false
    );
    assert_eq!(
        dashboard_body["data"]["pet_switcher"][1]["id"],
        second_pet_id
    );
    assert_eq!(
        dashboard_body["data"]["pet_switcher"][1]["is_selected"],
        true
    );
    assert_eq!(
        dashboard_body["data"]["recent_timeline"][0]["title"],
        "奶油早餐记录"
    );
}

#[tokio::test]
async fn home_dashboard_returns_uploaded_pet_media_urls() {
    let app = maohuoban_rust::test_support::spawn_home_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138231").await;
    let pet_id = create_named_home_test_pet(&app, &user_id, "花卷").await;

    let avatar_bytes = STANDARD
        .decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC")
        .expect("avatar png bytes");
    let avatar_response = app
        .router()
        .oneshot(multipart_media_request(
            &format!("/api/v1/pets/{pet_id}/media/avatar"),
            "avatar.png",
            "image/png",
            &avatar_bytes,
            "ios",
            &user_id,
        ))
        .await
        .expect("upload avatar");
    assert_eq!(avatar_response.status(), StatusCode::CREATED);
    let avatar_body = response_json(avatar_response).await;
    let avatar_asset_id = avatar_body["data"]["asset"]["id"]
        .as_str()
        .expect("avatar asset id");

    let background_bytes = STANDARD
        .decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC")
        .expect("background png bytes");
    let background_response = app
        .router()
        .oneshot(multipart_media_request(
            &format!("/api/v1/pets/{pet_id}/media/background-image"),
            "background.png",
            "image/png",
            &background_bytes,
            "ios",
            &user_id,
        ))
        .await
        .expect("upload background image");
    assert_eq!(background_response.status(), StatusCode::CREATED);
    let background_body = response_json(background_response).await;
    let background_asset_id = background_body["data"]["asset"]["id"]
        .as_str()
        .expect("background asset id");

    let dashboard_body = load_user_home_dashboard(&app, &user_id).await;
    let avatar_url = format!("/api/v1/media/assets/{avatar_asset_id}/content");
    let background_url = format!("/api/v1/media/assets/{background_asset_id}/content");

    assert_eq!(
        dashboard_body["data"]["selected_pet"]["avatar_url"],
        avatar_url
    );
    assert_eq!(dashboard_body["data"]["selected_pet"]["avatar_width"], 1);
    assert_eq!(dashboard_body["data"]["selected_pet"]["avatar_height"], 1);
    assert_eq!(
        dashboard_body["data"]["selected_pet"]["hero_image_url"],
        background_url
    );
    assert_eq!(
        dashboard_body["data"]["selected_pet"]["hero_image_width"],
        1
    );
    assert_eq!(
        dashboard_body["data"]["selected_pet"]["hero_image_height"],
        1
    );
    assert_eq!(
        dashboard_body["data"]["selected_pet"]["hero_theme_color_hex"],
        "#FF0000"
    );
    assert_eq!(
        dashboard_body["data"]["selected_pet"]["hero_content_color_scheme"],
        "dark"
    );
    assert_eq!(
        dashboard_body["data"]["pet_switcher"][0]["avatar_url"],
        avatar_url
    );
    assert_eq!(dashboard_body["data"]["pet_switcher"][0]["avatar_width"], 1);
    assert_eq!(
        dashboard_body["data"]["pet_switcher"][0]["avatar_height"],
        1
    );

    let media_response = app
        .router()
        .oneshot(empty_request("GET", &avatar_url))
        .await
        .expect("get media content");
    assert_eq!(media_response.status(), StatusCode::OK);
    assert_eq!(
        media_response
            .headers()
            .get("cache-control")
            .and_then(|value| value.to_str().ok()),
        Some("public, max-age=31536000, immutable")
    );
    let bytes = to_bytes(media_response.into_body(), 1024 * 1024)
        .await
        .expect("read media content");
    assert_eq!(&bytes[..], &avatar_bytes[..]);
}

#[tokio::test]
async fn home_dashboard_falls_back_when_selected_pet_belongs_to_another_user() {
    let app = maohuoban_rust::test_support::spawn_home_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138228").await;
    let own_pet_id = create_named_home_test_pet(&app, &user_id, "糯米").await;
    let other_user_id = login_user_id(&app, "13800138229").await;
    let other_pet_id = create_named_home_test_pet(&app, &other_user_id, "奶油").await;

    let dashboard_body = load_user_home_dashboard_for_pet(&app, &user_id, &other_pet_id).await;

    assert_eq!(dashboard_body["data"]["selected_pet"]["id"], own_pet_id);
    assert_eq!(dashboard_body["data"]["selected_pet"]["name"], "糯米");
    assert_eq!(dashboard_body["data"]["pet_switcher"][0]["id"], own_pet_id);
    assert_eq!(
        dashboard_body["data"]["pet_switcher"][0]["is_selected"],
        true
    );
}

#[tokio::test]
async fn home_dashboard_derives_care_summary_and_reminders_from_pet_events() {
    let app = maohuoban_rust::test_support::spawn_home_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138222").await;
    let pet_id = create_home_test_pet(&app, &user_id).await;

    for event in [
        json!({
            "event_kind": "daily",
            "event_subkind": "appetite",
            "title": "食欲记录",
            "summary": "早餐和晚餐都吃完了",
            "visibility": "private",
            "occurred_at": "2026-06-13T08:30:00Z",
            "event_payload": {
                "value_text": "旺盛",
                "status_text": "早餐和晚餐已记录"
            }
        }),
        json!({
            "event_kind": "health",
            "event_subkind": "weight",
            "title": "体重记录",
            "summary": "6.4kg，较上次增加",
            "visibility": "private",
            "occurred_at": "2026-06-13T09:20:00Z",
            "event_payload": {
                "weight_kg": 6.4
            }
        }),
        json!({
            "event_kind": "health",
            "event_subkind": "deworming",
            "title": "内外驱虫",
            "summary": "已完成本月驱虫",
            "visibility": "private",
            "occurred_at": "2026-06-13T10:30:00Z",
            "event_payload": {
                "next_due_at": "2026-07-01"
            }
        }),
    ] {
        append_home_test_event(&app, &user_id, &pet_id, event).await;
    }

    let dashboard_body = load_user_home_dashboard(&app, &user_id).await;

    assert_eq!(
        dashboard_body["data"]["care_summary"]["metrics"][0]["kind"],
        "appetite"
    );
    assert_eq!(
        dashboard_body["data"]["care_summary"]["metrics"][0]["value_text"],
        "旺盛"
    );
    assert_eq!(
        dashboard_body["data"]["care_summary"]["metrics"][0]["status_text"],
        "早餐和晚餐已记录"
    );
    assert_eq!(
        dashboard_body["data"]["care_summary"]["metrics"][3]["kind"],
        "weight"
    );
    assert_eq!(
        dashboard_body["data"]["care_summary"]["metrics"][3]["value_text"],
        "6.4kg"
    );
    assert_eq!(dashboard_body["data"]["reminders"][0]["kind"], "deworming");
    assert_eq!(dashboard_body["data"]["reminders"][0]["title"], "内外驱虫");
    assert_eq!(
        dashboard_body["data"]["reminders"][0]["subtitle"],
        "预计 2026-07-01 提醒"
    );
    assert_eq!(dashboard_body["data"]["reminders"][0]["due_text"], "待提醒");
    assert_eq!(
        dashboard_body["data"]["recent_timeline"][0]["event_kind"],
        "deworming"
    );
}

#[tokio::test]
async fn home_dashboard_uses_current_user_merchant_tracking_workspace() {
    let app = maohuoban_rust::test_support::spawn_home_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138221").await;
    let merchant_id = app.seed_merchant_tracking_workspace(&user_id).await;

    let dashboard_response = app
        .router()
        .oneshot(contextual_empty_request(
            "GET",
            "/api/v1/home/dashboard",
            Some(&user_id),
        ))
        .await
        .expect("load merchant tracking dashboard");
    assert_eq!(dashboard_response.status(), StatusCode::OK);
    let dashboard_body = response_json(dashboard_response).await;
    assert_eq!(
        dashboard_body["data"]["identity"]["kind"],
        "certified_merchant"
    );
    assert!(dashboard_body["data"]["selected_pet"].is_null());
    assert_eq!(
        dashboard_body["data"]["merchant_dashboard"]["merchant_id"],
        merchant_id
    );
    assert_eq!(
        dashboard_body["data"]["merchant_dashboard"]["merchant_name"],
        "梧桐猫舍"
    );
    assert_eq!(
        dashboard_body["data"]["merchant_dashboard"]["status_counts"][0]["status"],
        "available"
    );
    assert_eq!(
        dashboard_body["data"]["merchant_dashboard"]["status_counts"][0]["count"],
        2
    );
    assert_eq!(
        dashboard_body["data"]["merchant_dashboard"]["litters"][0]["name"],
        "2026 春季 A 窝"
    );
    assert_eq!(
        dashboard_body["data"]["merchant_dashboard"]["litters"][0]["parent_text"],
        "父亲 Leo · 母亲 Luna"
    );
    assert_eq!(
        dashboard_body["data"]["merchant_dashboard"]["litters"][0]["available_count"],
        2
    );
    assert_eq!(
        dashboard_body["data"]["merchant_dashboard"]["pending_tasks"][0]["kind"],
        "complete_health_record"
    );
    assert_eq!(
        dashboard_body["data"]["merchant_dashboard"]["recent_events"][0]["title"],
        "A 窝出生记录"
    );
    assert!(dashboard_body["data"]["empty_state"].is_null());
}

#[tokio::test]
async fn home_dashboard_recommends_same_litter_partner_from_pet_relationships() {
    let app = maohuoban_rust::test_support::spawn_home_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138223").await;
    let partner_user_id = login_user_id(&app, "13800138224").await;
    let pet_id = create_named_home_test_pet(&app, &user_id, "糯米").await;
    let partner_pet_id = create_named_home_test_pet(&app, &partner_user_id, "奶盖").await;

    app.seed_same_litter_relationship(&pet_id, &partner_pet_id)
        .await;

    let dashboard_body = load_user_home_dashboard(&app, &user_id).await;

    assert_eq!(
        dashboard_body["data"]["partner_recommendation"]["pet_id"],
        partner_pet_id
    );
    assert_eq!(
        dashboard_body["data"]["partner_recommendation"]["pet_name"],
        "奶盖"
    );
    assert_eq!(
        dashboard_body["data"]["partner_recommendation"]["relationship_kind"],
        "same_litter"
    );
    assert_eq!(
        dashboard_body["data"]["partner_recommendation"]["distance_text"],
        "同窝关系"
    );
    assert!(dashboard_body["data"]["empty_state"].is_null());
}

#[tokio::test]
async fn home_dashboard_uses_public_pet_events_for_new_user_recommended_content() {
    let app = maohuoban_rust::test_support::spawn_home_test_app().await;
    app.reset().await;
    let content_owner_id = login_user_id(&app, "13800138225").await;
    let pet_id = create_named_home_test_pet(&app, &content_owner_id, "小满").await;
    append_home_test_event(
        &app,
        &content_owner_id,
        &pet_id,
        json!({
            "event_kind": "daily",
            "event_subkind": "adaptation",
            "title": "到家第三天开始主动吃饭",
            "summary": "幼猫适应新家的公开记录",
            "visibility": "public",
            "occurred_at": "2026-06-13T12:00:00Z",
            "event_payload": {
                "value_text": "稳定"
            }
        }),
    )
    .await;
    let new_user_id = login_user_id(&app, "13800138226").await;

    let dashboard_body = load_user_home_dashboard(&app, &new_user_id).await;

    assert_eq!(dashboard_body["data"]["identity"]["kind"], "new_user");
    assert_eq!(
        dashboard_body["data"]["empty_state"]["kind"],
        "create_first_pet"
    );
    assert_eq!(
        dashboard_body["data"]["recommended_content"][0]["kind"],
        "ugc"
    );
    assert_eq!(
        dashboard_body["data"]["recommended_content"][0]["title"],
        "到家第三天开始主动吃饭"
    );
    let source_text = dashboard_body["data"]["recommended_content"][0]["source_text"]
        .as_str()
        .expect("source text");
    assert!(source_text.contains("小满"));
    assert!(source_text.contains("宠物世界"));
}
