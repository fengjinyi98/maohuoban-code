use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// ContextConfirmationTaskSummary 模型可见确认任务摘要
/// 核心职责：
/// - 只暴露 commit 阶段需要的最小确认任务信息
/// - 不暴露 candidate payload、内部状态字段或数据库结构
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ContextConfirmationTaskSummary {
    pub confirmation_task_id: Uuid,
    pub tool_name: String,
    pub question_text: String,
}
