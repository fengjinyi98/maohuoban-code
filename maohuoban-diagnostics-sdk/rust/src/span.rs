use crate::{DiagnosticEvent, Diagnostics, EventKind, Severity, runtime::event_with_metadata};
use serde_json::{Value, json};
use std::time::Instant;

/// `DiagnosticsSpan` 性能 span
/// 核心职责：
/// - 记录一段业务或系统操作的耗时
/// - 将耗时作为 performance 事件写入统一时间线
pub struct DiagnosticsSpan {
    name: String,
    diagnostics: Diagnostics,
    started_at: Instant,
}

impl DiagnosticsSpan {
    /// `new` 创建性能 span
    /// 核心职责：
    /// - 由运行时统一绑定诊断句柄
    /// - 保持 span 内部计时字段不暴露给调用方
    #[must_use]
    pub(crate) fn new(name: impl Into<String>, diagnostics: Diagnostics) -> Self {
        Self {
            name: name.into(),
            diagnostics,
            started_at: Instant::now(),
        }
    }

    /// `end` 结束 span 并写入性能事件
    /// 核心职责：
    /// - 计算 span 耗时
    /// - 合并业务 metadata 后记录 performance 事件
    pub fn end(self, metadata: impl IntoIterator<Item = (impl Into<String>, Value)>) {
        let duration = self.started_at.elapsed();
        let event = DiagnosticEvent::new(EventKind::Performance, Severity::Info, self.name)
            .metadata("duration_ms", json!(duration.as_millis()));
        self.diagnostics
            .record(event_with_metadata(event, metadata));
    }
}
