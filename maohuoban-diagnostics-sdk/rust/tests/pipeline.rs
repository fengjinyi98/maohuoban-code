use maohuoban_diagnostics::{
    CapturePolicy, CleanupPolicy, DebugBundleExporter, DiagnosticEvent, Diagnostics,
    DiagnosticsBootstrapConfig, DiagnosticsConfig, EventKind, FileSegmentStore, LlmPromptExporter,
    NetworkSummary, PrivacyPolicy, Severity,
};
use serde_json::json;
use std::{
    fs,
    sync::{Mutex, MutexGuard},
    time::Duration,
};
use tempfile::tempdir;

static DIAGNOSTICS_TEST_LOCK: Mutex<()> = Mutex::new(());

/// `diagnostics_test_lock` 隔离全局诊断运行时测试
/// 核心职责：
/// - 避免并行 integration tests 互相覆盖 `Diagnostics::current()`
/// - 保持每个测试的文件存储和全局 runtime 生命周期一致
fn diagnostics_test_lock() -> MutexGuard<'static, ()> {
    DIAGNOSTICS_TEST_LOCK.lock().expect("diagnostics test lock")
}

#[test]
fn records_events_with_privacy_filter_and_exports_debug_bundle() {
    let _guard = diagnostics_test_lock();
    let temp = tempdir().expect("temp dir");
    let store = FileSegmentStore::new(temp.path().join("segments"), 1024 * 1024).expect("store");
    let diagnostics = Diagnostics::install(DiagnosticsConfig {
        service_name: "maohuoban-rust".to_string(),
        environment: "test".to_string(),
        privacy: PrivacyPolicy::default()
            .redact_key("authorization")
            .redact_key("password"),
        capture: CapturePolicy::default(),
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
fn debug_bundle_includes_checksums_and_archive() {
    let _guard = diagnostics_test_lock();
    let temp = tempdir().expect("temp dir");
    let store = FileSegmentStore::new(temp.path().join("segments"), 1024 * 1024).expect("store");
    let diagnostics = Diagnostics::install(DiagnosticsConfig {
        service_name: "maohuoban-rust".to_string(),
        environment: "test".to_string(),
        privacy: PrivacyPolicy::default(),
        capture: CapturePolicy::default(),
        cleanup: CleanupPolicy::default(),
        store: Box::new(store),
    })
    .expect("install diagnostics");

    diagnostics.error("archive input", Vec::<(String, serde_json::Value)>::new());
    diagnostics.flush().expect("flush events");

    let bundle = DebugBundleExporter::new(temp.path().join("bundle"))
        .export(&diagnostics)
        .expect("export bundle");
    let manifest = fs::read_to_string(&bundle.manifest_path).expect("manifest");
    assert!(manifest.contains("\"timeline_sha256\""));
    assert!(manifest.contains("\"prompt_sha256\""));
    assert!(manifest.contains("\"archive_path\""));
    assert!(bundle.archive_path.exists());

    let archive = fs::read(&bundle.archive_path).expect("archive");
    let archive_text = String::from_utf8_lossy(&archive);
    assert!(archive_text.contains("timeline.jsonl"));
    assert!(archive_text.contains("prompt.md"));
}

#[test]
fn capture_policy_filters_low_severity_and_truncates_oversized_fields() {
    let _guard = diagnostics_test_lock();
    let temp = tempdir().expect("temp dir");
    let store = FileSegmentStore::new(temp.path().join("segments"), 1024 * 1024).expect("store");
    let diagnostics = Diagnostics::install(DiagnosticsConfig {
        service_name: "maohuoban-rust".to_string(),
        environment: "test".to_string(),
        privacy: PrivacyPolicy::default(),
        capture: CapturePolicy {
            minimum_severity: Severity::Warn,
            max_message_length: 8,
            max_metadata_value_length: 6,
        },
        cleanup: CleanupPolicy::default(),
        store: Box::new(store),
    })
    .expect("install diagnostics");

    diagnostics.log(Severity::Info, "filtered");
    diagnostics.record(
        DiagnosticEvent::new(
            EventKind::Error,
            Severity::Error,
            "checkout request timeout",
        )
        .metadata("detail", json!("database unavailable")),
    );
    diagnostics.flush().expect("flush events");

    let events = diagnostics.read_events().expect("events");
    assert_eq!(events.len(), 1);
    let event = events.first().expect("event");
    assert_eq!(event.message, "checkout...");
    assert_eq!(event.metadata["detail"], json!("databa..."));
    assert_eq!(event.metadata["service"], json!("maohuo..."));
    assert_eq!(event.metadata["environment"], json!("test"));
}

#[test]
fn cleanup_removes_old_segments_and_keeps_recent_events() {
    let _guard = diagnostics_test_lock();
    let temp = tempdir().expect("temp dir");
    let store = FileSegmentStore::new(temp.path().join("segments"), 1024).expect("store");
    let diagnostics = Diagnostics::install(DiagnosticsConfig {
        service_name: "maohuoban-rust".to_string(),
        environment: "test".to_string(),
        privacy: PrivacyPolicy::default(),
        capture: CapturePolicy::default(),
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
    let _guard = diagnostics_test_lock();
    let temp = tempdir().expect("temp dir");
    let store = FileSegmentStore::new(temp.path().join("segments"), 1024).expect("store");
    let diagnostics = Diagnostics::install(DiagnosticsConfig {
        service_name: "maohuoban-rust".to_string(),
        environment: "test".to_string(),
        privacy: PrivacyPolicy::default(),
        capture: CapturePolicy::default(),
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
    let _guard = diagnostics_test_lock();
    let temp = tempdir().expect("temp dir");
    let store = FileSegmentStore::new(temp.path().join("segments"), 1024 * 1024).expect("store");
    let diagnostics = Diagnostics::install(DiagnosticsConfig {
        service_name: "maohuoban-rust".to_string(),
        environment: "test".to_string(),
        privacy: PrivacyPolicy::default(),
        capture: CapturePolicy::default(),
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
    let _guard = diagnostics_test_lock();
    let temp = tempdir().expect("temp dir");
    let store = FileSegmentStore::new(temp.path().join("segments"), 1024 * 1024).expect("store");
    let diagnostics = Diagnostics::install(DiagnosticsConfig {
        service_name: "maohuoban-rust".to_string(),
        environment: "test".to_string(),
        privacy: PrivacyPolicy::default(),
        capture: CapturePolicy::default(),
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
    let _guard = diagnostics_test_lock();
    let temp = tempdir().expect("temp dir");
    let store = FileSegmentStore::new(temp.path().join("segments"), 1024 * 1024).expect("store");
    let diagnostics = Diagnostics::install(DiagnosticsConfig {
        service_name: "maohuoban-rust".to_string(),
        environment: "test".to_string(),
        privacy: PrivacyPolicy::default(),
        capture: CapturePolicy::default(),
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
    let _guard = diagnostics_test_lock();
    let temp = tempdir().expect("temp dir");
    let store = FileSegmentStore::new(temp.path().join("segments"), 1024 * 1024).expect("store");
    let diagnostics = Diagnostics::install(DiagnosticsConfig {
        service_name: "maohuoban-rust".to_string(),
        environment: "test".to_string(),
        privacy: PrivacyPolicy::default(),
        capture: CapturePolicy::default(),
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
fn captures_error_source_chain_as_structured_metadata() {
    let _guard = diagnostics_test_lock();
    let temp = tempdir().expect("temp dir");
    let store = FileSegmentStore::new(temp.path().join("segments"), 1024 * 1024).expect("store");
    let diagnostics = Diagnostics::install(DiagnosticsConfig {
        service_name: "maohuoban-rust".to_string(),
        environment: "test".to_string(),
        privacy: PrivacyPolicy::default(),
        capture: CapturePolicy::default(),
        cleanup: CleanupPolicy::default(),
        store: Box::new(store),
    })
    .expect("install diagnostics");

    let error = CheckoutError {
        source: DatabaseError,
    };
    diagnostics.capture_error(&error, [("feature", json!("checkout"))]);
    diagnostics.flush().expect("flush events");

    let events = diagnostics.read_events().expect("events");
    let event = events
        .iter()
        .find(|event| event.kind == EventKind::Error && event.message == "checkout failed")
        .expect("captured error");
    assert_eq!(event.severity, Severity::Error);
    assert_eq!(event.metadata["feature"], json!("checkout"));
    assert_eq!(event.metadata["error"], json!("checkout failed"));
    assert!(
        event.metadata["error_type"]
            .as_str()
            .expect("error type")
            .contains("CheckoutError")
    );
    assert_eq!(
        event.metadata["error_chain"],
        json!(["checkout failed", "database unavailable"])
    );
}

#[test]
fn captures_runtime_snapshot_as_performance_event() {
    let _guard = diagnostics_test_lock();
    let temp = tempdir().expect("temp dir");
    let store = FileSegmentStore::new(temp.path().join("segments"), 1024 * 1024).expect("store");
    let diagnostics = Diagnostics::install(DiagnosticsConfig {
        service_name: "maohuoban-rust".to_string(),
        environment: "test".to_string(),
        privacy: PrivacyPolicy::default(),
        capture: CapturePolicy::default(),
        cleanup: CleanupPolicy::default(),
        store: Box::new(store),
    })
    .expect("install diagnostics");

    diagnostics.capture_runtime_snapshot([("phase", json!("startup"))]);
    diagnostics.flush().expect("flush events");

    let events = diagnostics.read_events().expect("events");
    let event = events
        .iter()
        .find(|event| event.kind == EventKind::Performance && event.message == "runtime snapshot")
        .expect("runtime snapshot");
    assert_eq!(event.metadata["phase"], json!("startup"));
    assert_eq!(event.metadata["process_id"], json!(std::process::id()));
    assert!(event.metadata["process_name"].is_string());
    assert_eq!(event.metadata["os"], json!(std::env::consts::OS));
    assert_eq!(event.metadata["arch"], json!(std::env::consts::ARCH));
    assert!(event.metadata["uptime_ms"].as_u64().is_some());
}

#[test]
fn scoped_trace_restores_previous_trace_after_operation() {
    let _guard = diagnostics_test_lock();
    let temp = tempdir().expect("temp dir");
    let store = FileSegmentStore::new(temp.path().join("segments"), 1024 * 1024).expect("store");
    let diagnostics = Diagnostics::install(DiagnosticsConfig {
        service_name: "maohuoban-rust".to_string(),
        environment: "test".to_string(),
        privacy: PrivacyPolicy::default(),
        capture: CapturePolicy::default(),
        cleanup: CleanupPolicy::default(),
        store: Box::new(store),
    })
    .expect("install diagnostics");

    diagnostics.set_trace_id("outer");
    let result: Result<(), &str> = diagnostics.with_trace_id("inner", || {
        diagnostics.log(Severity::Info, "inside trace");
        Err("operation failed")
    });
    assert_eq!(result, Err("operation failed"));
    diagnostics.log(Severity::Info, "after trace");
    diagnostics.flush().expect("flush events");

    let events = diagnostics.read_events().expect("events");
    let inside = events
        .iter()
        .find(|event| event.message == "inside trace")
        .expect("inside trace");
    let after = events
        .iter()
        .find(|event| event.message == "after trace")
        .expect("after trace");
    assert_eq!(inside.trace_id.as_deref(), Some("inner"));
    assert_eq!(after.trace_id.as_deref(), Some("outer"));
}

#[test]
fn bootstrap_installs_global_runtime_and_captures_startup_context() {
    let _guard = diagnostics_test_lock();
    let temp = tempdir().expect("temp dir");
    let diagnostics = Diagnostics::bootstrap(DiagnosticsBootstrapConfig {
        service_name: "maohuoban-rust".to_string(),
        environment: "test".to_string(),
        storage_directory: temp.path().join("segments"),
        max_segment_bytes: 1024 * 1024,
        privacy: PrivacyPolicy::default(),
        capture: CapturePolicy::default(),
        cleanup: CleanupPolicy::default(),
        defaults: [
            ("app_version".to_string(), json!("1.2.3")),
            ("node".to_string(), json!("worker-a")),
        ]
        .into_iter()
        .collect(),
        session_id: Some("session-bootstrap".to_string()),
        trace_id: Some("launch-trace".to_string()),
        capture_runtime_snapshot: true,
        cleanup_on_bootstrap: true,
        install_panic_hook: false,
    })
    .expect("bootstrap diagnostics");

    diagnostics.log(Severity::Info, "after bootstrap");
    diagnostics.flush().expect("flush events");

    let events = diagnostics.read_events().expect("events");
    let launch = events
        .iter()
        .find(|event| {
            event.kind == EventKind::Lifecycle && event.message == "diagnostics bootstrap completed"
        })
        .expect("bootstrap lifecycle");
    assert_eq!(launch.session_id.as_deref(), Some("session-bootstrap"));
    assert_eq!(launch.trace_id.as_deref(), Some("launch-trace"));
    assert_eq!(launch.metadata["app_version"], json!("1.2.3"));
    assert_eq!(launch.metadata["node"], json!("worker-a"));

    let runtime = events
        .iter()
        .find(|event| event.kind == EventKind::Performance && event.message == "runtime snapshot")
        .expect("runtime snapshot");
    assert_eq!(runtime.metadata["phase"], json!("bootstrap"));
    assert_eq!(runtime.metadata["app_version"], json!("1.2.3"));

    let after = events
        .iter()
        .find(|event| event.message == "after bootstrap")
        .expect("after bootstrap");
    assert_eq!(after.session_id.as_deref(), Some("session-bootstrap"));
    assert_eq!(after.metadata["node"], json!("worker-a"));
}

#[test]
fn panic_hook_records_panic_as_fatal_error_event() {
    let _guard = diagnostics_test_lock();
    let temp = tempdir().expect("temp dir");
    let store = FileSegmentStore::new(temp.path().join("segments"), 1024 * 1024).expect("store");
    let diagnostics = Diagnostics::install(DiagnosticsConfig {
        service_name: "maohuoban-rust".to_string(),
        environment: "test".to_string(),
        privacy: PrivacyPolicy::default(),
        capture: CapturePolicy::default(),
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

#[derive(Debug, thiserror::Error)]
#[error("database unavailable")]
struct DatabaseError;

#[derive(Debug, thiserror::Error)]
#[error("checkout failed")]
struct CheckoutError {
    #[source]
    source: DatabaseError,
}
