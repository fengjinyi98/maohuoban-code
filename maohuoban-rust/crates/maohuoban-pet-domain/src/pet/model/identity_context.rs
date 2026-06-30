// pet_identity_context Agent 身份事实包读模型
// 核心职责：
// - 为毛球 Agent 提供以 pet_id 为根的聚合身份上下文
// - 可解释、可审计、不暴露底层兼容字段

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// PetIdentityContext Agent 宠物身份上下文
/// 核心职责：
/// - 聚合同一 pet_id 的身份、关系、外部标识、生命周期摘要
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct PetIdentityContext {
    pub identity: IdentitySummary,
    pub origin: OriginSummary,
    pub current_guardians: Vec<GuardianSummary>,
    pub external_identifiers: Vec<ExternalIdentifierSummary>,
    pub lifecycle: Vec<LifecycleSummary>,
}

/// IdentitySummary 宠物身份摘要
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct IdentitySummary {
    pub pet_id: Uuid,
    pub profile_number: String,
    pub name: String,
    pub species: String,
    pub breed: Option<String>,
    pub sex: String,
    pub birthday: Option<String>,
    pub arrival_date: Option<String>,
    pub world_days: Option<i64>,
    pub companionship_days: Option<i64>,
    pub life_status: String,
}

/// OriginSummary 来源摘要
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct OriginSummary {
    pub origin_kind: String,
    pub created_at: DateTime<Utc>,
}

/// GuardianSummary 归属关系摘要
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct GuardianSummary {
    pub guardian_id: Uuid,
    pub guardian_type: String,
    pub guardian_user_id: Option<Uuid>,
    pub guardian_merchant_id: Option<Uuid>,
    pub role: String,
    pub status: String,
}

/// ExternalIdentifierSummary 外部标识摘要
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ExternalIdentifierSummary {
    pub identifier_type: String,
    pub identifier_value: String,
    pub verified_status: String,
    pub status: String,
}

/// LifecycleSummary 生命周期事件摘要
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct LifecycleSummary {
    pub id: Uuid,
    pub event_kind: String,
    pub occurred_at: DateTime<Utc>,
    pub note: Option<String>,
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_context() -> PetIdentityContext {
        PetIdentityContext {
            identity: IdentitySummary {
                pet_id: Uuid::new_v4(),
                profile_number: "0000000000000001".into(),
                name: "测试宠物".into(),
                species: "dog".into(),
                breed: Some("金毛".into()),
                sex: "male".into(),
                birthday: None,
                arrival_date: None,
                world_days: None,
                companionship_days: None,
                life_status: "alive".into(),
            },
            origin: OriginSummary {
                origin_kind: "user_created".into(),
                created_at: Utc::now(),
            },
            current_guardians: vec![],
            external_identifiers: vec![],
            lifecycle: vec![],
        }
    }

    #[test]
    fn identity_context_has_pet_id_in_identity() {
        let ctx = sample_context();
        assert!(!ctx.identity.pet_id.is_nil());
    }

    #[test]
    fn identity_context_exposes_pet_life_days_and_companionship_days() {
        let ctx = PetIdentityContext {
            identity: IdentitySummary {
                birthday: Some("2024-01-01".into()),
                arrival_date: Some("2024-03-01".into()),
                world_days: Some(100),
                companionship_days: Some(40),
                ..sample_context().identity
            },
            ..sample_context()
        };

        assert_eq!(ctx.identity.arrival_date.as_deref(), Some("2024-03-01"));
        assert_eq!(ctx.identity.world_days, Some(100));
        assert_eq!(ctx.identity.companionship_days, Some(40));
    }

    #[test]
    fn identity_context_supports_multiple_guardians() {
        let ctx = PetIdentityContext {
            current_guardians: vec![
                GuardianSummary {
                    guardian_id: Uuid::new_v4(),
                    guardian_type: "user".into(),
                    guardian_user_id: Some(Uuid::new_v4()),
                    guardian_merchant_id: None,
                    role: "owner".into(),
                    status: "active".into(),
                },
                GuardianSummary {
                    guardian_id: Uuid::new_v4(),
                    guardian_type: "user".into(),
                    guardian_user_id: Some(Uuid::new_v4()),
                    guardian_merchant_id: None,
                    role: "co_caretaker".into(),
                    status: "active".into(),
                },
            ],
            ..sample_context()
        };
        assert_eq!(ctx.current_guardians.len(), 2);
    }

    #[test]
    fn identity_context_supports_disputed_external_id() {
        let ctx = PetIdentityContext {
            external_identifiers: vec![ExternalIdentifierSummary {
                identifier_type: "microchip".into(),
                identifier_value: "900000000000001".into(),
                verified_status: "self_reported".into(),
                status: "disputed".into(),
            }],
            ..sample_context()
        };
        assert_eq!(ctx.external_identifiers.len(), 1);
        assert_eq!(ctx.external_identifiers[0].verified_status, "self_reported");
        assert_eq!(ctx.external_identifiers[0].status, "disputed");
    }

    #[test]
    fn identity_context_lifecycle_preserves_history() {
        let ctx = PetIdentityContext {
            lifecycle: vec![
                LifecycleSummary {
                    id: Uuid::new_v4(),
                    event_kind: "created".into(),
                    occurred_at: Utc::now(),
                    note: None,
                },
                LifecycleSummary {
                    id: Uuid::new_v4(),
                    event_kind: "marked_deceased".into(),
                    occurred_at: Utc::now(),
                    note: Some("自然死亡".into()),
                },
            ],
            ..sample_context()
        };
        assert_eq!(ctx.lifecycle.len(), 2);
        assert_eq!(ctx.lifecycle[1].event_kind, "marked_deceased");
    }
}
