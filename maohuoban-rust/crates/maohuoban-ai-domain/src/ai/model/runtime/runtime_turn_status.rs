use serde::{Deserialize, Serialize};

/// AgentTurnStatus Runtime turn 结束状态
/// 核心职责：
/// - 表达单轮对话完成、等待或失败状态
/// - 包含运行中、完成、失败、中断和等待确认
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AgentTurnStatus {
    Running,
    Completed,
    Failed,
    Interrupted,
    AwaitingConfirmation,
    AwaitingClarification,
}
