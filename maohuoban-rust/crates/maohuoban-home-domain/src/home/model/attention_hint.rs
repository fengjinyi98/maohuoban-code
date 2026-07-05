/// AttentionHint 首页轻提示
/// 核心职责：
/// - 承载首页待处理提示的稳定读模型
/// - 含 kind、tone、priority、sourceRef、route
/// - 让客户端可直接映射展示
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// AttentionHint 首页轻提示
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct AttentionHint {
    pub id: Uuid,
    pub pet_id: Uuid,
    pub kind: AttentionHintKind,
    pub title: String,
    pub subtitle: String,
    pub icon: String,
    pub tone: AttentionHintTone,
    pub priority: i32,
    pub status: AttentionHintStatus,
    pub source_ref_type: Option<String>,
    pub source_ref_id: Option<Uuid>,
    pub route: AttentionHintRoute,
    pub display_from: Option<DateTime<Utc>>,
    pub display_until: Option<DateTime<Utc>>,
    pub created_by: AttentionHintCreator,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub resolved_at: Option<DateTime<Utc>>,
}

/// AttentionHintKind 轻提示类型
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum AttentionHintKind {
    OpenAbnormalEpisode,
    AbnormalFollowupDue,
    DietChangeConfirmation,
    PreventiveCareDue,
    ReminderDue,
    WeightStale,
    FeedingPatternChanged,
}

/// AttentionHintTone 轻提示色调
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum AttentionHintTone {
    Info,
    Notice,
    Warning,
    Critical,
}

/// AttentionHintStatus 轻提示状态
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum AttentionHintStatus {
    Active,
    Dismissed,
    Resolved,
    Expired,
}

/// AttentionHintRoute 轻提示点击路由
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct AttentionHintRoute {
    pub kind: AttentionHintRouteKind,
    pub payload: Option<serde_json::Value>,
}

/// AttentionHintRouteKind 路由类型
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum AttentionHintRouteKind {
    AbnormalDetail,
    ConfirmationTask,
    ReminderDetail,
    PreventiveCareDetail,
    WeightRecord,
    AiChat,
}

