// pet_guardian 宠物归属关系领域模型
// 核心职责：
// - 承载用户、商家、共管者与宠物的当前/历史关系
// - 不复制宠物主数据，只表达 pet_id 与主体之间的关系

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use super::PetErrorKind;

/// PetGuardian 宠物归属关系
/// 核心职责：
/// - 绑定一个主体（用户或商家）与宠物的关系
/// - 支持 owner/co_caretaker/merchant_manager/previous_owner 角色
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct PetGuardian {
    pub id: Uuid,
    pub pet_id: Uuid,
    pub guardian_type: GuardianType,
    pub guardian_user_id: Option<Uuid>,
    pub guardian_merchant_id: Option<Uuid>,
    pub role: GuardianRole,
    pub status: GuardianStatus,
    pub started_at: DateTime<Utc>,
    pub ended_at: Option<DateTime<Utc>>,
    pub granted_by_user_id: Option<Uuid>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// GuardianType 归属主体类型
/// 核心职责：
/// - 区分用户归属和商家管理
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum GuardianType {
    User,
    Merchant,
}

impl GuardianType {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::User => "user",
            Self::Merchant => "merchant",
        }
    }
}

impl TryFrom<&str> for GuardianType {
    type Error = PetErrorKind;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        match value {
            "user" => Ok(Self::User),
            "merchant" => Ok(Self::Merchant),
            _ => Err(PetErrorKind::GuardianType),
        }
    }
}

/// GuardianRole 归属角色
/// 核心职责：
/// - 区分 owner、co_caretaker、merchant_manager、previous_owner
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum GuardianRole {
    Owner,
    CoCaretaker,
    MerchantManager,
    PreviousOwner,
}

impl GuardianRole {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Owner => "owner",
            Self::CoCaretaker => "co_caretaker",
            Self::MerchantManager => "merchant_manager",
            Self::PreviousOwner => "previous_owner",
        }
    }
}

impl TryFrom<&str> for GuardianRole {
    type Error = PetErrorKind;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        match value {
            "owner" => Ok(Self::Owner),
            "co_caretaker" => Ok(Self::CoCaretaker),
            "merchant_manager" => Ok(Self::MerchantManager),
            "previous_owner" => Ok(Self::PreviousOwner),
            _ => Err(PetErrorKind::GuardianRole),
        }
    }
}

/// GuardianStatus 关系状态
/// 核心职责：
/// - 区分 active/transferred/revoked/archived
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum GuardianStatus {
    Active,
    Transferred,
    Revoked,
    Archived,
}

impl GuardianStatus {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Active => "active",
            Self::Transferred => "transferred",
            Self::Revoked => "revoked",
            Self::Archived => "archived",
        }
    }
}

impl TryFrom<&str> for GuardianStatus {
    type Error = PetErrorKind;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        match value {
            "active" => Ok(Self::Active),
            "transferred" => Ok(Self::Transferred),
            "revoked" => Ok(Self::Revoked),
            "archived" => Ok(Self::Archived),
            _ => Err(PetErrorKind::GuardianStatus),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // ── GuardianType ──

    #[test]
    fn guardian_type_as_str() {
        assert_eq!(GuardianType::User.as_str(), "user");
        assert_eq!(GuardianType::Merchant.as_str(), "merchant");
    }

    #[test]
    fn guardian_type_try_from_valid() {
        assert_eq!(GuardianType::try_from("user").unwrap(), GuardianType::User);
        assert_eq!(
            GuardianType::try_from("merchant").unwrap(),
            GuardianType::Merchant
        );
    }

    #[test]
    fn guardian_type_try_from_invalid() {
        assert!(GuardianType::try_from("admin").is_err());
    }

    // ── GuardianRole ──

    #[test]
    fn guardian_role_all_variants() {
        assert_eq!(GuardianRole::Owner.as_str(), "owner");
        assert_eq!(GuardianRole::CoCaretaker.as_str(), "co_caretaker");
        assert_eq!(GuardianRole::MerchantManager.as_str(), "merchant_manager");
        assert_eq!(GuardianRole::PreviousOwner.as_str(), "previous_owner");
    }

    #[test]
    fn guardian_role_try_from_valid() {
        assert_eq!(
            GuardianRole::try_from("owner").unwrap(),
            GuardianRole::Owner
        );
        assert_eq!(
            GuardianRole::try_from("co_caretaker").unwrap(),
            GuardianRole::CoCaretaker
        );
    }

    #[test]
    fn guardian_role_try_from_invalid() {
        assert!(GuardianRole::try_from("admin").is_err());
    }

    // ── GuardianStatus ──

    #[test]
    fn guardian_status_all_variants() {
        assert_eq!(GuardianStatus::Active.as_str(), "active");
        assert_eq!(GuardianStatus::Transferred.as_str(), "transferred");
        assert_eq!(GuardianStatus::Revoked.as_str(), "revoked");
        assert_eq!(GuardianStatus::Archived.as_str(), "archived");
    }

    #[test]
    fn guardian_status_try_from_invalid() {
        assert!(GuardianStatus::try_from("deleted").is_err());
    }

    // ── PetGuardian 构造契约 ──

    fn sample_guardian() -> PetGuardian {
        PetGuardian {
            id: Uuid::new_v4(),
            pet_id: Uuid::new_v4(),
            guardian_type: GuardianType::User,
            guardian_user_id: Some(Uuid::new_v4()),
            guardian_merchant_id: None,
            role: GuardianRole::Owner,
            status: GuardianStatus::Active,
            started_at: Utc::now(),
            ended_at: None,
            granted_by_user_id: None,
            created_at: Utc::now(),
            updated_at: Utc::now(),
        }
    }

    #[test]
    fn pet_guardian_owner_active_by_default() {
        let g = sample_guardian();
        assert_eq!(g.role, GuardianRole::Owner);
        assert_eq!(g.status, GuardianStatus::Active);
    }

    #[test]
    fn pet_guardian_references_pet_id() {
        let g = sample_guardian();
        assert!(!g.pet_id.is_nil());
    }

    #[test]
    fn pet_guardian_co_caretaker_can_be_active() {
        let g = PetGuardian {
            role: GuardianRole::CoCaretaker,
            ..sample_guardian()
        };
        assert_eq!(g.role, GuardianRole::CoCaretaker);
        assert_eq!(g.status, GuardianStatus::Active);
    }

    #[test]
    fn pet_guardian_can_be_transferred() {
        let g = PetGuardian {
            status: GuardianStatus::Transferred,
            ended_at: Some(Utc::now()),
            ..sample_guardian()
        };
        assert_eq!(g.status, GuardianStatus::Transferred);
        assert!(g.ended_at.is_some());
    }

    #[test]
    fn pet_guardian_merchant_manager_has_merchant_id() {
        let g = PetGuardian {
            guardian_type: GuardianType::Merchant,
            guardian_user_id: None,
            guardian_merchant_id: Some(Uuid::new_v4()),
            role: GuardianRole::MerchantManager,
            ..sample_guardian()
        };
        assert_eq!(g.guardian_type, GuardianType::Merchant);
        assert!(g.guardian_merchant_id.is_some());
    }
}
