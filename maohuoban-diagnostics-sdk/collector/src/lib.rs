use maohuoban_diagnostics::{
    CapturePolicy, CleanupPolicy, CleanupReport, DebugBundle, DebugBundleExporter, DiagnosticEvent,
    Diagnostics, DiagnosticsConfig, DiagnosticsError, EventStore, FileSegmentStore,
    LlmPromptExporter, PrivacyPolicy,
};
use std::path::{Path, PathBuf};

/// `CollectorConfig` 采集器配置
/// 核心职责：
/// - 定义事件段目录与诊断包输出目录
/// - 为 CLI 和测试提供统一输入边界
pub struct CollectorConfig {
    pub service_name: String,
    pub environment: String,
    pub segments_directories: Vec<PathBuf>,
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
            output_directory: output_directory.into(),
        }
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
    let store = MultiSourceSegmentStore::new(config.segments_directories)?;
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
}

impl MultiSourceSegmentStore {
    fn new(directories: impl IntoIterator<Item = PathBuf>) -> Result<Self, DiagnosticsError> {
        let stores = directories
            .into_iter()
            .map(|directory| FileSegmentStore::new(directory, 1024 * 1024))
            .collect::<Result<Vec<_>, _>>()?;
        Ok(Self { stores })
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
}
