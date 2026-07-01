use serde::{Deserialize, Serialize};

/// TaskType Agent 单轮任务类型
/// 核心职责：
/// - 将用户需求收敛为稳定任务类型
/// - 作为 StepPlan 与 ExecutionPolicy 的输入边界
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TaskType {
    DirectAnswer,
    ContextAnswer,
    EvidenceReadTask,
    ClarificationTask,
    WriteTask,
    RejectTask,
}

impl TaskType {
    /// as_str 返回冻结任务类型编码
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::DirectAnswer => "direct_answer",
            Self::ContextAnswer => "context_answer",
            Self::EvidenceReadTask => "evidence_read_task",
            Self::ClarificationTask => "clarification_task",
            Self::WriteTask => "write_task",
            Self::RejectTask => "reject_task",
        }
    }
}
