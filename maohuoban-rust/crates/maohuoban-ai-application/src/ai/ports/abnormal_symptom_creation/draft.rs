use chrono::{DateTime, Utc};

/// AbnormalSymptomCreationDraft Agent 异常创建草稿
/// 核心职责：
/// - 表达模型整理出的异常父记录候选
/// - 只用于创建确认任务，用户授权前不写事实账本
#[derive(Debug, Clone)]
pub struct AbnormalSymptomCreationDraft {
    pub occurred_at: DateTime<Utc>,
    pub symptom_kinds: Vec<String>,
    pub severity: String,
    pub note: String,
}
