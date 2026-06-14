use crate::{CollectorConfig, multi_source_store::MultiSourceSegmentStore};
use maohuoban_diagnostics::{
    CapturePolicy, CleanupPolicy, DebugBundle, DebugBundleExporter, Diagnostics, DiagnosticsConfig,
    DiagnosticsError, EventStore, PrivacyPolicy,
};
use std::path::Path;

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
    DebugBundleExporter::new(output_directory.as_ref()).export(&diagnostics)
}
