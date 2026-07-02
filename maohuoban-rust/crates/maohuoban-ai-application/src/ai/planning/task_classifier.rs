use super::{TaskClassificationInput, TaskType};

/// TaskClassifier 轻任务分类器
/// 核心职责：
/// - 只承接安全 Gate 与 Runtime 上下文边界
/// - 避免把用户文案分词成领域任务规划
pub struct TaskClassifier;

impl TaskClassifier {
    /// classify 根据 gate 与运行时信号分类任务
    #[must_use]
    pub fn classify(input: &TaskClassificationInput<'_>) -> TaskType {
        if !input.gate_decision.allow_processing() {
            return TaskType::RejectTask;
        }
        if input.confirmation_task_present && input.write_tool_visible {
            return TaskType::ConfirmationCommit;
        }

        Self::classify_runtime(
            input.selected_pet_present || input.gate_decision.context_loaded,
            input.confirmation_task_present,
        )
    }

    /// classify_runtime 根据 Runtime 可见信号分类任务
    /// 核心职责：
    /// - 只区分通用模型回答和已授权上下文模型回答
    /// - 保持入口 Intent Gate 作为安全裁决来源
    #[must_use]
    pub fn classify_runtime(
        selected_pet_present: bool,
        confirmation_task_present: bool,
    ) -> TaskType {
        if confirmation_task_present {
            return TaskType::ConfirmationCommit;
        }
        if selected_pet_present {
            return TaskType::ContextAnswer;
        }
        TaskType::DirectAnswer
    }
}
