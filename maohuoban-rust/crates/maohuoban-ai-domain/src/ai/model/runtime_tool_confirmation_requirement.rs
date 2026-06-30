use serde::{Deserialize, Serialize};

/// AiToolConfirmationRequirement 工具确认需求
/// 核心职责：
/// - 表达确认前不得执行的工具调用
/// - 保留确认任务、工具名、问题文案和原始参数
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AiToolConfirmationRequirement {
    pub confirmation_task_id: String,
    pub tool_name: String,
    pub question_text: String,
    pub args: serde_json::Value,
}
