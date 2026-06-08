mod support;

use maohuoban_diagnostics::{DiagnosticEvent, EventKind, NetworkSummary, Severity};
use serde_json::json;
use support::{diagnostics_test_lock, install_file_diagnostics};
use tempfile::tempdir;

#[test]
fn install_makes_runtime_available_globally_and_records_convenience_events() {
    let _guard = diagnostics_test_lock();
    let temp = tempdir().expect("temp dir");
    let diagnostics = install_file_diagnostics(temp.path());

    let current = maohuoban_diagnostics::Diagnostics::current().expect("current diagnostics");
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
fn global_context_is_applied_to_events_without_temp_metadata_plumbing() {
    let _guard = diagnostics_test_lock();
    let temp = tempdir().expect("temp dir");
    let diagnostics = install_file_diagnostics(temp.path());

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
fn scoped_trace_restores_previous_trace_after_operation() {
    let _guard = diagnostics_test_lock();
    let temp = tempdir().expect("temp dir");
    let diagnostics = install_file_diagnostics(temp.path());

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
