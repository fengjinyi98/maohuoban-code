use maohuoban_diagnostics::{
    CleanupPolicy, DebugBundleExporter, DiagnosticEvent, Diagnostics, DiagnosticsConfig, EventKind,
    FileSegmentStore, LlmPromptExporter, PrivacyPolicy, Severity,
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
