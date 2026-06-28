#![allow(clippy::needless_pass_by_value)]

use axum::body::{Body, to_bytes};
use axum::http::Request;
use serde_json::Value;
use tower::ServiceExt;

/// `json_request` 构造 JSON HTTP 请求
fn json_request(method: &str, uri: &str, body: Value) -> Request<Body> {
    Request::builder()
        .method(method)
        .uri(uri)
        .header("content-type", "application/json")
        .body(Body::from(body.to_string()))
        .expect("build test request")
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

/// `authorized_multipart_media_request` 构造带 Bearer 认证的媒体上传请求
/// 核心职责：
/// - 固定 AI 契约测试中的 multipart 上传协议
/// - 同时提交 `file`、`source_client` 和访问令牌
fn authorized_multipart_media_request(
    uri: &str,
    file_name: &str,
    mime_type: &str,
    content: &[u8],
    source_client: &str,
    access_token: &str,
) -> Request<Body> {
    let boundary = format!("maohuoban-ai-test-{}", uuid::Uuid::new_v4());
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
        .header("authorization", format!("Bearer {access_token}"))
        .body(Body::from(body))
        .expect("build authorized multipart media request")
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

/// `authorized_delete_request` 构造带 Bearer 认证的 DELETE 请求
/// 核心职责：
/// - 固定无 JSON body 的删除类契约测试请求
/// - 保持认证头注入方式与 GET/JSON 请求一致
fn authorized_delete_request(uri: &str, access_token: &str) -> Request<Body> {
    Request::builder()
        .method("DELETE")
        .uri(uri)
        .header("authorization", format!("Bearer {access_token}"))
        .body(Body::empty())
        .expect("build authorized delete request")
}

/// `response_json` 读取 JSON 响应
async fn response_json(response: axum::response::Response) -> Value {
    let bytes = to_bytes(response.into_body(), 1024 * 1024)
        .await
        .expect("read response body");
    serde_json::from_slice(&bytes).expect("parse response json")
}

/// `response_text` 读取纯文本响应（SSE）
async fn response_text(response: axum::response::Response) -> String {
    let bytes = to_bytes(response.into_body(), 1024 * 1024)
        .await
        .expect("read response body");
    String::from_utf8(bytes.to_vec()).expect("parse response text")
}

/// `device_payload` 构造设备信息 JSON
fn device_payload(device_id: &str) -> Value {
    serde_json::json!({
        "device_id": device_id,
        "device_name": "iPhone 17 Pro",
        "platform": "iOS",
        "app_version": "1.0"
    })
}

/// `send_phone_code` 发送验证码并返回 `challenge_id`
async fn send_phone_code(
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
            serde_json::json!({
                "phone": phone,
                "agreement_accepted": true,
                "device": device_payload(device_id)
            }),
        ))
        .await
        .expect("send phone code");
    assert_eq!(response.status(), axum::http::StatusCode::OK);
    let body = response_json(response).await;
    body["data"]["challenge_id"]
        .as_str()
        .expect("challenge_id")
        .to_owned()
}

/// `login_and_get_token` 完成手机验证码登录并返回 `access_token`
async fn login_and_get_token(
    app: &maohuoban_rust::test_support::AuthTestApp,
    phone: &str,
    device_id: &str,
) -> String {
    let challenge_id = send_phone_code(app, phone, device_id).await;
    let response = app
        .router()
        .clone()
        .oneshot(json_request(
            "POST",
            "/api/v1/auth/phone/verify",
            serde_json::json!({
                "challenge_id": challenge_id,
                "code": "123456",
                "device": device_payload(device_id)
            }),
        ))
        .await
        .expect("verify phone code");
    assert_eq!(response.status(), axum::http::StatusCode::OK);
    let body = response_json(response).await;
    body["data"]["access_token"]
        .as_str()
        .expect("access token")
        .to_owned()
}

#[path = "ai_contract/chat_stream.rs"]
mod chat_stream;

#[path = "ai_contract/chat_non_stream.rs"]
mod chat_non_stream;

#[path = "ai_contract/chat_stream_diet_context.rs"]
mod chat_stream_diet_context;

#[path = "ai_contract/chat_stream_inventory_hints.rs"]
mod chat_stream_inventory_hints;

#[path = "ai_contract/chat_stream_confirmation_candidates.rs"]
mod chat_stream_confirmation_candidates;

#[path = "ai_contract/persistence.rs"]
mod persistence;

#[path = "ai_contract/replay.rs"]
mod replay;

#[path = "ai_contract/history.rs"]
mod history;
