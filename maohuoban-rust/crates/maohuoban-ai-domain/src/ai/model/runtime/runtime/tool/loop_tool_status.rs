use serde::{Deserialize, Serialize};

/// LoopToolStatus 工具调用状态
/// 核心职责：
/// - 表达工具在 Runtime 内的请求、结果和确认态
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum LoopToolStatus {
    Requested,
    Succeeded,
    Denied,
    Failed,
    RequiresConfirmation,
}
