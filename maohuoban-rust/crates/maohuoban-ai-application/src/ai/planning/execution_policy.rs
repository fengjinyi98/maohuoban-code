use super::TaskType;

/// ExecutionPolicy 任务执行策略
/// 核心职责：
/// - 固定任务是否允许模型直答、是否必须取证和是否必须确认
/// - 为 Runtime 与 diagnostics 提供不可绕过的策略裁决编码
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ExecutionPolicy {
    task_type: TaskType,
}

impl ExecutionPolicy {
    /// for_task 返回任务对应执行策略
    #[must_use]
    pub const fn for_task(task_type: TaskType) -> Self {
        Self { task_type }
    }

    /// allows_direct_model_answer 返回是否允许模型直接回答
    #[must_use]
    pub const fn allows_direct_model_answer(self) -> bool {
        matches!(self.task_type, TaskType::DirectAnswer)
    }

    /// requires_evidence 返回是否必须先取证
    #[must_use]
    pub const fn requires_evidence(self) -> bool {
        matches!(self.task_type, TaskType::EvidenceReadTask)
    }

    /// requires_confirmation 返回是否必须确认
    #[must_use]
    pub const fn requires_confirmation(self) -> bool {
        matches!(self.task_type, TaskType::WriteTask)
    }

    /// requires_clarification 返回是否必须追问
    #[must_use]
    pub const fn requires_clarification(self) -> bool {
        matches!(self.task_type, TaskType::ClarificationTask)
    }

    /// rejects_task 返回是否直接拒绝
    #[must_use]
    pub const fn rejects_task(self) -> bool {
        matches!(self.task_type, TaskType::RejectTask)
    }

    /// policy_decision 返回冻结策略裁决编码
    #[must_use]
    pub const fn policy_decision(self) -> &'static str {
        match self.task_type {
            TaskType::DirectAnswer => "allow_direct_answer",
            TaskType::ContextAnswer => "requires_context",
            TaskType::EvidenceReadTask => "requires_evidence",
            TaskType::ClarificationTask => "clarify_user",
            TaskType::WriteTask => "requires_confirmation",
            TaskType::RejectTask => "reject",
        }
    }
}
