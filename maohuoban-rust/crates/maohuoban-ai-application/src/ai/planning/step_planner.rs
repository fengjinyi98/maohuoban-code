use super::{ExecutionPolicy, StepKind, StepPlan, TaskType};

/// StepPlanner 轻规划步骤生成器
/// 核心职责：
/// - 将 TaskType 映射为线性 StepPlan
/// - 固定模型回答、上下文回答和安全拒绝路径的停止边界
pub struct StepPlanner;

impl StepPlanner {
    /// plan 生成指定任务类型的顺序步骤计划
    #[must_use]
    pub fn plan(task_type: TaskType) -> StepPlan {
        let steps = match task_type {
            TaskType::DirectAnswer => vec![StepKind::ModelReason, StepKind::FinalizeAnswer],
            TaskType::ContextAnswer => vec![
                StepKind::LoadContext,
                StepKind::ModelReason,
                StepKind::FinalizeAnswer,
            ],
            TaskType::RejectTask => vec![StepKind::FinalizeAnswer],
        };
        StepPlan::new(task_type, steps, ExecutionPolicy::for_task(task_type))
    }
}
