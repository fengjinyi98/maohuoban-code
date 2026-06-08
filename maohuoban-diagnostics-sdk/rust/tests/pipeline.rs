use maohuoban_diagnostics::{
    CapturePolicy, CleanupPolicy, CleanupReport, DebugBundleExporter, DiagnosticEvent, Diagnostics,
    DiagnosticsBootstrapConfig, DiagnosticsConfig, DiagnosticsError, EventKind, EventStore,
    FileSegmentStore, LlmPromptExporter, NetworkSummary, PrivacyPolicy, Severity,
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

/// `tar_entries` 解析测试用无压缩 tar 条目
/// 核心职责：
/// - 验证 Debug Bundle 归档可以按 tar 格式读取
/// - 对比归档内文件内容和导出目录原文件
fn tar_entries(archive: &[u8]) -> Vec<(String, Vec<u8>)> {
    let mut entries = Vec::new();
    let mut offset = 0;
    while offset + 512 <= archive.len() {
        let header = &archive[offset..offset + 512];
        if header.iter().all(|byte| *byte == 0) {
            break;
        }
        let name_end = header[0..100]
            .iter()
            .position(|byte| *byte == 0)
            .unwrap_or(100);
        let name = String::from_utf8(header[0..name_end].to_vec()).expect("tar name");
        let size_bytes = header[124..136]
            .iter()
            .copied()
            .filter(|byte| *byte != 0 && *byte != b' ')
            .collect::<Vec<_>>();
        let size_text = String::from_utf8(size_bytes).expect("tar size");
        let size = usize::from_str_radix(size_text.trim(), 8).expect("tar octal size");
        let data_start = offset + 512;
        let data_end = data_start + size;
        assert!(data_end <= archive.len(), "tar entry exceeds archive size");
        entries.push((name, archive[data_start..data_end].to_vec()));
        offset = data_start + size.div_ceil(512) * 512;
    }
    entries
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
    let entries = tar_entries(&archive);
    assert_eq!(
        entries
            .iter()
            .find(|(name, _)| name == "manifest.json")
            .map(|(_, data)| data.as_slice()),
        Some(
            fs::read(&bundle.manifest_path)
                .expect("manifest data")
                .as_slice()
        )
    );
    assert_eq!(
        entries
            .iter()
            .find(|(name, _)| name == "timeline.jsonl")
            .map(|(_, data)| data.as_slice()),
        Some(
            fs::read(&bundle.timeline_path)
                .expect("timeline data")
                .as_slice()
        )
    );
    assert_eq!(
        entries
            .iter()
            .find(|(name, _)| name == "prompt.md")
            .map(|(_, data)| data.as_slice()),
        Some(
            fs::read(bundle.directory.join("prompt.md"))
                .expect("prompt data")
                .as_slice()
        )
    );
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
fn read_events_skips_corrupted_segment_lines_and_reports_warning() {
    let _guard = diagnostics_test_lock();
    let temp = tempdir().expect("temp dir");
    let storage = temp.path().join("segments");
    let store = FileSegmentStore::new(&storage, 1024 * 1024).expect("store");
    let valid_event =
        DiagnosticEvent::new(EventKind::Log, Severity::Info, "valid after corrupt line");
    let valid_json = serde_json::to_string(&valid_event).expect("valid json");
    fs::write(
        storage.join("corrupted.jsonl"),
        format!("not json\n{valid_json}\n"),
    )
    .expect("corrupted segment");
    let diagnostics = Diagnostics::install(DiagnosticsConfig {
        service_name: "maohuoban-rust".to_string(),
        environment: "test".to_string(),
        privacy: PrivacyPolicy::default(),
        capture: CapturePolicy::default(),
        cleanup: CleanupPolicy::default(),
        store: Box::new(store),
    })
    .expect("install diagnostics");

    let events = diagnostics.read_events().expect("events");
    let valid = events
        .iter()
        .find(|event| event.message == "valid after corrupt line")
        .expect("valid event");
    let warning = events
        .iter()
        .find(|event| event.message == "storage segment decode failed")
        .expect("storage warning");

    assert_eq!(valid.kind, EventKind::Log);
    assert_eq!(warning.kind, EventKind::Error);
    assert_eq!(warning.severity, Severity::Warn);
    assert_eq!(warning.metadata["source"], json!("file_segment_store"));
    assert_eq!(warning.metadata["line"], json!("1"));
    assert_eq!(warning.metadata["segment"], json!("corrupted.jsonl"));
    assert!(warning.metadata.get("error").is_some());
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
fn cleanup_removes_expired_debug_bundles_across_runtime_restart() {
    let _guard = diagnostics_test_lock();
    let temp = tempdir().expect("temp dir");
    let storage = temp.path().join("segments");
    let cleanup = CleanupPolicy {
        max_total_bytes: 1024 * 1024,
        max_segment_age: Duration::from_secs(7 * 24 * 60 * 60),
        max_export_age: Duration::from_secs(0),
    };
    let first_store = FileSegmentStore::new(&storage, 1024).expect("first store");
    let first_runtime = Diagnostics::install(DiagnosticsConfig {
        service_name: "maohuoban-rust".to_string(),
        environment: "test".to_string(),
        privacy: PrivacyPolicy::default(),
        capture: CapturePolicy::default(),
        cleanup: cleanup.clone(),
        store: Box::new(first_store),
    })
    .expect("install first diagnostics");

    first_runtime.error(
        "previous export cleanup input",
        Vec::<(String, serde_json::Value)>::new(),
    );
    first_runtime.flush().expect("flush events");
    let bundle = first_runtime
        .export_debug_bundle(temp.path().join("bundle"))
        .expect("export bundle");
    assert!(bundle.directory.exists());

    let next_store = FileSegmentStore::new(&storage, 1024).expect("next store");
    let next_runtime = Diagnostics::install(DiagnosticsConfig {
        service_name: "maohuoban-rust".to_string(),
        environment: "test".to_string(),
        privacy: PrivacyPolicy::default(),
        capture: CapturePolicy::default(),
        cleanup,
        store: Box::new(next_store),
    })
    .expect("install next diagnostics");
    let removed = next_runtime.cleanup().expect("cleanup");

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
fn diagnostics_facade_exports_debug_bundle_and_llm_prompt() {
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

    diagnostics.error(
        "facade export failed",
        [("feature", json!("facade-export"))],
    );
    diagnostics.flush().expect("flush events");

    let bundle = diagnostics
        .export_debug_bundle(temp.path().join("bundle"))
        .expect("export debug bundle");
    let prompt = diagnostics
        .export_llm_prompt("分析 facade 导出")
        .expect("export llm prompt");

    let timeline = fs::read_to_string(&bundle.timeline_path).expect("timeline");
    assert!(timeline.contains("facade export failed"));
    assert!(bundle.archive_path.exists());
    assert!(prompt.contains("分析 facade 导出"));
    assert!(prompt.contains("facade export failed"));
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
    diagnostics.network(
        NetworkSummary::new("GET", "https://api.example.com/profile")
            .status_code(500)
            .duration_ms(80),
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
    assert!(events.iter().any(|event| {
        event.kind == EventKind::Network
            && event.severity == Severity::Error
            && event.metadata.get("status_code") == Some(&json!(500))
            && event.message == "network request failed"
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
fn runtime_snapshot_reports_dropped_events_after_storage_write_failure() {
    let _guard = diagnostics_test_lock();
    let diagnostics = Diagnostics::install(DiagnosticsConfig {
        service_name: "maohuoban-rust".to_string(),
        environment: "test".to_string(),
        privacy: PrivacyPolicy::default(),
        capture: CapturePolicy::default(),
        cleanup: CleanupPolicy::default(),
        store: Box::new(FlakyStore::fail_first_append()),
    })
    .expect("install diagnostics");

    diagnostics.log(Severity::Error, "cannot be stored");
    diagnostics.capture_runtime_snapshot([("phase", json!("after-storage-error"))]);
    diagnostics.flush().expect("flush events");

    let events = diagnostics.read_events().expect("events");
    let event = events
        .iter()
        .find(|event| event.kind == EventKind::Performance && event.message == "runtime snapshot")
        .expect("runtime snapshot");
    assert_eq!(event.metadata["phase"], json!("after-storage-error"));
    assert_eq!(event.metadata["dropped_event_count"], json!(1));
    assert!(
        event.metadata["last_storage_error"]
            .as_str()
            .is_some_and(|error| error.contains("injected append failure"))
    );
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
fn bootstrap_runs_cleanup_before_recording_startup_events() {
    let _guard = diagnostics_test_lock();
    let temp = tempdir().expect("temp dir");
    let storage = temp.path().join("segments");
    fs::create_dir_all(&storage).expect("segments dir");
    let stale_event =
        DiagnosticEvent::new(EventKind::Log, Severity::Info, "stale before bootstrap");
    let stale_json = serde_json::to_string(&stale_event).expect("stale json");
    fs::write(storage.join("stale.jsonl"), format!("{stale_json}\n")).expect("stale segment");

    let diagnostics = Diagnostics::bootstrap(DiagnosticsBootstrapConfig {
        service_name: "maohuoban-rust".to_string(),
        environment: "test".to_string(),
        storage_directory: storage,
        max_segment_bytes: 1024 * 1024,
        privacy: PrivacyPolicy::default(),
        capture: CapturePolicy::default(),
        cleanup: CleanupPolicy {
            max_total_bytes: 1024 * 1024,
            max_segment_age: Duration::from_secs(0),
            max_export_age: Duration::from_secs(0),
        },
        defaults: serde_json::Map::default(),
        session_id: None,
        trace_id: None,
        capture_runtime_snapshot: false,
        cleanup_on_bootstrap: true,
        install_panic_hook: false,
    })
    .expect("bootstrap diagnostics");
    diagnostics.flush().expect("flush events");

    let events = diagnostics.read_events().expect("events");
    assert!(
        !events
            .iter()
            .any(|event| event.message == "stale before bootstrap")
    );
    assert!(events.iter().any(|event| {
        event.kind == EventKind::Lifecycle && event.message == "diagnostics bootstrap completed"
    }));
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

/// `FlakyStore` 测试用可失败存储
/// 核心职责：
/// - 模拟首次事件落盘失败
/// - 在后续写入中保留事件，验证运行时健康字段
struct FlakyStore {
    fail_next_append: bool,
    events: Vec<DiagnosticEvent>,
}

impl FlakyStore {
    fn fail_first_append() -> Self {
        Self {
            fail_next_append: true,
            events: Vec::new(),
        }
    }
}

impl EventStore for FlakyStore {
    fn append(&mut self, event: &DiagnosticEvent) -> Result<(), DiagnosticsError> {
        if self.fail_next_append {
            self.fail_next_append = false;
            return Err(std::io::Error::other("injected append failure").into());
        }
        self.events.push(event.clone());
        Ok(())
    }

    fn flush(&mut self) -> Result<(), DiagnosticsError> {
        Ok(())
    }

    fn read_all(&self) -> Result<Vec<DiagnosticEvent>, DiagnosticsError> {
        Ok(self.events.clone())
    }

    fn cleanup(&mut self, _policy: &CleanupPolicy) -> Result<CleanupReport, DiagnosticsError> {
        Ok(CleanupReport::default())
    }
}
