use serde_json::{Map, Value};

/// `DiagnosticsContext` 诊断上下文
/// 核心职责：
/// - 保存全局 `session_id`、`trace_id` 和默认 metadata
/// - 在统一记录管线中为后续事件补齐上下文
#[derive(Clone, Debug, Default)]
pub(super) struct DiagnosticsContext {
    pub(super) session_id: Option<String>,
    pub(super) trace_id: Option<String>,
    pub(super) metadata: Map<String, Value>,
}
