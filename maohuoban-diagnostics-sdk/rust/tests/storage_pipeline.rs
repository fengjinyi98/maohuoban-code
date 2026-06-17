mod support;

use maohuoban_diagnostics::{
    CapturePolicy, CleanupPolicy, DebugBundleExporter, DiagnosticEvent, Diagnostics,
    DiagnosticsConfig, EventKind, FileSegmentStore, NetworkSummary, PrivacyPolicy, Severity,
    TextRedactionPattern, TrackingConsent,
};
use serde_json::json;
use std::{fs, time::Duration};
use support::{diagnostics_test_lock, install_file_diagnostics, install_file_diagnostics_with};
use tempfile::tempdir;

#[test]
fn records_events_with_privacy_filter_and_exports_debug_bundle() {
    let _guard = diagnostics_test_lock();
    let temp = tempdir().expect("temp dir");
    let diagnostics = install_file_diagnostics_with(
        temp.path(),
        1024 * 1024,
        PrivacyPolicy::default()
            .redact_key("authorization")
            .redact_key("password"),
        CapturePolicy::default(),
        CleanupPolicy::default(),
    );

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
fn privacy_policy_redacts_message_url_query_and_error_text() {
    let _guard = diagnostics_test_lock();
    let temp = tempdir().expect("temp dir");
    let diagnostics = install_file_diagnostics_with(
        temp.path(),
        1024 * 1024,
        PrivacyPolicy::default()
            .redact_query_item("token")
            .redact_text_pattern(TextRedactionPattern::Email)
            .redact_text_pattern(TextRedactionPattern::PhoneNumber),
        CapturePolicy::default(),
        CleanupPolicy::default(),
    );

    diagnostics.log(Severity::Info, "contact 13800138000 at user@example.com");
    diagnostics.network(
        NetworkSummary::new("GET", "https://api.example.com/profile?token=secret&safe=1")
            .error("failed for user@example.com"),
    );
    diagnostics.flush().expect("flush events");

    let events = diagnostics.read_events().expect("events");
    let log = events
        .iter()
        .find(|event| event.kind == EventKind::Log)
        .expect("log event");
    let network = events
        .iter()
        .find(|event| event.kind == EventKind::Network)
        .expect("network event");

    assert_eq!(log.message, "contact <redacted:phone> at <redacted:email>");
    assert_eq!(
        network.metadata["url"],
        json!("https://api.example.com/profile?token=<redacted>&safe=1")
    );
    assert_eq!(
        network.metadata["error"],
        json!("failed for <redacted:email>")
    );
}

#[test]
fn capture_policy_filters_low_severity_and_truncates_oversized_fields() {
    let _guard = diagnostics_test_lock();
    let temp = tempdir().expect("temp dir");
    let diagnostics = install_file_diagnostics_with(
        temp.path(),
        1024 * 1024,
        PrivacyPolicy::default(),
        CapturePolicy {
            minimum_severity: Severity::Warn,
            max_message_length: 8,
            max_metadata_value_length: 6,
            ..CapturePolicy::default()
        },
        CleanupPolicy::default(),
    );

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
fn capture_policy_consent_enabled_and_sampling_control_event_writes() {
    let _guard = diagnostics_test_lock();
    let temp = tempdir().expect("temp dir");
    let disabled = install_file_diagnostics_with(
        &temp.path().join("disabled"),
        1024 * 1024,
        PrivacyPolicy::default(),
        CapturePolicy {
            enabled: false,
            ..CapturePolicy::default()
        },
        CleanupPolicy::default(),
    );
    disabled.error("disabled event", Vec::<(String, serde_json::Value)>::new());
    assert!(disabled.read_events().expect("disabled events").is_empty());

    let pending = install_file_diagnostics_with(
        &temp.path().join("pending"),
        1024 * 1024,
        PrivacyPolicy::default(),
        CapturePolicy {
            consent: TrackingConsent::Pending,
            ..CapturePolicy::default()
        },
        CleanupPolicy::default(),
    );
    pending.error("pending event", Vec::<(String, serde_json::Value)>::new());
    assert!(pending.read_events().expect("pending events").is_empty());

    let sampled_out = install_file_diagnostics_with(
        &temp.path().join("sampled-out"),
        1024 * 1024,
        PrivacyPolicy::default(),
        CapturePolicy {
            sample_rate: 0.0,
            ..CapturePolicy::default()
        },
        CleanupPolicy::default(),
    );
    sampled_out.error(
        "sampled out event",
        Vec::<(String, serde_json::Value)>::new(),
    );
    assert!(
        sampled_out
            .read_events()
            .expect("sampled out events")
            .is_empty()
    );
}

#[test]
fn runtime_can_update_capture_policy_controls() {
    let _guard = diagnostics_test_lock();
    let temp = tempdir().expect("temp dir");
    let diagnostics = install_file_diagnostics_with(
        temp.path(),
        1024 * 1024,
        PrivacyPolicy::default(),
        CapturePolicy {
            consent: TrackingConsent::Pending,
            ..CapturePolicy::default()
        },
        CleanupPolicy::default(),
    );

    diagnostics.error("before consent", Vec::<(String, serde_json::Value)>::new());
    diagnostics.set_tracking_consent(TrackingConsent::Granted);
    diagnostics.set_capture_enabled(false);
    diagnostics.error(
        "disabled after consent",
        Vec::<(String, serde_json::Value)>::new(),
    );
    diagnostics.set_capture_enabled(true);
    diagnostics.set_sample_rate(1.0);
    diagnostics.error("after consent", Vec::<(String, serde_json::Value)>::new());

    let events = diagnostics.read_events().expect("events");
    assert!(!events.iter().any(|event| event.message == "before consent"));
    assert!(
        !events
            .iter()
            .any(|event| event.message == "disabled after consent")
    );
    assert!(events.iter().any(|event| event.message == "after consent"));
}

#[test]
fn cleanup_removes_old_segments_and_keeps_recent_events() {
    let _guard = diagnostics_test_lock();
    let temp = tempdir().expect("temp dir");
    let diagnostics = install_file_diagnostics_with(
        temp.path(),
        1024,
        PrivacyPolicy::default(),
        CapturePolicy::default(),
        CleanupPolicy {
            max_total_bytes: 1024 * 1024,
            max_segment_age: Duration::from_secs(0),
            max_export_age: Duration::from_secs(0),
        },
    );

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
    let diagnostics = install_file_diagnostics_with(
        temp.path(),
        1024,
        PrivacyPolicy::default(),
        CapturePolicy::default(),
        CleanupPolicy {
            max_total_bytes: 1024 * 1024,
            max_segment_age: Duration::from_hours(168),
            max_export_age: Duration::from_secs(0),
        },
    );

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
        max_segment_age: Duration::from_hours(168),
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
fn install_file_diagnostics_uses_standard_runtime() {
    let _guard = diagnostics_test_lock();
    let temp = tempdir().expect("temp dir");
    let diagnostics = install_file_diagnostics(temp.path());

    diagnostics.log(Severity::Info, "standard helper event");
    diagnostics.flush().expect("flush events");

    assert!(
        diagnostics
            .read_events()
            .expect("events")
            .iter()
            .any(|event| event.message == "standard helper event")
    );
}
