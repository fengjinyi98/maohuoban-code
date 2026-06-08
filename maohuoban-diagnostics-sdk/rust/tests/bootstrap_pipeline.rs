mod support;

use maohuoban_diagnostics::{
    CapturePolicy, CleanupPolicy, DiagnosticEvent, Diagnostics, DiagnosticsBootstrapConfig,
    EventKind, PrivacyPolicy, Severity,
};
use serde_json::json;
use std::{fs, time::Duration};
use support::diagnostics_test_lock;
use tempfile::tempdir;

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
