use maohuoban_diagnostics::{
    CapturePolicy, CleanupPolicy, CleanupReport, DebugBundle, DebugBundleExporter, DiagnosticEvent,
    Diagnostics, DiagnosticsConfig, DiagnosticsError, EventKind, EventStore, FileSegmentStore,
    LlmPromptExporter, PrivacyPolicy,
};
use serde_json::json;
use std::{
    io::{BufRead, BufReader},
    path::{Path, PathBuf},
};

/// `CollectorConfig` 采集器配置
/// 核心职责：
/// - 定义事件段目录与诊断包输出目录
/// - 为 CLI 和测试提供统一输入边界
pub struct CollectorConfig {
    pub service_name: String,
    pub environment: String,
    pub segments_directories: Vec<PathBuf>,
    pub log_files: Vec<PathBuf>,
    pub output_directory: PathBuf,
}

impl CollectorConfig {
    /// `from_paths` 基于路径创建采集器配置
    /// 核心职责：
    /// - 保持 CLI 参数解析与采集执行分离
    /// - 为本地调试生成稳定默认 service/environment
    #[must_use]
    pub fn from_paths(
        segments_directory: impl Into<PathBuf>,
        output_directory: impl Into<PathBuf>,
    ) -> Self {
        Self {
            service_name: "maohuoban-collector".to_string(),
            environment: "local".to_string(),
            segments_directories: vec![segments_directory.into()],
            log_files: Vec::new(),
            output_directory: output_directory.into(),
        }
    }

    /// `from_segment_directories` 基于多个段目录创建采集器配置
    /// 核心职责：
    /// - 支持 Swift、Rust 和其他来源的本地事件合并
    /// - 保持输出为单个 Debug Bundle
    #[must_use]
    pub fn from_segment_directories<I, P>(
        segments_directories: I,
        output_directory: impl Into<PathBuf>,
    ) -> Self
    where
        I: IntoIterator<Item = P>,
        P: Into<PathBuf>,
    {
        Self {
            service_name: "maohuoban-collector".to_string(),
            environment: "local".to_string(),
            segments_directories: segments_directories.into_iter().map(Into::into).collect(),
            log_files: Vec::new(),
            output_directory: output_directory.into(),
        }
    }

    /// `from_log_files` 基于外部日志文件创建采集器配置
    /// 核心职责：
    /// - 支持尚未接入 SDK 的 Xcode、Rust 进程和脚本输出导出
    /// - 保持输出仍为标准 Debug Bundle
    #[must_use]
    pub fn from_log_files<I, P>(log_files: I, output_directory: impl Into<PathBuf>) -> Self
    where
        I: IntoIterator<Item = P>,
        P: Into<PathBuf>,
    {
        Self {
            service_name: "maohuoban-collector".to_string(),
            environment: "local".to_string(),
            segments_directories: Vec::new(),
            log_files: log_files.into_iter().map(Into::into).collect(),
            output_directory: output_directory.into(),
        }
    }

    /// `with_log_files` 添加外部日志文件输入
    /// 核心职责：
    /// - 支持 Xcode、Rust 进程和脚本输出进入统一 timeline
    /// - 保持日志文件输入与 SDK 段目录输入声明式组合
    #[must_use]
    pub fn with_log_files<I, P>(mut self, log_files: I) -> Self
    where
        I: IntoIterator<Item = P>,
        P: Into<PathBuf>,
    {
        self.log_files = log_files.into_iter().map(Into::into).collect();
        self
    }
}

/// `collect_debug_bundle` 执行本地诊断包导出
/// 核心职责：
/// - 读取 SDK JSONL 段文件
/// - 导出适合 LLM 分析的 Debug Bundle
///
/// # Errors
///
/// 当段文件读取、诊断包目录创建或导出写入失败时返回错误。
pub fn collect_debug_bundle(config: CollectorConfig) -> Result<DebugBundle, DiagnosticsError> {
    let store = MultiSourceSegmentStore::new(config.segments_directories, config.log_files)?;
    collect_from_store(
        config.output_directory,
        store,
        config.service_name,
        config.environment,
    )
}

