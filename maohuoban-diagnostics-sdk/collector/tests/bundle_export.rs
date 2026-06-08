mod support;

use maohuoban_diagnostics::{DiagnosticEvent, EventKind, EventStore, FileSegmentStore, Severity};
use maohuoban_diagnostics_collector::{CollectorConfig, collect_debug_bundle};
use support::tar_entries;
use tempfile::tempdir;

#[test]
fn collector_exports_existing_segments() {
    let root = tempdir().expect("temp dir");
    let segments = root.path().join("segments");
    let output = root.path().join("bundle");
    let mut store = FileSegmentStore::new(&segments, 1024 * 1024).expect("store");
    store
        .append(&DiagnosticEvent::new(
            EventKind::Log,
            Severity::Info,
            "collector input",
        ))
        .expect("append");

    let bundle = collect_debug_bundle(CollectorConfig::from_paths(segments, output))
        .expect("collect bundle");
    let timeline = std::fs::read_to_string(bundle.timeline_path).expect("timeline");
    assert!(timeline.contains("collector input"));
}

#[test]
fn collector_writes_llm_prompt_into_debug_bundle() {
    let root = tempdir().expect("temp dir");
    let segments = root.path().join("segments");
    let output = root.path().join("bundle");
    let mut store = FileSegmentStore::new(&segments, 1024 * 1024).expect("store");
    store
        .append(&DiagnosticEvent::new(
            EventKind::Error,
            Severity::Error,
            "collector prompt input",
        ))
        .expect("append");

    let bundle = collect_debug_bundle(CollectorConfig::from_paths(segments, output))
        .expect("collect bundle");
    let prompt = std::fs::read_to_string(bundle.directory.join("prompt.md")).expect("prompt");
    assert!(prompt.contains("maohuoban.diagnostics.prompt.v1"));
    assert!(prompt.contains("collector prompt input"));
}

#[test]
fn collector_keeps_archive_in_debug_bundle() {
    let root = tempdir().expect("temp dir");
    let segments = root.path().join("segments");
    let output = root.path().join("bundle");
    let mut store = FileSegmentStore::new(&segments, 1024 * 1024).expect("store");
    store
        .append(&DiagnosticEvent::new(
            EventKind::Error,
            Severity::Error,
            "collector archive input",
        ))
        .expect("append");

    let bundle = collect_debug_bundle(CollectorConfig::from_paths(segments, output))
        .expect("collect bundle");
    assert!(bundle.archive_path.exists());
    let manifest = std::fs::read_to_string(bundle.manifest_path).expect("manifest");
    assert!(manifest.contains("\"archive_path\""));

    let archive = std::fs::read(&bundle.archive_path).expect("archive");
    let entries = tar_entries(&archive);
    assert_eq!(
        entries
            .iter()
            .find(|(name, _)| name == "manifest.json")
            .map(|(_, data)| data.as_slice()),
        Some(
            std::fs::read(bundle.directory.join("manifest.json"))
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
            std::fs::read(bundle.directory.join("timeline.jsonl"))
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
            std::fs::read(bundle.directory.join("prompt.md"))
                .expect("prompt data")
                .as_slice()
        )
    );
}

#[test]
fn collector_merges_multiple_segment_directories_into_one_timeline() {
    let root = tempdir().expect("temp dir");
    let swift_segments = root.path().join("swift-segments");
    let rust_segments = root.path().join("rust-segments");
    let output = root.path().join("bundle");

    let mut swift_store = FileSegmentStore::new(&swift_segments, 1024 * 1024).expect("store");
    swift_store
        .append(&DiagnosticEvent::new(
            EventKind::Log,
            Severity::Info,
            "swift input",
        ))
        .expect("append swift");

    let mut rust_store = FileSegmentStore::new(&rust_segments, 1024 * 1024).expect("store");
    rust_store
        .append(&DiagnosticEvent::new(
            EventKind::Error,
            Severity::Error,
            "rust input",
        ))
        .expect("append rust");

    let bundle = collect_debug_bundle(CollectorConfig::from_segment_directories(
        [swift_segments, rust_segments],
        output,
    ))
    .expect("collect bundle");
    let timeline = std::fs::read_to_string(bundle.timeline_path).expect("timeline");
    assert!(timeline.contains("swift input"));
    assert!(timeline.contains("rust input"));
}

#[test]
fn collector_recovers_corrupted_segment_lines() {
    let root = tempdir().expect("temp dir");
    let segments = root.path().join("segments");
    let output = root.path().join("bundle");
    let mut store = FileSegmentStore::new(&segments, 1024 * 1024).expect("store");
    store
        .append(&DiagnosticEvent::new(
            EventKind::Log,
            Severity::Info,
            "collector valid after corrupt line",
        ))
        .expect("append");
    std::fs::write(segments.join("corrupted.jsonl"), "not json\n").expect("write corrupt line");

    let bundle = collect_debug_bundle(CollectorConfig::from_paths(segments, output))
        .expect("collect bundle");
    let timeline = std::fs::read_to_string(bundle.timeline_path).expect("timeline");

    assert!(timeline.contains("collector valid after corrupt line"));
    assert!(timeline.contains("storage segment decode failed"));
    assert!(timeline.contains("\"source\":\"file_segment_store\""));
    assert!(timeline.contains("\"segment\":\"corrupted.jsonl\""));
}
