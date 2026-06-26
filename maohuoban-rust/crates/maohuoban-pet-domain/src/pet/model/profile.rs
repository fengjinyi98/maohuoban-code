use chrono::{DateTime, NaiveDate, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use super::PetExternalIdentifier;
use super::profile_enums::{
    LifeStatus, ManagedPetStatus, OriginKind, PetBackgroundMediaKind, PetNeuterStatus, PetSex,
    PetSourceKind, PetSpecies,
};

/// PetProfile 宠物档案
/// 核心职责：
/// - 表达普通用户和商家共用的宠物主体
/// - 使用 UUID 作为跨端稳定身份
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct PetProfile {
    pub id: Uuid,
    pub owner_user_id: Option<Uuid>,
    pub merchant_id: Option<Uuid>,
    pub name: String,
    pub species: PetSpecies,
    pub breed: Option<String>,
    pub sex: PetSex,
    pub birthday: Option<NaiveDate>,
    pub profile_number: String,
    pub microchip_number: Option<String>,
    pub external_identifiers: Vec<PetExternalIdentifier>,
    pub arrival_date: Option<NaiveDate>,
    pub weight_grams: Option<i32>,
    pub neuter_status: PetNeuterStatus,
    pub personality_tags: Vec<String>,
    pub note: Option<String>,
    pub avatar_asset_id: Option<Uuid>,
    pub background_asset_id: Option<Uuid>,
    pub background_media_kind: Option<PetBackgroundMediaKind>,
    pub deleted_at: Option<DateTime<Utc>>,
    pub delete_requested_by_user_id: Option<Uuid>,
    pub recoverable_until: Option<DateTime<Utc>>,
    pub delete_reason: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub name_edit_policy: Option<PetNameEditPolicy>,
    pub managed_status: ManagedPetStatus,
    pub source_kind: PetSourceKind,
    pub life_status: LifeStatus,
    pub origin_kind: OriginKind,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// PetNameEditPolicy 宠物名字编辑策略
/// 核心职责：
/// - 表达后端计算出的改名额度
/// - 为前端编辑页展示提供直接消费的数据
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct PetNameEditPolicy {
    pub max_count: i32,
    pub used_count: i32,
    pub remaining_count: i32,
    pub window_days: i32,
    pub window_ends_at: Option<DateTime<Utc>>,
    pub display_text: String,
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::Utc;
    use uuid::Uuid;

    fn sample_profile() -> PetProfile {
        PetProfile {
            id: Uuid::new_v4(),
            owner_user_id: Some(Uuid::new_v4()),
            merchant_id: None,
            name: "测试宠物".into(),
            species: PetSpecies::Dog,
            breed: Some("金毛".into()),
            sex: PetSex::Male,
            birthday: None,
            profile_number: "0000000000000001".into(),
            microchip_number: None,
            external_identifiers: vec![],
            arrival_date: None,
            weight_grams: Some(15000),
            neuter_status: PetNeuterStatus::Unknown,
            personality_tags: vec![],
            note: None,
            avatar_asset_id: None,
            background_asset_id: None,
            background_media_kind: None,
            deleted_at: None,
            delete_requested_by_user_id: None,
            recoverable_until: None,
            delete_reason: None,
            name_edit_policy: None,
            managed_status: ManagedPetStatus::Family,
            source_kind: PetSourceKind::UserCreated,
            life_status: LifeStatus::Alive,
            origin_kind: OriginKind::UserCreated,
            created_at: Utc::now(),
            updated_at: Utc::now(),
        }
    }

    #[test]
    fn pet_profile_has_life_status_field() {
        let profile = sample_profile();
        assert_eq!(profile.life_status, LifeStatus::Alive);
    }

    #[test]
    fn pet_profile_has_origin_kind_field() {
        let profile = sample_profile();
        assert_eq!(profile.origin_kind, OriginKind::UserCreated);
    }

    #[test]
    fn pet_profile_immutable_id_contract() {
        let profile = sample_profile();
        let id = profile.id;
        assert_eq!(profile.id, id);
        assert!(!profile.id.is_nil());
    }

    #[test]
    fn pet_profile_microchip_is_read_only_compat_field() {
        let profile = sample_profile();
        assert!(
            profile.microchip_number.is_none(),
            "新创建的 profile 不应通过主表写入 microchip，只走外部标识"
        );
    }

    #[test]
    fn pet_profile_microchip_can_still_be_read_for_compat() {
        let profile = PetProfile {
            microchip_number: Some("900000000000001".into()),
            ..sample_profile()
        };
        assert_eq!(profile.microchip_number.as_deref(), Some("900000000000001"));
    }

    #[test]
    fn pet_profile_immutable_profile_number_contract() {
        let profile = sample_profile();
        let num = profile.profile_number.clone();
        assert_eq!(profile.profile_number, num);
        assert!(!profile.profile_number.is_empty());
    }

    #[test]
    fn life_status_separate_from_deleted_at() {
        let profile = PetProfile {
            life_status: LifeStatus::Deceased,
            deleted_at: None,
            ..sample_profile()
        };
        assert_eq!(profile.life_status, LifeStatus::Deceased);
        assert!(profile.deleted_at.is_none());
    }

    #[test]
    fn life_status_separate_from_managed_status() {
        let profile = PetProfile {
            life_status: LifeStatus::Deceased,
            managed_status: ManagedPetStatus::Family,
            ..sample_profile()
        };
        assert_eq!(profile.life_status, LifeStatus::Deceased);
        assert_eq!(profile.managed_status, ManagedPetStatus::Family);
    }
}
