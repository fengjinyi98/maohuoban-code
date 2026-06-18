use crate::{CollectorConfig, config::EventFilter, multi_source_store::MultiSourceSegmentStore};
use maohuoban_diagnostics::{
    CapturePolicy, CleanupPolicy, CleanupReport, DebugBundle, DebugBundleExporter, DiagnosticEvent,
    Diagnostics, DiagnosticsConfig, DiagnosticsError, EventStore, PrivacyPolicy,
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
    let store = FilteredEventStore::new(
        MultiSourceSegmentStore::new(config.segments_directories, config.log_files)?,
        config.filter,
    );
    collect_from_store(
        config.output_directory,
        store,
        config.service_name,
        config.environment,
    )
}

/// `FilteredEventStore` 过滤后的事件读取适配器
/// 核心职责：
/// - 包装多来源段文件读取
/// - 在导出前按 `CollectorConfig` 过滤事件
struct FilteredEventStore<S> {
    store: S,
    filter: EventFilter,
}

impl<S> FilteredEventStore<S> {
    const fn new(store: S, filter: EventFilter) -> Self {
        Self { store, filter }
    }
}

impl<S> EventStore for FilteredEventStore<S>
where
    S: EventStore,
{
    fn append(&mut self, event: &DiagnosticEvent) -> Result<(), DiagnosticsError> {
        self.store.append(event)
    }

    fn flush(&mut self) -> Result<(), DiagnosticsError> {
        self.store.flush()
    }

    fn read_all(&self) -> Result<Vec<DiagnosticEvent>, DiagnosticsError> {
        Ok(self
            .store
            .read_all()?
            .into_iter()
            .filter(|event| self.filter.matches(event))
            .collect())
    }

    fn cleanup(
        &mut self,
        policy: &maohuoban_diagnostics::CleanupPolicy,
    ) -> Result<CleanupReport, DiagnosticsError> {
        self.store.cleanup(policy)
    }
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
