use maohuoban_diagnostics_collector::{
    CollectorConfig, WorkspaceReportConfig, collect_debug_bundle, collect_workspace_report,
};

use maohuoban_diagnostics::Severity;
use std::{env, path::PathBuf, process};

/// main Collector CLI 入口
/// 核心职责：
/// - 解析本地段文件目录与输出目录
/// - 将采集结果导出为 Debug Bundle
fn main() {
    let args = env::args().skip(1).collect::<Vec<_>>();
    match run(&args) {
        Ok(()) => {}
        Err(error) => {
            eprintln!("{error}");
            process::exit(1);
        }
    }
}

#[allow(clippy::too_many_lines)]
fn run(args: &[String]) -> Result<(), String> {
    let mut segments = Vec::new();
    let mut log_files = Vec::new();
    let mut output = None;
    let mut workspace_root = None;
    let mut clean_sources = false;
    let mut trace = None;
    let mut session = None;
    let mut severity = None;
    let mut screen = None;
    let mut request_id = None;
    let mut index = 0;
    while index < args.len() {
        match args[index].as_str() {
            "--segments" => {
                index += 1;
                let path = args
                    .get(index)
                    .ok_or_else(|| "missing value for --segments".to_string())?;
                segments.push(PathBuf::from(path));
            }
            "--log-file" => {
                index += 1;
                let path = args
                    .get(index)
                    .ok_or_else(|| "missing value for --log-file".to_string())?;
                log_files.push(PathBuf::from(path));
            }
            "--output" => {
                index += 1;
                output = args.get(index).map(PathBuf::from);
            }
            "--workspace-root" => {
                index += 1;
                workspace_root = args.get(index).map(PathBuf::from);
            }
            "--clean-sources" => {
                clean_sources = true;
            }
            "--trace" => {
                index += 1;
                trace = args.get(index).cloned();
                if trace.is_none() {
                    return Err("missing value for --trace".to_string());
                }
            }
            "--session" => {
                index += 1;
                session = args.get(index).cloned();
                if session.is_none() {
                    return Err("missing value for --session".to_string());
                }
            }
            "--severity" => {
                index += 1;
                let value = args
                    .get(index)
                    .ok_or_else(|| "missing value for --severity".to_string())?;
                severity = Some(parse_severity(value)?);
            }
            "--screen" => {
                index += 1;
                screen = args.get(index).cloned();
                if screen.is_none() {
                    return Err("missing value for --screen".to_string());
                }
            }
            "--request-id" => {
                index += 1;
                request_id = args.get(index).cloned();
                if request_id.is_none() {
                    return Err("missing value for --request-id".to_string());
                }
            }
            "--help" | "-h" => {
                print_help();
                return Ok(());
            }
            unknown => return Err(format!("unknown argument: {unknown}")),
        }
        index += 1;
    }

    if let Some(workspace_root) = workspace_root {
        if output.is_some() {
            return Err("use either --workspace-root <path> or --output <path>".to_string());
        }
        let mut config = WorkspaceReportConfig::new(workspace_root)
            .with_log_files(log_files)
            .clean_sources(clean_sources)
            .with_filter_options(trace, session, severity, screen, request_id);
        if !segments.is_empty() {
            config = config.with_segment_directories(segments);
        }
        let report = collect_workspace_report(config).map_err(|error| error.to_string())?;
        println!("{}", report.bundle.directory.display());
        return Ok(());
    }

    if clean_sources {
        return Err("--clean-sources requires --workspace-root <path>".to_string());
    }
    if segments.is_empty() && log_files.is_empty() {
        return Err("missing input: provide --segments <path> or --log-file <path>".to_string());
    }
    let output = output.ok_or_else(|| "missing --output <path>".to_string())?;
    let config = CollectorConfig::from_segment_directories(segments, output)
        .with_log_files(log_files)
        .with_filter_options(trace, session, severity, screen, request_id);
    let bundle = collect_debug_bundle(config).map_err(|error| error.to_string())?;
    println!("{}", bundle.directory.display());
    Ok(())
}

fn print_help() {
    println!(
        "maohuoban_diagnostics_collector [--segments <path> ...] [--log-file <path> ...] (--output <path> | --workspace-root <path>) [--clean-sources] [--trace <id>] [--session <id>] [--severity <level>] [--screen <name>] [--request-id <id>]\n\n导出 Maohuoban Debug Bundle。"
    );
}

