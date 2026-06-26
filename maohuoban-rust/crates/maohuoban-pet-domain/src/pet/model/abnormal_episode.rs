#![allow(dead_code)]

// AbnormalEpisode 异常追踪 Episode 领域模型
// 核心职责：
// - 定义异常 episode 的状态机、主症状和严重程度枚举
// - 支持序列化和反序列化，与后端存储契约一致
// - 让追踪链（追加观察、就诊、恢复、关闭）有稳定领域抽象

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// AbnormalEpisode 异常追踪 Episode
/// 核心职责：
/// - 把异常记录、追加观察、就诊、恢复串成一个闭环
/// - 所有 pet_events 通过 episode_id 追踪到同一 episode
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct AbnormalEpisode {
    pub id: Uuid,
    pub pet_id: Uuid,
    pub status: AbnormalEpisodeStatus,
    pub primary_symptom_kind: SymptomKind,
    pub symptom_kinds: Vec<SymptomKind>,
    pub severity: Severity,
    pub started_at: DateTime<Utc>,
    pub last_observed_at: Option<DateTime<Utc>>,
    pub recovered_at: Option<DateTime<Utc>>,
    pub created_by_user_id: Uuid,
    pub created_event_id: Uuid,
    pub latest_event_id: Option<Uuid>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// AbnormalEpisodeStatus 异常 Episode 状态
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum AbnormalEpisodeStatus {
    Open,
    Watching,
    Recovering,
    Recovered,
    Escalated,
    Closed,
}

/// SymptomKind 症状类型
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum SymptomKind {
    Appetite,
    Energy,
    Stool,
    Vomit,
    Skin,
    Eye,
    Ear,
    Mouth,
    Respiratory,
    Urinary,
    Mobility,
    Weight,
    Behavior,
    Other,
}

/// Severity 严重程度
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum Severity {
    Mild,
    Obvious,
    Severe,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn abnormal_episode_status_serialization() {
        assert_eq!(
            serde_json::to_string(&AbnormalEpisodeStatus::Open).unwrap(),
            "\"open\""
        );
        assert_eq!(
            serde_json::to_string(&AbnormalEpisodeStatus::Watching).unwrap(),
            "\"watching\""
        );
        assert_eq!(
            serde_json::to_string(&AbnormalEpisodeStatus::Recovering).unwrap(),
            "\"recovering\""
        );
        assert_eq!(
            serde_json::to_string(&AbnormalEpisodeStatus::Recovered).unwrap(),
            "\"recovered\""
        );
        assert_eq!(
            serde_json::to_string(&AbnormalEpisodeStatus::Escalated).unwrap(),
            "\"escalated\""
        );
        assert_eq!(
            serde_json::to_string(&AbnormalEpisodeStatus::Closed).unwrap(),
            "\"closed\""
        );
    }

    #[test]
    fn symptom_kind_serialization() {
        assert_eq!(
            serde_json::to_string(&SymptomKind::Appetite).unwrap(),
            "\"appetite\""
        );
        assert_eq!(
            serde_json::to_string(&SymptomKind::Energy).unwrap(),
            "\"energy\""
        );
        assert_eq!(
            serde_json::to_string(&SymptomKind::Stool).unwrap(),
            "\"stool\""
        );
    }

    #[test]
    fn severity_serialization() {
        assert_eq!(serde_json::to_string(&Severity::Mild).unwrap(), "\"mild\"");
        assert_eq!(
            serde_json::to_string(&Severity::Obvious).unwrap(),
            "\"obvious\""
        );
        assert_eq!(
            serde_json::to_string(&Severity::Severe).unwrap(),
            "\"severe\""
        );
    }

    #[test]
    fn abnormal_episode_full_roundtrip() {
        let episode = AbnormalEpisode {
            id: Uuid::nil(),
            pet_id: Uuid::nil(),
            status: AbnormalEpisodeStatus::Open,
            primary_symptom_kind: SymptomKind::Appetite,
            symptom_kinds: vec![SymptomKind::Appetite, SymptomKind::Energy],
            severity: Severity::Obvious,
            started_at: DateTime::from_timestamp_nanos(0),
            last_observed_at: None,
            recovered_at: None,
            created_by_user_id: Uuid::nil(),
            created_event_id: Uuid::nil(),
            latest_event_id: None,
            created_at: DateTime::from_timestamp_nanos(0),
            updated_at: DateTime::from_timestamp_nanos(0),
        };

        let json = serde_json::to_string(&episode).unwrap();
        let deserialized: AbnormalEpisode = serde_json::from_str(&json).unwrap();
        assert_eq!(episode, deserialized);
    }

    #[test]
    fn abnormal_episode_recovered_state_transition() {
        let mut episode = AbnormalEpisode {
            id: Uuid::nil(),
            pet_id: Uuid::nil(),
            status: AbnormalEpisodeStatus::Open,
            primary_symptom_kind: SymptomKind::Vomit,
            symptom_kinds: vec![SymptomKind::Vomit],
            severity: Severity::Mild,
            started_at: DateTime::from_timestamp_nanos(0),
            last_observed_at: Some(DateTime::from_timestamp_nanos(0)),
            recovered_at: None,
            created_by_user_id: Uuid::nil(),
            created_event_id: Uuid::nil(),
            latest_event_id: None,
            created_at: DateTime::from_timestamp_nanos(0),
            updated_at: DateTime::from_timestamp_nanos(0),
        };

        episode.status = AbnormalEpisodeStatus::Recovered;
        episode.recovered_at = Some(DateTime::from_timestamp_nanos(1));

        let json = serde_json::to_string(&episode).unwrap();
        let deserialized: AbnormalEpisode = serde_json::from_str(&json).unwrap();
        assert_eq!(deserialized.status, AbnormalEpisodeStatus::Recovered);
        assert!(deserialized.recovered_at.is_some());
    }

    #[test]
    fn abnormal_episode_unknown_status_rejected() {
        let result = serde_json::from_str::<AbnormalEpisodeStatus>("\"unknown_status\"");
        assert!(result.is_err());
    }

    #[test]
    fn abnormal_episode_unknown_symptom_rejected() {
        let result = serde_json::from_str::<SymptomKind>("\"unknown_symptom\"");
        assert!(result.is_err());
    }

    #[test]
    fn abnormal_episode_unknown_severity_rejected() {
        let result = serde_json::from_str::<Severity>("\"unknown_severity\"");
        assert!(result.is_err());
    }
}
