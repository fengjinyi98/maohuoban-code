#![allow(clippy::needless_pass_by_value)]

use axum::body::{Body, to_bytes};
use axum::http::Request;
use serde_json::Value;

/// `json_request` 构造 JSON HTTP 请求
/// 核心职责：
/// - 固定测试请求的 Content-Type
/// - 将 JSON body 转为 axum Body
fn json_request(method: &str, uri: &str, body: Value) -> Request<Body> {
    Request::builder()
        .method(method)
        .uri(uri)
        .header("content-type", "application/json")
        .body(Body::from(body.to_string()))
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

#[path = "auth_contract/account_recovery.rs"]
mod account_recovery;
#[path = "auth_contract/oauth.rs"]
mod oauth;
#[path = "auth_contract/observability.rs"]
mod observability;
#[path = "auth_contract/phone.rs"]
mod phone;
#[path = "auth_contract/session.rs"]
mod session;
