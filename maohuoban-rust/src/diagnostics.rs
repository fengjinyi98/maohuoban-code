use std::time::Instant;

use axum::{extract::Request, http::HeaderMap, middleware::Next, response::Response};
use maohuoban_diagnostics::{Diagnostics, NetworkSummary};
use serde_json::json;

/// record_http_network 记录后端 HTTP 网络摘要
/// 核心职责：
/// - 在 axum 入口统一捕获请求方法、路径、状态码和耗时
/// - 保留授权上下文是否存在，避免记录 token 和查询参数明文
pub async fn record_http_network(request: Request, next: Next) -> Response {
    let method = request.method().as_str().to_owned();
    let path = request.uri().path().to_owned();
    let query_count = request.uri().query().map_or(0, |query| {
        query.split('&').filter(|item| !item.is_empty()).count()
    });
    let has_authorization = has_authorization_header(request.headers());
    let started_at = Instant::now();
    let response = next.run(request).await;
    let status = response.status().as_u16();
    if let Some(diagnostics) = Diagnostics::current() {
        diagnostics.network(
            NetworkSummary::new(method, path)
                .status_code(status)
                .duration_ms(started_at.elapsed().as_millis())
                .metadata("query_count", json!(query_count))
                .metadata("has_authorization", json!(has_authorization)),
        );
    }
    response
}

fn has_authorization_header(headers: &HeaderMap) -> bool {
    headers
        .get("authorization")
        .and_then(|value| value.to_str().ok())
        .is_some_and(|value| value.starts_with("Bearer ") && value.len() > "Bearer ".len())
}
