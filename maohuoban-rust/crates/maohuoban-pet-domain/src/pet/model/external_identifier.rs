// pet_external_identifier 宠物外部标识领域模型
// 核心职责：
// - 承载芯片号等外部标识，与 pet_id 绑定
// - 支持验证状态、争议状态和历史追溯
// - 不替代 pet_profiles.id 作为宠物唯一身份

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use super::PetErrorKind;

/// PetExternalIdentifier 宠物外部标识
/// 核心职责：
/// - 将芯片号等外部标识与宠物绑定
/// - 支持标识生命周期（active/replaced/disputed/removed）
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct PetExternalIdentifier {
    pub id: Uuid,
    pub pet_id: Uuid,
    pub identifier_type: IdentifierType,
    pub identifier_value: String,
    pub issuer: Option<String>,
    pub issued_at: Option<DateTime<Utc>>,
    pub verified_status: VerifiedStatus,
    pub status: IdentifierStatus,
    pub evidence_asset_id: Option<Uuid>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// IdentifierType 外部标识类型
/// 核心职责：
/// - 区分芯片号、耳号、证书号等不同外部标识
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum IdentifierType {
    Microchip,
}

impl IdentifierType {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Microchip => "microchip",
        }
    }
}

impl TryFrom<&str> for IdentifierType {
    type Error = PetErrorKind;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        match value {
            "microchip" => Ok(Self::Microchip),
            _ => Err(PetErrorKind::IdentifierType),
        }
    }
}

/// VerifiedStatus 验证状态
/// 核心职责：
/// - 区分用户自报、系统验证、人工审核等不同可信度
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum VerifiedStatus {
    Unverified,
    SelfReported,
    Verified,
    Rejected,
}

impl VerifiedStatus {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Unverified => "unverified",
            Self::SelfReported => "self_reported",
            Self::Verified => "verified",
            Self::Rejected => "rejected",
        }
    }
}

impl TryFrom<&str> for VerifiedStatus {
    type Error = PetErrorKind;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        match value {
            "unverified" => Ok(Self::Unverified),
            "self_reported" => Ok(Self::SelfReported),
            "verified" => Ok(Self::Verified),
            "rejected" => Ok(Self::Rejected),
            _ => Err(PetErrorKind::VerifiedStatus),
        }
    }
}

/// IdentifierStatus 标识生命周期状态
/// 核心职责：
/// - 追踪外部标识的当前有效性和历史状态
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum IdentifierStatus {
    Active,
    Replaced,
    Disputed,
    Removed,
}

impl IdentifierStatus {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Active => "active",
            Self::Replaced => "replaced",
            Self::Disputed => "disputed",
            Self::Removed => "removed",
        }
    }
}

