use maohuoban_diagnostics_collector::{CollectorConfig, collect_debug_bundle};
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

fn run(args: &[String]) -> Result<(), String> {
    let mut segments = Vec::new();
    let mut log_files = Vec::new();
    let mut output = None;
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
            "--help" | "-h" => {
                print_help();
                return Ok(());
            }
            unknown => return Err(format!("unknown argument: {unknown}")),
        }
        index += 1;
    }

    if segments.is_empty() {
        return Err("missing --segments <path>".to_string());
    }
    let output = output.ok_or_else(|| "missing --output <path>".to_string())?;
    let bundle = collect_debug_bundle(
        CollectorConfig::from_segment_directories(segments, output).with_log_files(log_files),
    )
    .map_err(|error| error.to_string())?;
    println!("{}", bundle.directory.display());
    Ok(())
}

fn print_help() {
    println!(
        "maohuoban_diagnostics_collector --segments <path> [--segments <path> ...] [--log-file <path> ...] --output <path>\n\n导出 Maohuoban Debug Bundle。"
    );
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
}
