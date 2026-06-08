use maohuoban_diagnostics::{
    CleanupPolicy, DebugBundleExporter, DiagnosticEvent, Diagnostics, DiagnosticsConfig, EventKind,
    FileSegmentStore, LlmPromptExporter, NetworkSummary, PrivacyPolicy, Severity,
};
use serde_json::json;
use std::{fs, time::Duration};
use tempfile::tempdir;

#[test]
fn records_events_with_privacy_filter_and_exports_debug_bundle() {
    let temp = tempdir().expect("temp dir");
    let store = FileSegmentStore::new(temp.path().join("segments"), 1024 * 1024).expect("store");
    let diagnostics = Diagnostics::install(DiagnosticsConfig {
        service_name: "maohuoban-rust".to_string(),
        environment: "test".to_string(),
        privacy: PrivacyPolicy::default()
            .redact_key("authorization")
            .redact_key("password"),
        cleanup: CleanupPolicy::default(),
        store: Box::new(store),
    })
    .expect("install diagnostics");

    diagnostics.record(
        DiagnosticEvent::new(EventKind::Network, Severity::Info, "request completed")
            .metadata("url", json!("https://example.com/login"))
            .metadata("authorization", json!("Bearer token"))
            .metadata("password", json!("secret")),
    );
    diagnostics.flush().expect("flush events");

    let bundle = DebugBundleExporter::new(temp.path().join("bundle"))
        .export(&diagnostics)
        .expect("export bundle");

    let timeline = fs::read_to_string(bundle.timeline_path).expect("timeline");
    assert!(timeline.contains("request completed"));
    assert!(timeline.contains("\"authorization\":\"<redacted>\""));
    assert!(timeline.contains("\"password\":\"<redacted>\""));
    assert!(!timeline.contains("Bearer token"));
    assert!(!timeline.contains("secret"));
}

#[test]
fn cleanup_removes_old_segments_and_keeps_recent_events() {
    let temp = tempdir().expect("temp dir");
    let store = FileSegmentStore::new(temp.path().join("segments"), 1024).expect("store");
    let diagnostics = Diagnostics::install(DiagnosticsConfig {
        service_name: "maohuoban-rust".to_string(),
        environment: "test".to_string(),
        privacy: PrivacyPolicy::default(),
        cleanup: CleanupPolicy {
            max_total_bytes: 1024 * 1024,
            max_segment_age: Duration::from_secs(0),
            max_export_age: Duration::from_secs(0),
        },
        store: Box::new(store),
    })
    .expect("install diagnostics");

    diagnostics.record(DiagnosticEvent::new(
        EventKind::Log,
        Severity::Info,
        "kept until cleanup",
    ));
    diagnostics.flush().expect("flush events");

    let removed = diagnostics.cleanup().expect("cleanup");
    assert!(removed.removed_segments >= 1);
    assert_eq!(diagnostics.read_events().expect("read events").len(), 0);
}

#[test]
fn cleanup_removes_expired_debug_bundles() {
    let temp = tempdir().expect("temp dir");
    let store = FileSegmentStore::new(temp.path().join("segments"), 1024).expect("store");
    let diagnostics = Diagnostics::install(DiagnosticsConfig {
        service_name: "maohuoban-rust".to_string(),
        environment: "test".to_string(),
        privacy: PrivacyPolicy::default(),
        cleanup: CleanupPolicy {
            max_total_bytes: 1024 * 1024,
            max_segment_age: Duration::from_secs(7 * 24 * 60 * 60),
            max_export_age: Duration::from_secs(0),
        },
        store: Box::new(store),
    })
    .expect("install diagnostics");

    diagnostics.record(DiagnosticEvent::new(
        EventKind::Error,
        Severity::Error,
        "export cleanup input",
    ));
    diagnostics.flush().expect("flush events");

    let bundle = DebugBundleExporter::new(temp.path().join("bundle"))
        .export(&diagnostics)
        .expect("export bundle");
    assert!(bundle.directory.exists());

    let removed = diagnostics.cleanup().expect("cleanup");
    assert_eq!(removed.removed_exports, 1);
    assert!(!bundle.directory.exists());
}

#[test]
fn prompt_exporter_summarizes_timeline_for_llm() {
    let temp = tempdir().expect("temp dir");
    let store = FileSegmentStore::new(temp.path().join("segments"), 1024 * 1024).expect("store");
    let diagnostics = Diagnostics::install(DiagnosticsConfig {
        service_name: "maohuoban-rust".to_string(),
        environment: "test".to_string(),
        privacy: PrivacyPolicy::default(),
        cleanup: CleanupPolicy::default(),
        store: Box::new(store),
    })
    .expect("install diagnostics");

    diagnostics.record(DiagnosticEvent::new(
        EventKind::Error,
        Severity::Error,
        "request timeout",
    ));
    diagnostics.flush().expect("flush events");

    let prompt = LlmPromptExporter::new("分析这个 bug")
        .export_prompt(&diagnostics)
        .expect("export prompt");
    assert!(prompt.contains("分析这个 bug"));
    assert!(prompt.contains("request timeout"));
    assert!(prompt.contains("maohuoban.diagnostics.prompt.v1"));
}

