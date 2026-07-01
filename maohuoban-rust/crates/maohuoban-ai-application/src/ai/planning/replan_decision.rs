use super::{ReplanAction, ReplanCause, TaskType};

/// ReplanDecision 重规划裁决结果
/// 核心职责：
/// - 记录失败原因对应的下一步动作
/// - 明确是否可重试以及是否改写为新的任务类型
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ReplanDecision {
    pub cause: ReplanCause,
    pub action: ReplanAction,
    pub retryable: bool,
    pub replanned_task_type: Option<TaskType>,
    pub reason: &'static str,
}

impl ReplanDecision {
    /// new 创建重规划裁决
    #[must_use]
    pub const fn new(
        cause: ReplanCause,
        action: ReplanAction,
        retryable: bool,
        replanned_task_type: Option<TaskType>,
    ) -> Self {
        Self {
            cause,
            action,
            retryable,
            replanned_task_type,
            reason: cause.as_str(),
        }
    }
}
