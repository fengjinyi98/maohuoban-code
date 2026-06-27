#![allow(clippy::needless_pass_by_value)]

use axum::{
    Router,
    body::{Body, to_bytes},
    http::{Request, StatusCode},
    middleware,
    routing::get,
};
use maohuoban_diagnostics::{DiagnosticEvent, EventKind, EventStore, FileSegmentStore, Severity};
use serde_json::json;
use std::time::Duration;
use tower::ServiceExt;

fn temporary_directory() -> std::path::PathBuf {
    let root = std::env::temp_dir().join(format!(
        "maohuoban-rust-diagnostics-{}",
        uuid::Uuid::new_v4()
    ));
    std::fs::create_dir_all(&root).expect("create temp dir");
    root
}

fn json_request(method: &str, uri: &str, body: serde_json::Value) -> Request<Body> {
    Request::builder()
        .method(method)
        .uri(uri)
        .header("content-type", "application/json")
        .header("x-maohuoban-diagnostics-token", "local-token")
        .body(Body::from(body.to_string()))
        .expect("build request")
}

#[test]
fn backend_config_enables_local_diagnostics_ingest_by_default() {
    assert!(
        maohuoban_rust::BackendConfig::diagnostics_ingest_enabled_from_env_value(None),
        "local diagnostics ingest must be available for iOS device debug mirror"
    );
    assert!(maohuoban_rust::BackendConfig::diagnostics_ingest_enabled_from_env_value(Some("1")));
    assert!(maohuoban_rust::BackendConfig::diagnostics_ingest_enabled_from_env_value(Some("true")));
    assert!(!maohuoban_rust::BackendConfig::diagnostics_ingest_enabled_from_env_value(Some("0")));
    assert!(
        !maohuoban_rust::BackendConfig::diagnostics_ingest_enabled_from_env_value(Some("false"))
    );
}

#[test]
fn backend_diagnostics_cleanup_policy_uses_llm_friendly_local_defaults() {
    let policy = maohuoban_rust::diagnostics::cleanup_policy_from_env_values(None, None, None);

    assert_eq!(policy.max_total_bytes, 10 * 1024 * 1024);
    assert_eq!(policy.max_segment_age, Duration::from_hours(24));
    assert_eq!(policy.max_export_age, Duration::from_hours(6));
    assert_eq!(
        maohuoban_rust::diagnostics::cleanup_interval_from_env_value(None),
        Duration::from_mins(30)
    );
}

#[test]
fn backend_diagnostics_cleanup_policy_accepts_env_overrides() {
    let policy = maohuoban_rust::diagnostics::cleanup_policy_from_env_values(
        Some("1048576"),
        Some("2"),
        Some("1"),
    );

    assert_eq!(policy.max_total_bytes, 1024 * 1024);
    assert_eq!(policy.max_segment_age, Duration::from_hours(2));
    assert_eq!(policy.max_export_age, Duration::from_hours(1));
    assert_eq!(
        maohuoban_rust::diagnostics::cleanup_interval_from_env_value(Some("5")),
        Duration::from_mins(5)
    );
}

async fn response_json(response: axum::response::Response) -> serde_json::Value {
    let bytes = to_bytes(response.into_body(), 1024 * 1024)
        .await
        .expect("read body");
    serde_json::from_slice(&bytes).expect("parse body")
}

#[tokio::test]
async fn backend_debug_ingest_accepts_ios_batch_into_workspace_segments() {
    let root = temporary_directory();
    let segments = root.join(".maohuoban-diagnostics").join("segments");
    let router = maohuoban_rust::diagnostics::build_diagnostics_ingest_router(
        maohuoban_rust::diagnostics::DiagnosticsIngestConfig::local(
            segments.clone(),
            "local-token",
        ),
    )
    .expect("build diagnostics ingest router");

    let event = DiagnosticEvent::new(EventKind::Lifecycle, Severity::Info, "ios mirror event")
        .trace_id("trace-ios")
        .metadata("source", json!("ios-device-debug"));
    let response = router
        .oneshot(json_request(
            "POST",
            "/internal/diagnostics/ingest",
            json!([event]),
        ))
        .await
        .expect("ingest request");

    assert_eq!(response.status(), StatusCode::ACCEPTED);
    let body = response_json(response).await;
    assert_eq!(body["ok"], true);
    assert_eq!(body["accepted"], 1);
    assert_eq!(body["dropped"], 0);

    let store = FileSegmentStore::new(&segments, 1024 * 1024).expect("read store");
    let events = store.read_all().expect("read events");
    assert!(events.iter().any(|event| {
        event.message == "ios mirror event" && event.trace_id.as_deref() == Some("trace-ios")
    }));
}

#[tokio::test]
async fn http_middleware_propagates_trace_headers_and_records_request_metadata() {
    let root = temporary_directory();
    let segments = root.join("segments");
    let diagnostics = maohuoban_diagnostics::Diagnostics::bootstrap(
        maohuoban_diagnostics::DiagnosticsBootstrapConfig::new("maohuoban-rust", "test", segments),
    )
    .expect("bootstrap diagnostics");
    let incoming_traceparent = "00-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-bbbbbbbbbbbbbbbb-01";
    let app = Router::new()
        .route("/health", get(|| async { "ok" }))
        .layer(middleware::from_fn(
            maohuoban_rust::diagnostics::record_http_network,
        ));

    let response = app
        .oneshot(
            Request::builder()
                .method("GET")
                .uri("/health?probe=1")
                .header("traceparent", incoming_traceparent)
                .header("authorization", "Bearer local")
                .body(Body::empty())
                .expect("build request"),
        )
        .await
        .expect("middleware response");

    assert_eq!(response.status(), StatusCode::OK);
    assert_eq!(
        response
            .headers()
            .get("traceparent")
            .and_then(|value| value.to_str().ok()),
        Some(incoming_traceparent)
    );
    let request_id = response
        .headers()
        .get("x-request-id")
        .and_then(|value| value.to_str().ok())
        .expect("x-request-id")
        .to_owned();

    diagnostics.flush().expect("flush diagnostics");
    let events = diagnostics.read_events().expect("read events");
    let event = events
        .iter()
        .find(|event| {
            event.kind == EventKind::Network && event.message == "network request completed"
        })
        .expect("network event");
    assert_eq!(
        event.trace_id.as_deref(),
        Some("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
    );
    assert_eq!(event.metadata["traceparent"], incoming_traceparent);
    assert_eq!(event.metadata["request_id"], request_id);
    assert_eq!(event.metadata["query_count"], 1);
    assert_eq!(event.metadata["has_authorization"], true);
}
