use chrono::{DateTime, Utc};

/// AbnormalFollowupPlanDraft Agent 异常追踪计划草稿
/// 核心职责：
/// - 承载模型生成的下一轮追踪时间、文案和动作建议
/// - 只作为候选输入，最终保存由 application service 校验
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AbnormalFollowupPlanDraft {
    pub due_at: DateTime<Utc>,
    pub message_title: String,
    pub message_body: String,
    pub rationale: String,
    pub recommended_actions: Vec<String>,
}