impl TryFrom<&str> for IdentifierStatus {
    type Error = PetErrorKind;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        match value {
            "active" => Ok(Self::Active),
            "replaced" => Ok(Self::Replaced),
            "disputed" => Ok(Self::Disputed),
            "removed" => Ok(Self::Removed),
            _ => Err(PetErrorKind::IdentifierStatus),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // ── IdentifierType ──

    #[test]
    fn identifier_type_microchip_as_str() {
        assert_eq!(IdentifierType::Microchip.as_str(), "microchip");
    }

    #[test]
    fn identifier_type_try_from_valid() {
        assert_eq!(
            IdentifierType::try_from("microchip").unwrap(),
            IdentifierType::Microchip
        );
    }

    #[test]
    fn identifier_type_try_from_invalid() {
        assert!(IdentifierType::try_from("chip").is_err());
        assert!(IdentifierType::try_from("").is_err());
    }

    // ── VerifiedStatus ──

    #[test]
    fn verified_status_all_variants() {
        assert_eq!(VerifiedStatus::Unverified.as_str(), "unverified");
        assert_eq!(VerifiedStatus::SelfReported.as_str(), "self_reported");
        assert_eq!(VerifiedStatus::Verified.as_str(), "verified");
        assert_eq!(VerifiedStatus::Rejected.as_str(), "rejected");
    }

    #[test]
    fn verified_status_try_from_valid() {
        assert_eq!(
            VerifiedStatus::try_from("unverified").unwrap(),
            VerifiedStatus::Unverified
        );
        assert_eq!(
            VerifiedStatus::try_from("self_reported").unwrap(),
            VerifiedStatus::SelfReported
        );
        assert_eq!(
            VerifiedStatus::try_from("verified").unwrap(),
            VerifiedStatus::Verified
        );
        assert_eq!(
            VerifiedStatus::try_from("rejected").unwrap(),
            VerifiedStatus::Rejected
        );
    }

    #[test]
    fn verified_status_try_from_invalid() {
        assert!(VerifiedStatus::try_from("pending").is_err());
    }

    // ── IdentifierStatus ──

    #[test]
    fn identifier_status_all_variants() {
        assert_eq!(IdentifierStatus::Active.as_str(), "active");
        assert_eq!(IdentifierStatus::Replaced.as_str(), "replaced");
        assert_eq!(IdentifierStatus::Disputed.as_str(), "disputed");
        assert_eq!(IdentifierStatus::Removed.as_str(), "removed");
    }

    #[test]
    fn identifier_status_try_from_valid() {
        assert_eq!(
            IdentifierStatus::try_from("active").unwrap(),
            IdentifierStatus::Active
        );
        assert_eq!(
            IdentifierStatus::try_from("replaced").unwrap(),
            IdentifierStatus::Replaced
        );
        assert_eq!(
            IdentifierStatus::try_from("disputed").unwrap(),
            IdentifierStatus::Disputed
        );
        assert_eq!(
            IdentifierStatus::try_from("removed").unwrap(),
            IdentifierStatus::Removed
        );
    }

    #[test]
    fn identifier_status_try_from_invalid() {
        assert!(IdentifierStatus::try_from("deleted").is_err());
    }

    // ── PetExternalIdentifier 构造契约 ──

    fn sample_identifier() -> PetExternalIdentifier {
        PetExternalIdentifier {
            id: Uuid::new_v4(),
            pet_id: Uuid::new_v4(),
            identifier_type: IdentifierType::Microchip,
            identifier_value: "900000000000001".into(),
            issuer: None,
            issued_at: None,
            verified_status: VerifiedStatus::SelfReported,
            status: IdentifierStatus::Active,
            evidence_asset_id: None,
            created_at: Utc::now(),
            updated_at: Utc::now(),
        }
    }

    #[test]
    fn pet_external_identifier_has_pet_id_reference() {
        let ident = sample_identifier();
        assert!(!ident.pet_id.is_nil());
    }

    #[test]
    fn pet_external_identifier_microchip_default_active() {
        let ident = sample_identifier();
        assert_eq!(ident.identifier_type, IdentifierType::Microchip);
        assert_eq!(ident.status, IdentifierStatus::Active);
    }

    #[test]
    fn pet_external_identifier_can_be_disputed() {
        let ident = PetExternalIdentifier {
            status: IdentifierStatus::Disputed,
            ..sample_identifier()
        };
        assert_eq!(ident.status, IdentifierStatus::Disputed);
    }

    #[test]
    fn pet_external_identifier_can_be_replaced() {
        let ident = PetExternalIdentifier {
            status: IdentifierStatus::Replaced,
            ..sample_identifier()
        };
        assert_eq!(ident.status, IdentifierStatus::Replaced);
    }

    #[test]
    fn pet_external_identifier_does_not_replace_pet_id() {
        // 外部标识有自己的 id，但必须引用 pet_id，不替代宠物身份
        let ident = sample_identifier();
        assert_ne!(ident.id, ident.pet_id);
        // 芯片号不应等于 pet_id 的字符串表示
        assert_ne!(ident.identifier_value, ident.pet_id.to_string());
    }
}
