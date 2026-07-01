use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// AiProposedActionRisk 建议动作风险等级
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AiProposedActionRisk {
    Low,
    Medium,
    High,
}

/// AiProposedActionKind 建议动作类型
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AiProposedActionKind {
    DietChangeConfirmation,
    FeedingCorrection,
    SymptomFollowup,
    ReminderCreation,
    RiskContextConfirmation,
}

/// AiProposedAction 建议写操作
/// 核心职责：
/// - 表达 Agent 建议的待确认动作，用户确认后才执行
/// - 不直接写 pet_events 强事实
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AiProposedAction {
    pub id: Uuid,
    pub action_kind: AiProposedActionKind,
    pub target_pet_id: Uuid,
    pub payload: serde_json::Value,
    pub confirm_text: String,
    pub risk_level: AiProposedActionRisk,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub source_message_id: Option<Uuid>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub confirmation_task_id: Option<Uuid>,
}

impl AiProposedAction {
    /// requires_confirmation 判断该动作是否必须用户确认
    pub fn requires_confirmation(&self) -> bool {
        true
    }
}