fn collect_from_store(
    output_directory: impl AsRef<Path>,
    store: impl EventStore + 'static,
    service_name: String,
    environment: String,
) -> Result<DebugBundle, DiagnosticsError> {
    let diagnostics = Diagnostics::install(DiagnosticsConfig {
        service_name,
        environment,
        privacy: PrivacyPolicy::default(),
        capture: CapturePolicy::default(),
        cleanup: CleanupPolicy::default(),
        store: Box::new(store),
    })?;
    let bundle = DebugBundleExporter::new(output_directory.as_ref()).export(&diagnostics)?;
    let prompt = LlmPromptExporter::new("分析 Maohuoban 诊断包").export_prompt(&diagnostics)?;
    std::fs::write(bundle.directory.join("prompt.md"), prompt)?;
    Ok(bundle)
}

/// `MultiSourceSegmentStore` 多来源段文件存储
/// 核心职责：
/// - 汇总多个 SDK JSONL 段目录
/// - 为 Collector 导出提供按时间排序的统一事件流
struct MultiSourceSegmentStore {
    stores: Vec<FileSegmentStore>,
    log_files: Vec<PathBuf>,
}

impl MultiSourceSegmentStore {
    fn new(
        directories: impl IntoIterator<Item = PathBuf>,
        log_files: impl IntoIterator<Item = PathBuf>,
    ) -> Result<Self, DiagnosticsError> {
        let stores = directories
            .into_iter()
            .map(|directory| FileSegmentStore::new(directory, 1024 * 1024))
            .collect::<Result<Vec<_>, _>>()?;
        Ok(Self {
            stores,
            log_files: log_files.into_iter().collect(),
        })
    }
}

impl EventStore for MultiSourceSegmentStore {
    fn append(&mut self, event: &DiagnosticEvent) -> Result<(), DiagnosticsError> {
        if let Some(store) = self.stores.first_mut() {
            store.append(event)?;
        }
        Ok(())
    }

    fn flush(&mut self) -> Result<(), DiagnosticsError> {
        for store in &mut self.stores {
            store.flush()?;
        }
        Ok(())
    }

    fn read_all(&self) -> Result<Vec<DiagnosticEvent>, DiagnosticsError> {
        let mut events = Vec::new();
        for store in &self.stores {
            events.extend(store.read_all()?);
        }
        for log_file in &self.log_files {
            events.extend(read_external_log_file(log_file)?);
        }
        events.sort_by_key(|event| event.timestamp);
        Ok(events)
    }

    fn cleanup(&mut self, policy: &CleanupPolicy) -> Result<CleanupReport, DiagnosticsError> {
        let mut report = CleanupReport::default();
        for store in &mut self.stores {
            let store_report = store.cleanup(policy)?;
            report.removed_segments += store_report.removed_segments;
            report.removed_exports += store_report.removed_exports;
            report.freed_bytes += store_report.freed_bytes;
        }
        Ok(report)
    }
}

/// `read_external_log_file` 读取外部日志文件
/// 核心职责：
/// - 将 Xcode、Rust 进程和脚本输出转换为标准 log 事件
/// - 为 Collector 多来源 timeline 提供统一事件输入
fn read_external_log_file(path: &Path) -> Result<Vec<DiagnosticEvent>, DiagnosticsError> {
    let file = std::fs::File::open(path)?;
    let reader = BufReader::new(file);
    let source_path = path.display().to_string();
    let mut events = Vec::new();
    for line in reader.lines() {
        let line = line?;
        let message = line.trim();
        if message.is_empty() {
            continue;
        }
        let parsed = parse_external_log_line(message);
        let mut event = DiagnosticEvent::new(EventKind::Log, parsed.severity, message)
            .metadata("source", json!("external_log"))
            .metadata("source_path", json!(source_path));
        if let Some(marker) = parsed.marker {
            event = event.metadata("external_log_marker", json!(marker));
        }
        if let Some(format) = parsed.format {
            event = event.metadata("external_log_format", json!(format));
        }
        events.push(event);
    }
    Ok(events)
}