#[test]
fn install_makes_runtime_available_globally_and_records_convenience_events() {
    let temp = tempdir().expect("temp dir");
    let store = FileSegmentStore::new(temp.path().join("segments"), 1024 * 1024).expect("store");
    let diagnostics = Diagnostics::install(DiagnosticsConfig {
        service_name: "maohuoban-rust".to_string(),
        environment: "test".to_string(),
        privacy: PrivacyPolicy::default(),
        cleanup: CleanupPolicy::default(),
        store: Box::new(store),
    })
    .expect("install diagnostics");

    let current = Diagnostics::current().expect("current diagnostics");
    current.breadcrumb("screen opened", [("screen", json!("home"))]);
    current.error("api failed", [("status", json!(504))]);
    let span = current.begin_span("load home");
    span.end([("phase", json!("render"))]);
    current.flush().expect("flush events");

    let events = diagnostics.read_events().expect("events");
    assert!(
        events
            .iter()
            .any(|event| event.kind == EventKind::Breadcrumb)
    );
    assert!(events.iter().any(|event| event.kind == EventKind::Error));
    assert!(
        events
            .iter()
            .any(|event| event.kind == EventKind::Performance)
    );
}

#[test]
fn network_summary_api_records_success_and_failure_without_temp_logs() {
    let temp = tempdir().expect("temp dir");
    let store = FileSegmentStore::new(temp.path().join("segments"), 1024 * 1024).expect("store");
    let diagnostics = Diagnostics::install(DiagnosticsConfig {
        service_name: "maohuoban-rust".to_string(),
        environment: "test".to_string(),
        privacy: PrivacyPolicy::default(),
        cleanup: CleanupPolicy::default(),
        store: Box::new(store),
    })
    .expect("install diagnostics");

    diagnostics.network(
        NetworkSummary::new("GET", "https://api.example.com/feed")
            .status_code(200)
            .duration_ms(42)
            .metadata("feature", json!("feed")),
    );
    diagnostics.network(
        NetworkSummary::new("POST", "https://api.example.com/login")
            .duration_ms(1_200)
            .error("request timed out"),
    );
    diagnostics.flush().expect("flush events");

    let events = diagnostics.read_events().expect("events");
    assert!(events.iter().any(|event| {
        event.kind == EventKind::Network
            && event.severity == Severity::Info
            && event.metadata["status_code"] == json!(200)
            && event.metadata["feature"] == json!("feed")
    }));
    assert!(events.iter().any(|event| {
        event.kind == EventKind::Network
            && event.severity == Severity::Error
            && event.metadata["error"] == json!("request timed out")
            && event.metadata["duration_ms"] == json!(1_200)
    }));
}

#[test]
fn global_context_is_applied_to_events_without_temp_metadata_plumbing() {
    let temp = tempdir().expect("temp dir");
    let store = FileSegmentStore::new(temp.path().join("segments"), 1024 * 1024).expect("store");
    let diagnostics = Diagnostics::install(DiagnosticsConfig {
        service_name: "maohuoban-rust".to_string(),
        environment: "test".to_string(),
        privacy: PrivacyPolicy::default(),
        cleanup: CleanupPolicy::default(),
        store: Box::new(store),
    })
    .expect("install diagnostics");

    diagnostics.set_session_id("session-a");
    diagnostics.set_trace_id("trace-a");
    diagnostics.set_context_metadata("screen", json!("home"));
    diagnostics.log(Severity::Info, "context log");
    diagnostics.network(NetworkSummary::new("GET", "https://api.example.com/feed"));
    diagnostics.record(
        DiagnosticEvent::new(EventKind::Breadcrumb, Severity::Info, "explicit context")
            .trace_id("trace-event")
            .metadata("screen", json!("detail")),
    );
    let span = diagnostics.begin_span("context span");
    span.end(Vec::<(String, serde_json::Value)>::new());
    diagnostics.flush().expect("flush events");

    let events = diagnostics.read_events().expect("events");
    let log = events
        .iter()
        .find(|event| event.message == "context log")
        .expect("context log");
    assert_eq!(log.session_id.as_deref(), Some("session-a"));
    assert_eq!(log.trace_id.as_deref(), Some("trace-a"));
    assert_eq!(log.metadata["screen"], json!("home"));

    let network = events
        .iter()
        .find(|event| event.kind == EventKind::Network)
        .expect("network event");
    assert_eq!(network.session_id.as_deref(), Some("session-a"));
    assert_eq!(network.trace_id.as_deref(), Some("trace-a"));

    let explicit = events
        .iter()
        .find(|event| event.message == "explicit context")
        .expect("explicit context");
    assert_eq!(explicit.session_id.as_deref(), Some("session-a"));
    assert_eq!(explicit.trace_id.as_deref(), Some("trace-event"));
    assert_eq!(explicit.metadata["screen"], json!("detail"));

    diagnostics.clear_trace_id();
    diagnostics.log(Severity::Info, "trace cleared");
    diagnostics.flush().expect("flush cleared event");

    let events = diagnostics.read_events().expect("events after clear");
    let cleared = events
        .iter()
        .find(|event| event.message == "trace cleared")
        .expect("trace cleared event");
    assert_eq!(cleared.session_id.as_deref(), Some("session-a"));
    assert_eq!(cleared.trace_id, None);
}

#[test]
fn panic_hook_records_panic_as_fatal_error_event() {
    let temp = tempdir().expect("temp dir");
    let store = FileSegmentStore::new(temp.path().join("segments"), 1024 * 1024).expect("store");
    let diagnostics = Diagnostics::install(DiagnosticsConfig {
        service_name: "maohuoban-rust".to_string(),
        environment: "test".to_string(),
        privacy: PrivacyPolicy::default(),
        cleanup: CleanupPolicy::default(),
        store: Box::new(store),
    })
    .expect("install diagnostics");
    diagnostics.install_panic_hook();

    let _ = std::panic::catch_unwind(|| panic!("database unavailable"));
    diagnostics.flush().expect("flush events");

    let events = diagnostics.read_events().expect("events");
    assert!(events.iter().any(|event| {
        event.kind == EventKind::Error
            && event.severity == Severity::Fatal
            && event.message.contains("database unavailable")
    }));
}
