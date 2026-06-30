use serde::{Deserialize, Serialize};

/// AgentToolStatus Runtime 工具执行状态
/// 核心职责：
/// - 表达工具调用在 Runtime 内部的完成结果
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AgentToolStatus {
    Succeeded,
    Failed,
    Denied,
}
