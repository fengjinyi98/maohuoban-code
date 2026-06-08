mod config;
mod export;
mod external_log;
mod multi_source_store;

pub use config::CollectorConfig;
pub use export::collect_debug_bundle;

#[cfg(test)]
mod tests {
    use super::*;
    use maohuoban_diagnostics::{
        DiagnosticEvent, EventKind, EventStore, FileSegmentStore, Severity,
    };
    use serde_json::json;
    use tempfile::tempdir;

    /// `tar_entries` 解析测试用无压缩 tar 条目
    /// 核心职责：
    /// - 验证 Collector 生成的归档可以按 tar 格式读取
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
}
