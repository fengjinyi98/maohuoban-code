use super::{ExecutionPolicy, StepKind, TaskType};

/// StepPlan 轻规划步骤计划
/// 核心职责：
/// - 记录单轮任务对应的顺序步骤
/// - 暴露终止步骤和策略裁决供 runtime 与 diagnostics 使用
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct StepPlan {
    task_type: TaskType,
    steps: Vec<StepKind>,
    policy: ExecutionPolicy,
}

impl StepPlan {
    /// new 创建步骤计划
    #[must_use]
    pub fn new(task_type: TaskType, steps: Vec<StepKind>, policy: ExecutionPolicy) -> Self {
        Self {
            task_type,
            steps,
            policy,
        }
    }

    /// task_type 返回本计划任务类型
    #[must_use]
    pub const fn task_type(&self) -> TaskType {
        self.task_type
    }

    /// step_kinds 返回顺序步骤
    #[must_use]
    pub fn step_kinds(&self) -> &[StepKind] {
        &self.steps
    }

    /// terminal_step 返回计划终止步骤
    #[must_use]
    pub fn terminal_step(&self) -> StepKind {
        self.steps
            .last()
            .copied()
            .unwrap_or(StepKind::FinalizeAnswer)
    }

    /// policy 返回执行策略
    #[must_use]
    pub const fn policy(&self) -> ExecutionPolicy {
        self.policy
    }
}
