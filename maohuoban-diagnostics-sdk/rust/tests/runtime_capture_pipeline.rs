mod support;

use maohuoban_diagnostics::{
    CapturePolicy, CleanupPolicy, Diagnostics, DiagnosticsConfig, EventKind, NetworkSummary,
    PrivacyPolicy, Severity, TraceContext,
};
use serde_json::json;
use support::{
    CheckoutError, DatabaseError, FlakyStore, diagnostics_test_lock, install_file_diagnostics,
};
use tempfile::tempdir;

#[test]
fn trace_context_builds_w3c_traceparent() {
    let context = TraceContext::new("4bf92f3577b34da6a3ce929d0e0e4736", "00f067aa0ba902b7", true);

    assert_eq!(
        context.traceparent(),
        "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"
    );
}

#[test]
fn network_summary_api_records_success_and_failure_without_temp_logs() {
    let _guard = diagnostics_test_lock();
    let temp = tempdir().expect("temp dir");
    let diagnostics = install_file_diagnostics(temp.path());

    diagnostics.network(
        NetworkSummary::new("GET", "https://api.example.com/feed")
            .status_code(200)
            .duration_ms(42)
            .trace_context(TraceContext::new(
                "4bf92f3577b34da6a3ce929d0e0e4736",
                "00f067aa0ba902b7",
                true,
            ))
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
            && event.metadata["http.request.method"] == json!("GET")
            && event.metadata["url.full"] == json!("https://api.example.com/feed")
            && event.metadata["http.response.status_code"] == json!(200)
            && event.metadata["traceparent"]
                == json!("00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01")
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
fn captures_error_source_chain_as_structured_metadata() {
    let _guard = diagnostics_test_lock();
    let temp = tempdir().expect("temp dir");
    let diagnostics = install_file_diagnostics(temp.path());

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
    let diagnostics = install_file_diagnostics(temp.path());

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
fn panic_hook_records_panic_as_fatal_error_event() {
    let _guard = diagnostics_test_lock();
    let temp = tempdir().expect("temp dir");
    let diagnostics = install_file_diagnostics(temp.path());
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
