use std::time::Instant;

use axum::{
    extract::{MatchedPath, Request},
    http::{HeaderMap, HeaderValue},
    middleware::Next,
    response::Response,
};
use maohuoban_diagnostics::{Diagnostics, NetworkSummary, TraceContext};
use serde_json::json;

/// record_http_network 记录后端 HTTP 网络摘要
/// 核心职责：
/// - 在 axum 入口统一捕获请求方法、路径、状态码和耗时
/// - 保留授权上下文是否存在，避免记录 token 和查询参数明文
pub async fn record_http_network(request: Request, next: Next) -> Response {
    let method = request.method().as_str().to_owned();
    let path = request.uri().path().to_owned();
    let path_template = request.extensions().get::<MatchedPath>().map_or_else(
        || path.clone(),
        |matched_path| matched_path.as_str().to_owned(),
    );
    let query_count = request.uri().query().map_or(0, |query| {
        query.split('&').filter(|item| !item.is_empty()).count()
    });
    let has_authorization = has_authorization_header(request.headers());
    let trace_context = request
        .headers()
        .get("traceparent")
        .and_then(|value| value.to_str().ok())
        .and_then(TraceContext::parse_traceparent)
        .unwrap_or_else(|| TraceContext::generate(true));
    let traceparent = trace_context.traceparent();
    let request_id = request
        .headers()
        .get("x-request-id")
        .and_then(|value| value.to_str().ok())
        .map_or_else(|| uuid::Uuid::new_v4().to_string(), ToOwned::to_owned);
    let started_at = Instant::now();
    let mut response = next.run(request).await;
    let status = response.status().as_u16();
    insert_response_header(response.headers_mut(), "traceparent", &traceparent);
    insert_response_header(response.headers_mut(), "x-request-id", &request_id);
    if let Some(diagnostics) = Diagnostics::current() {
        let mut summary = NetworkSummary::new(method, path)
            .status_code(status)
            .duration_ms(started_at.elapsed().as_millis())
            .trace_context(trace_context)
            .metadata("path_template", json!(path_template))
            .metadata("request_id", json!(request_id))
            .metadata("query_count", json!(query_count))
            .metadata("has_authorization", json!(has_authorization));
        if status >= 500 {
            summary = summary.metadata("response_error_kind", json!("server"));
        } else if status >= 400 {
            summary = summary.metadata("response_error_kind", json!("client"));
        }
        diagnostics.network(summary);
    }
    response
}

fn insert_response_header(headers: &mut HeaderMap, name: &'static str, value: &str) {
    if let Ok(value) = HeaderValue::from_str(value) {
        headers.insert(name, value);
    }
}

fn has_authorization_header(headers: &HeaderMap) -> bool {
    headers
        .get("authorization")
        .and_then(|value| value.to_str().ok())
        .is_some_and(|value| value.starts_with("Bearer ") && value.len() > "Bearer ".len())
}
