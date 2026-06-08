use maohuoban_diagnostics::{
    CleanupPolicy, DebugBundle, DebugBundleExporter, Diagnostics, DiagnosticsConfig,
    DiagnosticsError, EventStore, FileSegmentStore, PrivacyPolicy,
};
use std::path::{Path, PathBuf};

/// `CollectorConfig` 采集器配置
/// 核心职责：
/// - 定义事件段目录与诊断包输出目录
/// - 为 CLI 和测试提供统一输入边界
pub struct CollectorConfig {
    pub service_name: String,
    pub environment: String,
    pub segments_directory: PathBuf,
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
            segments_directory: segments_directory.into(),
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
    let store = FileSegmentStore::new(config.segments_directory, 1024 * 1024)?;
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
        cleanup: CleanupPolicy::default(),
        store: Box::new(store),
    })?;
    DebugBundleExporter::new(output_directory.as_ref()).export(&diagnostics)
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
}
