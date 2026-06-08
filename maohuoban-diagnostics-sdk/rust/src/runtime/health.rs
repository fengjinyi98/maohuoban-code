/// `DiagnosticsStorageHealth` 诊断存储健康状态
/// 核心职责：
/// - 记录事件落盘失败导致的丢弃数量
/// - 为运行时快照提供 SDK 自身健康信号
#[derive(Default)]
pub(super) struct DiagnosticsStorageHealth {
    dropped_event_count: usize,
    last_storage_error: String,
}

/// `DiagnosticsStorageHealthSnapshot` 存储健康快照
/// 核心职责：
/// - 承载运行时读取到的存储失败状态
/// - 避免运行时快照直接暴露可变状态
pub(super) struct DiagnosticsStorageHealthSnapshot {
    pub(super) dropped_event_count: usize,
    pub(super) last_storage_error: String,
}

impl DiagnosticsStorageHealth {
    pub(super) fn record_dropped_event(&mut self, error: &str) {
        self.dropped_event_count += 1;
        error.clone_into(&mut self.last_storage_error);
    }

    pub(super) fn snapshot(&self) -> DiagnosticsStorageHealthSnapshot {
        DiagnosticsStorageHealthSnapshot {
            dropped_event_count: self.dropped_event_count,
            last_storage_error: self.last_storage_error.clone(),
        }
    }
}
