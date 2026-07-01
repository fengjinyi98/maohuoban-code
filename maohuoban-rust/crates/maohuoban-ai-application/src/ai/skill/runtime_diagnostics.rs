use maohuoban_diagnostics::{DiagnosticEvent, Diagnostics, EventKind, Severity};

use super::SkillDiagnosticsSnapshot;

/// SkillRuntimeDiagnostics Skill Runtime 诊断记录器
/// 核心职责：
/// - 将 SkillDiagnosticsSnapshot 写入正式 diagnostics 链路
/// - 只记录 ID、层级、策略摘要和长度，不记录完整指令正文
pub(crate) struct SkillRuntimeDiagnostics;

impl SkillRuntimeDiagnostics {
    /// record_matched 记录 skill 匹配结果
    pub(crate) fn record_matched(snapshot: &SkillDiagnosticsSnapshot) {
        let Some(diagnostics) = Diagnostics::current() else {
            return;
        };
        let mut event = DiagnosticEvent::new(
            EventKind::Analytics,
            Severity::Debug,
            SkillDiagnosticsSnapshot::event_name(),
        );
        for (key, value) in snapshot.to_metadata_entries() {
            event = event.metadata(key, value);
        }
        diagnostics.record(event);
    }
}