/// AttentionHintCreator 创建来源
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum AttentionHintCreator {
    System,
    Agent,
    User,
    BusinessRule,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn attention_hint_kind_serialization() {
        assert_eq!(
            serde_json::to_string(&AttentionHintKind::OpenAbnormalEpisode).unwrap(),
            "\"open_abnormal_episode\""
        );
        assert_eq!(
            serde_json::to_string(&AttentionHintKind::AbnormalFollowupDue).unwrap(),
            "\"abnormal_followup_due\""
        );
        assert_eq!(
            serde_json::to_string(&AttentionHintKind::DietChangeConfirmation).unwrap(),
            "\"diet_change_confirmation\""
        );
        assert_eq!(
            serde_json::to_string(&AttentionHintKind::PreventiveCareDue).unwrap(),
            "\"preventive_care_due\""
        );
        assert_eq!(
            serde_json::to_string(&AttentionHintKind::ReminderDue).unwrap(),
            "\"reminder_due\""
        );
        assert_eq!(
            serde_json::to_string(&AttentionHintKind::WeightStale).unwrap(),
            "\"weight_stale\""
        );
        assert_eq!(
            serde_json::to_string(&AttentionHintKind::FeedingPatternChanged).unwrap(),
            "\"feeding_pattern_changed\""
        );
    }

    #[test]
    fn attention_hint_kind_deserialization() {
        assert_eq!(
            serde_json::from_str::<AttentionHintKind>("\"open_abnormal_episode\"").unwrap(),
            AttentionHintKind::OpenAbnormalEpisode
        );
        assert_eq!(
            serde_json::from_str::<AttentionHintKind>("\"abnormal_followup_due\"").unwrap(),
            AttentionHintKind::AbnormalFollowupDue
        );
        assert_eq!(
            serde_json::from_str::<AttentionHintKind>("\"diet_change_confirmation\"").unwrap(),
            AttentionHintKind::DietChangeConfirmation
        );
        assert_eq!(
            serde_json::from_str::<AttentionHintKind>("\"preventive_care_due\"").unwrap(),
            AttentionHintKind::PreventiveCareDue
        );
        assert_eq!(
            serde_json::from_str::<AttentionHintKind>("\"reminder_due\"").unwrap(),
            AttentionHintKind::ReminderDue
        );
        assert_eq!(
            serde_json::from_str::<AttentionHintKind>("\"weight_stale\"").unwrap(),
            AttentionHintKind::WeightStale
        );
        assert_eq!(
            serde_json::from_str::<AttentionHintKind>("\"feeding_pattern_changed\"").unwrap(),
            AttentionHintKind::FeedingPatternChanged
        );
    }

    #[test]
    fn attention_hint_tone_serialization() {
        assert_eq!(
            serde_json::to_string(&AttentionHintTone::Info).unwrap(),
            "\"info\""
        );
        assert_eq!(
            serde_json::to_string(&AttentionHintTone::Notice).unwrap(),
            "\"notice\""
        );
        assert_eq!(
            serde_json::to_string(&AttentionHintTone::Warning).unwrap(),
            "\"warning\""
        );
        assert_eq!(
            serde_json::to_string(&AttentionHintTone::Critical).unwrap(),
            "\"critical\""
        );
    }

    #[test]
    fn attention_hint_status_serialization() {
        assert_eq!(
            serde_json::to_string(&AttentionHintStatus::Active).unwrap(),
            "\"active\""
        );
        assert_eq!(
            serde_json::to_string(&AttentionHintStatus::Dismissed).unwrap(),
            "\"dismissed\""
        );
        assert_eq!(
            serde_json::to_string(&AttentionHintStatus::Resolved).unwrap(),
            "\"resolved\""
        );
        assert_eq!(
            serde_json::to_string(&AttentionHintStatus::Expired).unwrap(),
            "\"expired\""
        );
    }

    #[test]
    fn attention_hint_route_kind_serialization() {
        assert_eq!(
            serde_json::to_string(&AttentionHintRouteKind::AbnormalDetail).unwrap(),
            "\"abnormal_detail\""
        );
        assert_eq!(
            serde_json::to_string(&AttentionHintRouteKind::ConfirmationTask).unwrap(),
            "\"confirmation_task\""
        );
        assert_eq!(
            serde_json::to_string(&AttentionHintRouteKind::ReminderDetail).unwrap(),
            "\"reminder_detail\""
        );
        assert_eq!(
            serde_json::to_string(&AttentionHintRouteKind::PreventiveCareDetail).unwrap(),
            "\"preventive_care_detail\""
        );
        assert_eq!(
            serde_json::to_string(&AttentionHintRouteKind::WeightRecord).unwrap(),
            "\"weight_record\""
        );
        assert_eq!(
            serde_json::to_string(&AttentionHintRouteKind::AiChat).unwrap(),
            "\"ai_chat\""
        );
    }

    #[test]
    fn attention_hint_creator_serialization() {
        assert_eq!(
            serde_json::to_string(&AttentionHintCreator::System).unwrap(),
            "\"system\""
        );
        assert_eq!(
            serde_json::to_string(&AttentionHintCreator::Agent).unwrap(),
            "\"agent\""
        );
        assert_eq!(
            serde_json::to_string(&AttentionHintCreator::User).unwrap(),
            "\"user\""
        );
        assert_eq!(
            serde_json::to_string(&AttentionHintCreator::BusinessRule).unwrap(),
            "\"business_rule\""
        );
    }

    #[test]
    fn attention_hint_full_roundtrip() {
        let hint = AttentionHint {
            id: Uuid::nil(),
            pet_id: Uuid::nil(),
            kind: AttentionHintKind::OpenAbnormalEpisode,
            title: "未关闭异常".to_string(),
            subtitle: "点点查看详情".to_string(),
            icon: "exclamationmark.circle".to_string(),
            tone: AttentionHintTone::Warning,
            priority: 10,
            status: AttentionHintStatus::Active,
            source_ref_type: Some("abnormal_episode".to_string()),
            source_ref_id: Some(Uuid::nil()),
            route: AttentionHintRoute {
                kind: AttentionHintRouteKind::AbnormalDetail,
                payload: Some(serde_json::json!({"episode_id": Uuid::nil()})),
            },
            display_from: None,
            display_until: None,
            created_by: AttentionHintCreator::System,
            created_at: DateTime::from_timestamp_nanos(0),
            updated_at: DateTime::from_timestamp_nanos(0),
            resolved_at: None,
        };

        let json = serde_json::to_string(&hint).unwrap();
        let deserialized: AttentionHint = serde_json::from_str(&json).unwrap();
        assert_eq!(hint, deserialized);
    }

    #[test]
    fn attention_hint_unknown_kind_rejected() {
        let result = serde_json::from_str::<AttentionHintKind>("\"unknown_kind\"");
        assert!(result.is_err());
    }

    #[test]
    fn attention_hint_unknown_tone_rejected() {
        let result = serde_json::from_str::<AttentionHintTone>("\"mega_critical\"");
        assert!(result.is_err());
    }

    #[test]
    fn attention_hint_unknown_status_rejected() {
        let result = serde_json::from_str::<AttentionHintStatus>("\"unknown_status\"");
        assert!(result.is_err());
    }

    #[test]
    fn attention_hint_unknown_route_kind_rejected() {
        let result = serde_json::from_str::<AttentionHintRouteKind>("\"some_unknown_route\"");
        assert!(result.is_err());
    }
}
