use serde::{Deserialize, Serialize};

/// AgentTurnTerminationReason Runtime turn 终止原因
/// 核心职责：
/// - 区分自然停止、轮次上限、澄清中断和输出守卫失败
/// - 为 diagnostics、contract tests 和上层观测提供稳定编码
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AgentTurnTerminationReason {
    ModelStop,
    MaxToolRounds,
    AwaitingClarification,
    OutputGuardFailed,
}
