// Profile 集成测试 — 模块入口
// 核心职责：
// - 聚合资料子模块
// - 提供共享测试辅助函数

use axum::{
    body::Body,
    http::{Request, StatusCode},
};
use base64::{Engine as _, engine::general_purpose::STANDARD};
use serde_json::{Value, json};
use tower::ServiceExt;

use super::{json_request, response_json};

#[path = "profile/login.rs"]
mod login;
#[path = "profile/media.rs"]
mod media;
#[path = "profile/read.rs"]
mod read;
#[path = "profile/update.rs"]
mod update;

/// `send_phone_code` 发送验证码并返回 `challenge_id`
/// 核心职责：
/// - 复用登录测试流程
async fn send_phone_code(
    app: &maohuoban_rust::test_support::AuthTestApp,
    phone: &str,
    device_id: &str,
) -> String {
    let response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/auth/phone/code",
            json!({
                "phone": phone,
                "agreement_accepted": true,
                "device": device_payload(device_id)
            }),
        ))
        .await
        .expect("send phone code");
    assert_eq!(response.status(), StatusCode::OK);

    let body = response_json(response).await;
    body["data"]["challenge_id"]
        .as_str()
        .expect("challenge_id")
        .to_owned()
}

/// `device_payload` 构造设备信息 JSON
fn device_payload(device_id: &str) -> Value {
    json!({
        "device_id": device_id,
        "device_name": "iPhone 17 Pro",
        "platform": "iOS",
        "app_version": "1.0"
    })
}

/// `authorized_get_request` 构造带 Bearer 认证的 GET 请求
fn authorized_get_request(uri: &str, access_token: &str) -> Request<Body> {
    Request::builder()
        .method("GET")
        .uri(uri)
        .header("authorization", format!("Bearer {access_token}"))
        .body(Body::empty())
        .expect("build authorized get request")
}

/// `authorized_json_request` 构造带 Bearer 认证的 JSON 请求
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

/// `authorized_multipart_image_request` 构造带 Bearer 认证的 multipart 图片上传请求
fn authorized_multipart_image_request(
    uri: &str,
    access_token: &str,
    file_name: &str,
    mime_type: &str,
    content: &[u8],
) -> Request<Body> {
    let boundary = format!("maohuoban-profile-test-{}", uuid::Uuid::new_v4());
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
        b"Content-Disposition: form-data; name=\"source_client\"\r\n\r\nios\r\n",
    );
    body.extend_from_slice(format!("--{boundary}--\r\n").as_bytes());

    Request::builder()
        .method("POST")
        .uri(uri)
        .header("authorization", format!("Bearer {access_token}"))
        .header(
            "content-type",
            format!("multipart/form-data; boundary={boundary}"),
        )
        .body(Body::from(body))
        .expect("build authorized multipart image request")
}

/// `assert_profile_edit_policy` 断言编辑策略字段
fn assert_profile_edit_policy(
    policy: &Value,
    max_count: i64,
    used_count: i64,
    remaining_count: i64,
) {
    assert_eq!(policy["max_count"], max_count);
    assert_eq!(policy["used_count"], used_count);
    assert_eq!(policy["remaining_count"], remaining_count);
    assert_eq!(policy["window_days"], 30);
    assert!(policy["display_text"].as_str().is_some());
}

/// `assert_profile_media` 断言媒体资源字段
fn assert_profile_media(media: &Value, mime_type: &str, width: i64, height: i64) {
    assert!(media["asset_id"].as_str().is_some());
    assert!(
        media["url"]
            .as_str()
            .expect("profile media url")
            .starts_with("/api/v1/media/assets/")
    );
    assert_eq!(media["mime_type"], mime_type);
    assert_eq!(media["width"], width);
    assert_eq!(media["height"], height);
    assert!(media["updated_at"].as_str().is_some());
}

/// `tiny_png` 返回 1x1 像素 PNG 字节
fn tiny_png() -> Vec<u8> {
    STANDARD
        .decode(
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC",
        )
        .expect("decode tiny png")
}
