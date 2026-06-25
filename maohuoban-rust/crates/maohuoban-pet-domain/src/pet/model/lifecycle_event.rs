// pet_lifecycle_event 宠物生命周期事件领域模型
// 核心职责：
// - 用追加事件表达创建、转移、领养、标记去世、恢复、归档等变化
// - 去世不删除档案，只更新 life_status 并追加事件

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use super::PetErrorKind;

/// PetLifecycleEvent 宠物生命周期事件
/// 核心职责：
/// - 记录宠物生命状态变化的关键时刻
/// - 保留操作人、来源主体、单据引用等审计信息
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct PetLifecycleEvent {
    pub id: Uuid,
    pub pet_id: Uuid,
    pub event_kind: LifecycleEventKind,
    pub from_guardian_type: Option<String>,
    pub from_guardian_id: Option<Uuid>,
    pub to_guardian_type: Option<String>,
    pub to_guardian_id: Option<Uuid>,
    pub actor_user_id: Option<Uuid>,
    pub source_ref_type: Option<String>,
    pub source_ref_id: Option<Uuid>,
    pub note: Option<String>,
    pub occurred_at: DateTime<Utc>,
    pub created_at: DateTime<Utc>,
}

/// LifecycleEventKind 生命周期事件类型
/// 核心职责：
/// - 区分不同生命阶段变化
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum LifecycleEventKind {
    Created,
    Imported,
    Transferred,
    Adopted,
    MarkedDeceased,
    Restored,
    Archived,
    GuardianAdded,
    GuardianRevoked,
}

impl LifecycleEventKind {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Created => "created",
            Self::Imported => "imported",
            Self::Transferred => "transferred",
            Self::Adopted => "adopted",
            Self::MarkedDeceased => "marked_deceased",
            Self::Restored => "restored",
            Self::Archived => "archived",
            Self::GuardianAdded => "guardian_added",
            Self::GuardianRevoked => "guardian_revoked",
        }
    }
}

impl TryFrom<&str> for LifecycleEventKind {
    type Error = PetErrorKind;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        match value {
            "created" => Ok(Self::Created),
            "imported" => Ok(Self::Imported),
            "transferred" => Ok(Self::Transferred),
            "adopted" => Ok(Self::Adopted),
            "marked_deceased" => Ok(Self::MarkedDeceased),
            "restored" => Ok(Self::Restored),
            "archived" => Ok(Self::Archived),
            "guardian_added" => Ok(Self::GuardianAdded),
            "guardian_revoked" => Ok(Self::GuardianRevoked),
            _ => Err(PetErrorKind::LifecycleEventKind),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn lifecycle_event_kind_all_variants() {
        assert_eq!(LifecycleEventKind::Created.as_str(), "created");
        assert_eq!(LifecycleEventKind::Imported.as_str(), "imported");
        assert_eq!(LifecycleEventKind::Transferred.as_str(), "transferred");
        assert_eq!(LifecycleEventKind::Adopted.as_str(), "adopted");
        assert_eq!(
            LifecycleEventKind::MarkedDeceased.as_str(),
            "marked_deceased"
        );
        assert_eq!(LifecycleEventKind::Restored.as_str(), "restored");
        assert_eq!(LifecycleEventKind::Archived.as_str(), "archived");
        assert_eq!(LifecycleEventKind::GuardianAdded.as_str(), "guardian_added");
        assert_eq!(
            LifecycleEventKind::GuardianRevoked.as_str(),
            "guardian_revoked"
        );
    }

    #[test]
    fn lifecycle_event_kind_try_from_valid() {
        assert_eq!(
            LifecycleEventKind::try_from("created").unwrap(),
            LifecycleEventKind::Created
        );
        assert_eq!(
            LifecycleEventKind::try_from("marked_deceased").unwrap(),
            LifecycleEventKind::MarkedDeceased
        );
    }

    #[test]
    fn lifecycle_event_kind_try_from_invalid() {
        assert!(LifecycleEventKind::try_from("deleted").is_err());
    }

    fn sample_event(kind: LifecycleEventKind) -> PetLifecycleEvent {
        PetLifecycleEvent {
            id: Uuid::new_v4(),
            pet_id: Uuid::new_v4(),
            event_kind: kind,
            from_guardian_type: None,
            from_guardian_id: None,
            to_guardian_type: None,
            to_guardian_id: None,
            actor_user_id: Some(Uuid::new_v4()),
            source_ref_type: None,
            source_ref_id: None,
            note: None,
            occurred_at: Utc::now(),
            created_at: Utc::now(),
        }
    }

    #[test]
    fn lifecycle_event_created_has_pet_ref() {
        let event = sample_event(LifecycleEventKind::Created);
        assert!(!event.pet_id.is_nil());
    }

    #[test]
    fn lifecycle_event_marked_deceased_preserves_pet_id() {
        let event = sample_event(LifecycleEventKind::MarkedDeceased);
        assert!(!event.pet_id.is_nil());
        assert!(event.actor_user_id.is_some());
    }

    #[test]
    fn lifecycle_event_transferred_has_guardian_refs() {
        let event = PetLifecycleEvent {
            from_guardian_type: Some("user".into()),
            from_guardian_id: Some(Uuid::new_v4()),
            to_guardian_type: Some("user".into()),
            to_guardian_id: Some(Uuid::new_v4()),
            ..sample_event(LifecycleEventKind::Transferred)
        };
        assert!(event.from_guardian_id.is_some());
        assert!(event.to_guardian_id.is_some());
    }
}
