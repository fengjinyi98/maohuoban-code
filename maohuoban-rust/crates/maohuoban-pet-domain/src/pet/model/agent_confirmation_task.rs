// AgentConfirmationTask 毛球 Agent 结构化确认任务
// 核心职责：
// - 承载毛球 Agent 的结构化追问任务，包括饮食变化确认、症状追问、风险上下文确认
// - 不自动写入聊天消息；用户确认后才写 pet_events
// - 可被首页轻提示、通知、聊天入口复用

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// AgentConfirmationTask 结构化确认任务
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct AgentConfirmationTask {
    pub id: Uuid,
    pub pet_id: Uuid,
    pub task_kind: ConfirmationTaskKind,
    pub question_text: String,
    pub candidate_payload: Option<serde_json::Value>,
    pub source_hint_id: Option<Uuid>,
    pub source_ref_type: Option<String>,
    pub source_ref_id: Option<Uuid>,
    pub status: ConfirmationTaskStatus,
    pub answer_payload: Option<serde_json::Value>,
    pub resolved_event_id: Option<Uuid>,
    pub created_at: DateTime<Utc>,
    pub resolved_at: Option<DateTime<Utc>>,
}

/// ConfirmationTaskKind 确认任务类型
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum ConfirmationTaskKind {
    DietChangeConfirmation,
    SymptomFollowup,
    AbnormalSymptomCreation,
    AbnormalRecovery,
    RiskContextConfirmation,
}

/// ConfirmationTaskStatus 确认任务状态
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum ConfirmationTaskStatus {
    Pending,
    Answered,
    Dismissed,
    Expired,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn confirmation_task_kind_serialization() {
        assert_eq!(
            serde_json::to_string(&ConfirmationTaskKind::DietChangeConfirmation).unwrap(),
            "\"diet_change_confirmation\""
        );
        assert_eq!(
            serde_json::to_string(&ConfirmationTaskKind::SymptomFollowup).unwrap(),
            "\"symptom_followup\""
        );
        assert_eq!(
            serde_json::to_string(&ConfirmationTaskKind::AbnormalSymptomCreation).unwrap(),
            "\"abnormal_symptom_creation\""
        );
        assert_eq!(
            serde_json::to_string(&ConfirmationTaskKind::AbnormalRecovery).unwrap(),
            "\"abnormal_recovery\""
        );
        assert_eq!(
            serde_json::to_string(&ConfirmationTaskKind::RiskContextConfirmation).unwrap(),
            "\"risk_context_confirmation\""
        );
    }

    #[test]
    fn confirmation_task_kind_deserialization() {
        assert_eq!(
            serde_json::from_str::<ConfirmationTaskKind>("\"diet_change_confirmation\"").unwrap(),
            ConfirmationTaskKind::DietChangeConfirmation
        );
        assert_eq!(
            serde_json::from_str::<ConfirmationTaskKind>("\"symptom_followup\"").unwrap(),
            ConfirmationTaskKind::SymptomFollowup
        );
        assert_eq!(
            serde_json::from_str::<ConfirmationTaskKind>("\"abnormal_symptom_creation\"").unwrap(),
            ConfirmationTaskKind::AbnormalSymptomCreation
        );
        assert_eq!(
            serde_json::from_str::<ConfirmationTaskKind>("\"abnormal_recovery\"").unwrap(),
            ConfirmationTaskKind::AbnormalRecovery
        );
        assert_eq!(
            serde_json::from_str::<ConfirmationTaskKind>("\"risk_context_confirmation\"").unwrap(),
            ConfirmationTaskKind::RiskContextConfirmation
        );
    }

    #[test]
    fn confirmation_task_unknown_kind_rejected() {
        let result = serde_json::from_str::<ConfirmationTaskKind>("\"invalid_kind\"");
        assert!(result.is_err());
    }

    #[test]
    fn confirmation_task_status_serialization() {
        assert_eq!(
            serde_json::to_string(&ConfirmationTaskStatus::Pending).unwrap(),
            "\"pending\""
        );
        assert_eq!(
            serde_json::to_string(&ConfirmationTaskStatus::Answered).unwrap(),
            "\"answered\""
        );
        assert_eq!(
            serde_json::to_string(&ConfirmationTaskStatus::Dismissed).unwrap(),
            "\"dismissed\""
        );
        assert_eq!(
            serde_json::to_string(&ConfirmationTaskStatus::Expired).unwrap(),
            "\"expired\""
        );
    }

    #[test]
    fn confirmation_task_unknown_status_rejected() {
        let result = serde_json::from_str::<ConfirmationTaskStatus>("\"unknown_status\"");
        assert!(result.is_err());
    }

    #[test]
    fn confirmation_task_full_roundtrip() {
        let task = AgentConfirmationTask {
            id: Uuid::nil(),
            pet_id: Uuid::nil(),
            task_kind: ConfirmationTaskKind::DietChangeConfirmation,
            question_text: "最近是否更换了主粮？".to_string(),
            candidate_payload: Some(serde_json::json!({
                "new_brand": "渴望六种鱼",
                "old_brand": "皇家奶糕",
                "inventory_changed": true
            })),
            source_hint_id: Some(Uuid::nil()),
            source_ref_type: Some("food_inventory_change".to_string()),
            source_ref_id: Some(Uuid::nil()),
            status: ConfirmationTaskStatus::Pending,
            answer_payload: None,
            resolved_event_id: None,
            created_at: DateTime::from_timestamp_nanos(0),
            resolved_at: None,
        };

        let json = serde_json::to_string(&task).unwrap();
        let deserialized: AgentConfirmationTask = serde_json::from_str(&json).unwrap();
        assert_eq!(task, deserialized);
    }

    #[test]
    fn confirmation_task_answered_state() {
        let task = AgentConfirmationTask {
            id: Uuid::nil(),
            pet_id: Uuid::nil(),
            task_kind: ConfirmationTaskKind::SymptomFollowup,
            question_text: "点击后症状是否好转？".to_string(),
            candidate_payload: None,
            source_hint_id: None,
            source_ref_type: Some("abnormal_episode".to_string()),
            source_ref_id: Some(Uuid::nil()),
            status: ConfirmationTaskStatus::Answered,
            answer_payload: Some(serde_json::json!({
                "confirmed": true,
                "note": "精神好转，食欲恢复"
            })),
            resolved_event_id: Some(Uuid::nil()),
            created_at: DateTime::from_timestamp_nanos(0),
            resolved_at: Some(DateTime::from_timestamp_nanos(1)),
        };

        let json = serde_json::to_string(&task).unwrap();
        let deserialized: AgentConfirmationTask = serde_json::from_str(&json).unwrap();
        assert_eq!(deserialized.status, ConfirmationTaskStatus::Answered);
        assert!(deserialized.answer_payload.is_some());
        assert!(deserialized.resolved_at.is_some());
    }
}
