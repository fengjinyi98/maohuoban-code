use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use super::PetErrorKind;

/// PetDietAssignment 宠物饮食配置
/// 核心职责：
/// - 表达某只宠物对储物柜食品资产的消费配置
/// - 同一宠物同一时间只能有一个 active current_staple
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct PetDietAssignment {
    pub id: Uuid,
    pub pet_id: Uuid,
    pub food_item_id: Uuid,
    pub role: DietAssignmentRole,
    pub status: DietAssignmentStatus,
    pub started_at: DateTime<Utc>,
    pub ended_at: Option<DateTime<Utc>>,
    pub reason: Option<String>,
    pub created_by_user_id: Uuid,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// DietAssignmentRole 饮食配置角色
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum DietAssignmentRole {
    CurrentStaple,
    Trying,
    UsualTreat,
    UsualNutrition,
    Backup,
    NotSuitable,
}

impl DietAssignmentRole {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::CurrentStaple => "current_staple",
            Self::Trying => "trying",
            Self::UsualTreat => "usual_treat",
            Self::UsualNutrition => "usual_nutrition",
            Self::Backup => "backup",
            Self::NotSuitable => "not_suitable",
        }
    }
}

impl TryFrom<&str> for DietAssignmentRole {
    type Error = PetErrorKind;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        match value {
            "current_staple" => Ok(Self::CurrentStaple),
            "trying" => Ok(Self::Trying),
            "usual_treat" => Ok(Self::UsualTreat),
            "usual_nutrition" => Ok(Self::UsualNutrition),
            "backup" => Ok(Self::Backup),
            "not_suitable" => Ok(Self::NotSuitable),
            _ => Err(PetErrorKind::DietAssignmentRole),
        }
    }
}

/// DietAssignmentStatus 饮食配置状态
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum DietAssignmentStatus {
    Active,
    Ended,
    Archived,
}

impl DietAssignmentStatus {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Active => "active",
            Self::Ended => "ended",
            Self::Archived => "archived",
        }
    }

    #[must_use]
    pub const fn is_active(self) -> bool {
        matches!(self, Self::Active)
    }
}

impl TryFrom<&str> for DietAssignmentStatus {
    type Error = PetErrorKind;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        match value {
            "active" => Ok(Self::Active),
            "ended" => Ok(Self::Ended),
            "archived" => Ok(Self::Archived),
            _ => Err(PetErrorKind::DietAssignmentStatus),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn diet_assignment_role_serializes_snake_case() {
        let value = serde_json::to_value(DietAssignmentRole::CurrentStaple).expect("serialize");
        assert_eq!(value, "current_staple");
    }

    #[test]
    fn diet_assignment_status_parses_active() {
        assert!(
            DietAssignmentStatus::try_from("active")
                .expect("parse")
                .is_active()
        );
        assert!(!DietAssignmentStatus::Ended.is_active());
    }
}
