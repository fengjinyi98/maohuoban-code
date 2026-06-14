use maohuoban_diagnostics::{DiagnosticEvent, EventKind, EventStore, FileSegmentStore, Severity};
use maohuoban_diagnostics_collector::{WorkspaceReportConfig, collect_workspace_report};
use tempfile::tempdir;

#[test]
fn workspace_report_writes_latest_bundle_under_hidden_root_directory() {
    let root = tempdir().expect("temp dir");
    let segments = root.path().join(".maohuoban-diagnostics").join("segments");
    let mut store = FileSegmentStore::new(&segments, 1024 * 1024).expect("store");
    store
        .append(&DiagnosticEvent::new(
            EventKind::Error,
            Severity::Error,
            "workspace collector input",
        ))
        .expect("append");

    let report = collect_workspace_report(WorkspaceReportConfig::new(root.path()))
        .expect("collect workspace report");

    let latest = root.path().join(".maohuoban-diagnostics").join("latest");
    assert_eq!(report.bundle.directory, latest);
    assert!(latest.join("manifest.json").exists());
    assert!(latest.join("timeline.jsonl").exists());
    assert!(latest.join("prompt.md").exists());
    assert!(latest.join("index.json").exists());
    assert!(latest.join("archive.tar").exists());

    let prompt = std::fs::read_to_string(latest.join("prompt.md")).expect("prompt");
    assert!(prompt.contains("maohuoban.diagnostics.prompt.v1"));
    assert!(prompt.contains("workspace collector input"));

    let index = std::fs::read_to_string(latest.join("index.json")).expect("index");
    assert!(index.contains("\"recommended_read_order\""));
    assert!(index.contains("\"prompt.md\""));
    assert!(index.contains("\"timeline.jsonl\""));
}

#[test]
fn workspace_report_can_remove_source_sdk_reports_after_export() {
    let root = tempdir().expect("temp dir");
    let segments = root.path().join("system-segments");
    let mut store = FileSegmentStore::new(&segments, 1024 * 1024).expect("store");
    store
        .append(&DiagnosticEvent::new(
            EventKind::Breadcrumb,
            Severity::Info,
            "source cleanup input",
        ))
        .expect("append");
    std::fs::write(segments.join(".debug-bundles.jsonl"), "").expect("debug bundle index");
    std::fs::write(segments.join("note.txt"), "keep").expect("unrelated file");

    let report = collect_workspace_report(
        WorkspaceReportConfig::new(root.path())
            .with_segment_directories([segments.clone()])
            .clean_sources(true),
    )
    .expect("collect workspace report");

    let timeline = std::fs::read_to_string(report.bundle.timeline_path).expect("timeline");
    assert!(timeline.contains("source cleanup input"));
    assert!(report.cleaned_sources.removed_files >= 2);
    assert!(segments.join("note.txt").exists());

    let remaining_reports = std::fs::read_dir(&segments)
        .expect("segments dir")
        .filter_map(Result::ok)
        .filter(|entry| {
            entry
                .path()
                .extension()
                .is_some_and(|extension| extension == "jsonl")
        })
        .collect::<Vec<_>>();
    assert!(
        remaining_reports.is_empty(),
        "all jsonl SDK report files should be removed"
    );
}