/// `ParsedExternalLogLine` 外部日志解析结果
/// 核心职责：
/// - 承载从原始日志行识别出的严重级别
/// - 为事件 metadata 保留解析依据
struct ParsedExternalLogLine<'a> {
    severity: maohuoban_diagnostics::Severity,
    marker: Option<&'a str>,
    format: Option<&'static str>,
}

/// `parse_external_log_line` 解析外部日志行
/// 核心职责：
/// - 识别 Xcode、Rust 和脚本日志里的常见级别标记
/// - 保留原始日志文本，由 Collector 统一转换为标准事件
fn parse_external_log_line(line: &str) -> ParsedExternalLogLine<'_> {
    for token in line.split(|character: char| {
        character.is_whitespace()
            || matches!(
                character,
                '[' | ']' | '(' | ')' | '{' | '}' | '<' | '>' | ':' | '=' | ',' | ';'
            )
    }) {
        let Some(severity) = severity_from_marker(token) else {
            continue;
        };
        return ParsedExternalLogLine {
            severity,
            marker: Some(token),
            format: Some(classify_external_log_format(line)),
        };
    }

    ParsedExternalLogLine {
        severity: maohuoban_diagnostics::Severity::Info,
        marker: None,
        format: None,
    }
}

/// `severity_from_marker` 映射日志级别标记
/// 核心职责：
/// - 将常见大小写日志级别转换为诊断事件严重级别
/// - 保持外部日志解析逻辑集中在 Collector 层
fn severity_from_marker(marker: &str) -> Option<maohuoban_diagnostics::Severity> {
    match marker {
        "TRACE" | "Trace" | "trace" => Some(maohuoban_diagnostics::Severity::Trace),
        "DEBUG" | "Debug" | "debug" => Some(maohuoban_diagnostics::Severity::Debug),
        "INFO" | "Info" | "info" => Some(maohuoban_diagnostics::Severity::Info),
        "WARN" | "Warn" | "warn" | "WARNING" | "Warning" | "warning" => {
            Some(maohuoban_diagnostics::Severity::Warn)
        }
        "ERROR" | "Error" | "error" => Some(maohuoban_diagnostics::Severity::Error),
        "FATAL" | "Fatal" | "fatal" => Some(maohuoban_diagnostics::Severity::Fatal),
        _ => None,
    }
}

/// `classify_external_log_format` 判断外部日志格式
/// 核心职责：
/// - 标记日志行来源形态，辅助 LLM 判断上下文
/// - 为 Xcode、Rust 和普通脚本输出提供轻量分类
fn classify_external_log_format(line: &str) -> &'static str {
    if looks_like_xcode_or_system_log(line) {
        "xcode_or_system"
    } else if line.contains(" src/") || line.contains(".rs:") {
        "rust"
    } else {
        "plain"
    }
}

/// `looks_like_xcode_or_system_log` 判断 Xcode 或系统日志行
/// 核心职责：
/// - 识别带日期、进程和线程片段的 Apple 平台日志
/// - 为外部日志格式分类提供无依赖判断
fn looks_like_xcode_or_system_log(line: &str) -> bool {
    let bytes = line.as_bytes();
    bytes.len() >= 23
        && bytes[4] == b'-'
        && bytes[7] == b'-'
        && bytes[10].is_ascii_whitespace()
        && bytes[13] == b':'
        && bytes[16] == b':'
        && line.contains('[')
        && line.contains(']')
}

#[cfg(test)]
mod tests {
    use super::*;
    use maohuoban_diagnostics::{DiagnosticEvent, EventKind, Severity};
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
