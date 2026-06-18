use maohuoban_diagnostics::{DiagnosticEvent, EventKind, EventStore, FileSegmentStore, Severity};
use maohuoban_diagnostics_collector::{CollectorConfig, collect_debug_bundle};

fn temporary_directory() -> std::path::PathBuf {
    let unique = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .expect("system time")
        .as_nanos();
    let root = std::env::temp_dir().join(format!("maohuoban-collector-filter-{unique}"));
    std::fs::create_dir_all(&root).expect("create temp dir");
    root
}

#[test]
fn collector_trace_filter_exports_only_matching_trace_events() {
    let root = temporary_directory();
    let segments = root.join("segments");
    let output = root.join("bundle");
    let mut store = FileSegmentStore::new(&segments, 1024 * 1024).expect("store");

    store
        .append(
            &DiagnosticEvent::new(EventKind::Network, Severity::Info, "matching trace")
                .trace_id("trace-a"),
        )
        .expect("append matching");
    store
        .append(
            &DiagnosticEvent::new(EventKind::Network, Severity::Info, "other trace")
                .trace_id("trace-b"),
        )
        .expect("append other");

    collect_debug_bundle(CollectorConfig::from_paths(&segments, &output).with_trace("trace-a"))
        .expect("collect filtered bundle");

    let timeline = std::fs::read_to_string(output.join("timeline.jsonl")).expect("timeline");
    assert!(timeline.contains("matching trace"));
    assert!(!timeline.contains("other trace"));
}