fn parse_severity(value: &str) -> Result<Severity, String> {
    match value {
        "trace" => Ok(Severity::Trace),
        "debug" => Ok(Severity::Debug),
        "info" => Ok(Severity::Info),
        "warn" => Ok(Severity::Warn),
        "error" => Ok(Severity::Error),
        "fatal" => Ok(Severity::Fatal),
        unknown => Err(format!("unknown severity: {unknown}")),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use maohuoban_diagnostics::{
        DiagnosticEvent, EventKind, EventStore, FileSegmentStore, Severity,
    };
    use tempfile::tempdir;

    #[test]
    fn cli_accepts_repeated_segments_arguments() {
        let root = tempdir().expect("temp dir");
        let swift_segments = root.path().join("swift-segments");
        let rust_segments = root.path().join("rust-segments");
        let output = root.path().join("bundle");

        let mut swift_store = FileSegmentStore::new(&swift_segments, 1024 * 1024).expect("store");
        swift_store
            .append(&DiagnosticEvent::new(
                EventKind::Log,
                Severity::Info,
                "cli swift input",
            ))
            .expect("append swift");

        let mut rust_store = FileSegmentStore::new(&rust_segments, 1024 * 1024).expect("store");
        rust_store
            .append(&DiagnosticEvent::new(
                EventKind::Error,
                Severity::Error,
                "cli rust input",
            ))
            .expect("append rust");

        run(&[
            "--segments".to_string(),
            swift_segments.display().to_string(),
            "--segments".to_string(),
            rust_segments.display().to_string(),
            "--output".to_string(),
            output.display().to_string(),
        ])
        .expect("run collector");

        let timeline = std::fs::read_to_string(output.join("timeline.jsonl")).expect("timeline");
        assert!(timeline.contains("cli swift input"));
        assert!(timeline.contains("cli rust input"));
    }

    #[test]
    fn cli_accepts_external_log_file_arguments() {
        let root = tempdir().expect("temp dir");
        let segments = root.path().join("segments");
        let log_file = root.path().join("xcode.log");
        let output = root.path().join("bundle");

        let mut store = FileSegmentStore::new(&segments, 1024 * 1024).expect("store");
        store
            .append(&DiagnosticEvent::new(
                EventKind::Lifecycle,
                Severity::Info,
                "cli sdk input",
            ))
            .expect("append sdk");
        std::fs::write(&log_file, "preview crashed\nnetwork timeout\n").expect("write log");

        run(&[
            "--segments".to_string(),
            segments.display().to_string(),
            "--log-file".to_string(),
            log_file.display().to_string(),
            "--output".to_string(),
            output.display().to_string(),
        ])
        .expect("run collector");

        let timeline = std::fs::read_to_string(output.join("timeline.jsonl")).expect("timeline");
        assert!(timeline.contains("cli sdk input"));
        assert!(timeline.contains("preview crashed"));
        assert!(timeline.contains("network timeout"));
    }

    #[test]
    fn cli_accepts_only_external_log_file_arguments() {
        let root = tempdir().expect("temp dir");
        let log_file = root.path().join("xcode.log");
        let output = root.path().join("bundle");
        std::fs::write(&log_file, "launch failed\nmissing entitlement\n").expect("write log");

        run(&[
            "--log-file".to_string(),
            log_file.display().to_string(),
            "--output".to_string(),
            output.display().to_string(),
        ])
        .expect("run collector");

        let timeline = std::fs::read_to_string(output.join("timeline.jsonl")).expect("timeline");
        assert!(timeline.contains("launch failed"));
        assert!(timeline.contains("missing entitlement"));
    }

    #[test]
    fn cli_writes_workspace_report_under_hidden_root_directory() {
        let root = tempdir().expect("temp dir");
        let segments = root.path().join(".maohuoban-diagnostics").join("segments");
        let mut store = FileSegmentStore::new(&segments, 1024 * 1024).expect("store");
        store
            .append(&DiagnosticEvent::new(
                EventKind::Error,
                Severity::Error,
                "cli workspace input",
            ))
            .expect("append");

        run(&[
            "--workspace-root".to_string(),
            root.path().display().to_string(),
        ])
        .expect("run collector");

        let latest = root.path().join(".maohuoban-diagnostics").join("latest");
        let timeline = std::fs::read_to_string(latest.join("timeline.jsonl")).expect("timeline");
        assert!(latest.join("prompt.md").exists());
        assert!(latest.join("index.json").exists());
        assert!(timeline.contains("cli workspace input"));
    }

    #[test]
    fn cli_can_clean_source_reports_after_workspace_export() {
        let root = tempdir().expect("temp dir");
        let segments = root.path().join("segments");
        let mut store = FileSegmentStore::new(&segments, 1024 * 1024).expect("store");
        store
            .append(&DiagnosticEvent::new(
                EventKind::Breadcrumb,
                Severity::Info,
                "cli source cleanup input",
            ))
            .expect("append");

        run(&[
            "--segments".to_string(),
            segments.display().to_string(),
            "--workspace-root".to_string(),
            root.path().display().to_string(),
            "--clean-sources".to_string(),
        ])
        .expect("run collector");

        let latest = root.path().join(".maohuoban-diagnostics").join("latest");
        let timeline = std::fs::read_to_string(latest.join("timeline.jsonl")).expect("timeline");
        assert!(timeline.contains("cli source cleanup input"));

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
        assert!(remaining_reports.is_empty());
    }

    #[test]
    fn cli_rejects_legacy_serve_ingest_mode() {
        let error = run(&["--serve-ingest".to_string()]).expect_err("reject serve ingest");

        assert_eq!(error, "unknown argument: --serve-ingest");
    }
}
