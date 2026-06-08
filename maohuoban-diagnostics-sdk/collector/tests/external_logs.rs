use maohuoban_diagnostics::{DiagnosticEvent, EventKind, EventStore, FileSegmentStore, Severity};
use maohuoban_diagnostics_collector::{CollectorConfig, collect_debug_bundle};
use serde_json::json;
use tempfile::tempdir;

#[test]
fn collector_imports_external_log_files_into_timeline() {
    let root = tempdir().expect("temp dir");
    let segments = root.path().join("segments");
    let output = root.path().join("bundle");
    let log_file = root.path().join("xcode.log");
    std::fs::write(
        &log_file,
        "SwiftUI body updated\nnetwork request failed: timeout\n",
    )
    .expect("write log");

    let mut store = FileSegmentStore::new(&segments, 1024 * 1024).expect("store");
    store
        .append(&DiagnosticEvent::new(
            EventKind::Lifecycle,
            Severity::Info,
            "sdk input",
        ))
        .expect("append sdk");

    let bundle = collect_debug_bundle(
        CollectorConfig::from_paths(segments, output).with_log_files([log_file]),
    )
    .expect("collect bundle");
    let timeline = std::fs::read_to_string(bundle.timeline_path).expect("timeline");
    assert!(timeline.contains("sdk input"));
    assert!(timeline.contains("SwiftUI body updated"));
    assert!(timeline.contains("network request failed: timeout"));
    assert!(timeline.contains("\"source\":\"external_log\""));
}

#[test]
fn collector_exports_bundle_from_only_external_log_files() {
    let root = tempdir().expect("temp dir");
    let output = root.path().join("bundle");
    let log_file = root.path().join("xcode.log");
    std::fs::write(&log_file, "app launch failed\nmissing entitlement\n").expect("write log");

    let bundle = collect_debug_bundle(CollectorConfig::from_log_files([log_file], output))
        .expect("collect bundle");
    let timeline = std::fs::read_to_string(bundle.timeline_path).expect("timeline");
    let manifest = std::fs::read_to_string(bundle.manifest_path).expect("manifest");
    let manifest: serde_json::Value = serde_json::from_str(&manifest).expect("manifest json");

    assert!(timeline.contains("app launch failed"));
    assert!(timeline.contains("missing entitlement"));
    assert!(timeline.contains("\"source\":\"external_log\""));
    assert_eq!(manifest["event_count"], json!(2));
}

#[test]
fn collector_classifies_external_log_severity_markers() {
    let root = tempdir().expect("temp dir");
    let output = root.path().join("bundle");
    let log_file = root.path().join("xcode.log");
    std::fs::write(
        &log_file,
        [
            "2026-06-09 10:00:00.000 maohuoban[100:200] ERROR login failed",
            "warning: missing asset catalog color",
            "DEBUG cache warm completed",
            "TRACE render pass entered",
            "FATAL database migration corrupted",
        ]
        .join("\n"),
    )
    .expect("write log");

    let bundle = collect_debug_bundle(CollectorConfig::from_log_files([log_file], output))
        .expect("collect bundle");
    let timeline = std::fs::read_to_string(bundle.timeline_path).expect("timeline");
    let events = timeline
        .lines()
        .map(|line| serde_json::from_str::<serde_json::Value>(line).expect("event json"))
        .collect::<Vec<_>>();

    assert_eq!(events[0]["severity"], json!("error"));
    assert_eq!(events[1]["severity"], json!("warn"));
    assert_eq!(events[2]["severity"], json!("debug"));
    assert_eq!(events[3]["severity"], json!("trace"));
    assert_eq!(events[4]["severity"], json!("fatal"));
    assert_eq!(events[0]["metadata"]["external_log_marker"], json!("ERROR"));
    assert_eq!(
        events[1]["metadata"]["external_log_marker"],
        json!("warning")
    );
    assert_eq!(
        events[0]["metadata"]["external_log_format"],
        json!("xcode_or_system")
    );
}
