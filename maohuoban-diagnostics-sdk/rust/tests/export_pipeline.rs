mod support;

use maohuoban_diagnostics::{
    DebugBundleExporter, DiagnosticEvent, EventKind, LlmPromptExporter, Severity,
};
use std::fs;
use support::{diagnostics_test_lock, install_file_diagnostics, tar_entries};
use tempfile::tempdir;

#[test]
fn debug_bundle_includes_checksums_and_archive() {
    let _guard = diagnostics_test_lock();
    let temp = tempdir().expect("temp dir");
    let diagnostics = install_file_diagnostics(temp.path());

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
fn prompt_exporter_summarizes_timeline_for_llm() {
    let _guard = diagnostics_test_lock();
    let temp = tempdir().expect("temp dir");
    let diagnostics = install_file_diagnostics(temp.path());

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
fn diagnostics_facade_exports_debug_bundle_and_llm_prompt() {
    let _guard = diagnostics_test_lock();
    let temp = tempdir().expect("temp dir");
    let diagnostics = install_file_diagnostics(temp.path());

    diagnostics.error(
        "facade export failed",
        [("feature", serde_json::json!("facade-export"))],
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
