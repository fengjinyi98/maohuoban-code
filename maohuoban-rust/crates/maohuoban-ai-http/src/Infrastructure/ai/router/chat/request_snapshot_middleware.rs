use axum::{
    body::{Body, to_bytes},
    http::Request,
    middleware::Next,
    response::Response,
};

use super::composition::request::ChatStreamRequest;

/// `snapshot_ai_chat_request` AI chat 请求快照中间件
/// 核心职责：
/// - 在业务 handler 前解析并缓存 ChatStreamRequest
/// - 为后续 auth middleware 和 diagnostics 提供稳定的请求体视图
pub async fn snapshot_ai_chat_request(
    request: Request<Body>,
    next: Next,
) -> Response {
    let (mut parts, body) = request.into_parts();
    let Ok(bytes) = to_bytes(body, 1024 * 1024).await else {
        return next.run(Request::from_parts(parts, Body::empty())).await;
    };
    if let Ok(chat_request) = serde_json::from_slice::<ChatStreamRequest>(&bytes) {
        parts.extensions.insert(chat_request);
    }
    next.run(Request::from_parts(parts, Body::from(bytes))).await
}
