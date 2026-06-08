use crate::external_log::read_external_log_file;
use maohuoban_diagnostics::{
    CleanupPolicy, CleanupReport, DiagnosticEvent, DiagnosticsError, EventStore, FileSegmentStore,
};
use std::path::PathBuf;

/// `MultiSourceSegmentStore` 多来源段文件存储
/// 核心职责：
/// - 汇总多个 SDK JSONL 段目录
/// - 为 Collector 导出提供按时间排序的统一事件流
pub(crate) struct MultiSourceSegmentStore {
    stores: Vec<FileSegmentStore>,
    log_files: Vec<PathBuf>,
}

impl MultiSourceSegmentStore {
    pub(crate) fn new(
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
