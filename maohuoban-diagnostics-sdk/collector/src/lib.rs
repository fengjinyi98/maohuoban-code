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
        events.push(
            DiagnosticEvent::new(
                EventKind::Log,
                maohuoban_diagnostics::Severity::Info,
                message,
            )
            .metadata("source", json!("external_log"))
            .metadata("source_path", json!(source_path)),
        );
    }
    Ok(events)
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
}
