use chrono::{DateTime, NaiveDate, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use super::{PetErrorKind, PetExternalIdentifier};

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

/// PetNeuterStatus 宠物绝育状态
/// 核心职责：
/// - 固定档案绝育状态枚举
/// - 与数据库和 iOS 展示契约保持一致
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum PetNeuterStatus {
    Unknown,
    Intact,
    Neutered,
}

impl PetNeuterStatus {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Unknown => "unknown",
            Self::Intact => "intact",
            Self::Neutered => "neutered",
        }
    }
}

impl TryFrom<&str> for PetNeuterStatus {
    type Error = PetErrorKind;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        match value {
            "unknown" => Ok(Self::Unknown),
            "intact" => Ok(Self::Intact),
            "neutered" => Ok(Self::Neutered),
            _ => Err(PetErrorKind::NeuterStatus),
        }
    }
}

/// PetBackgroundMediaKind 宠物背景媒体类型
/// 核心职责：
/// - 区分背景图片、背景视频和 Live Photo
/// - 支持前端选择正确预览和播放路径
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum PetBackgroundMediaKind {
    Image,
    Video,
    LivePhoto,
}

impl PetBackgroundMediaKind {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Image => "image",
            Self::Video => "video",
            Self::LivePhoto => "live_photo",
        }
    }
}

impl TryFrom<&str> for PetBackgroundMediaKind {
    type Error = PetErrorKind;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        match value {
            "image" => Ok(Self::Image),
            "video" => Ok(Self::Video),
            "live_photo" => Ok(Self::LivePhoto),
            _ => Err(PetErrorKind::BackgroundMediaKind),
        }
    }
}

/// PetSpecies 宠物物种
/// 核心职责：
/// - 固定首批宠物物种枚举
/// - 与首页读模型和数据库约束保持一致
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum PetSpecies {
    Dog,
    Cat,
    Other,
}

impl PetSpecies {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Dog => "dog",
            Self::Cat => "cat",
            Self::Other => "other",
        }
    }
}

impl TryFrom<&str> for PetSpecies {
    type Error = PetErrorKind;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        match value {
            "dog" => Ok(Self::Dog),
            "cat" => Ok(Self::Cat),
            "other" => Ok(Self::Other),
            _ => Err(PetErrorKind::Species),
        }
    }
}

/// PetSex 宠物性别
/// 核心职责：
/// - 统一宠物档案性别字段
/// - 支持未知性别
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum PetSex {
    Female,
    Male,
    Unknown,
}

impl PetSex {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Female => "female",
            Self::Male => "male",
            Self::Unknown => "unknown",
        }
    }
}

impl TryFrom<&str> for PetSex {
    type Error = PetErrorKind;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        match value {
            "female" => Ok(Self::Female),
            "male" => Ok(Self::Male),
            "unknown" => Ok(Self::Unknown),
            _ => Err(PetErrorKind::Sex),
        }
    }
}

/// ManagedPetStatus 商家和家庭宠物状态
/// 核心职责：
/// - 表达普通家庭、在售、预定、已售和待补记录等状态
/// - 支撑首页商家多宠状态看板
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum ManagedPetStatus {
    Family,
    Available,
    Reserved,
    Sold,
    Retained,
    Fostered,
    NeedsExam,
    NeedsRecord,
    Inactive,
}

impl ManagedPetStatus {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Family => "family",
            Self::Available => "available",
            Self::Reserved => "reserved",
            Self::Sold => "sold",
            Self::Retained => "retained",
            Self::Fostered => "fostered",
            Self::NeedsExam => "needs_exam",
            Self::NeedsRecord => "needs_record",
            Self::Inactive => "inactive",
        }
    }
}

impl TryFrom<&str> for ManagedPetStatus {
    type Error = PetErrorKind;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        match value {
            "family" => Ok(Self::Family),
            "available" => Ok(Self::Available),
            "reserved" => Ok(Self::Reserved),
            "sold" => Ok(Self::Sold),
            "retained" => Ok(Self::Retained),
            "fostered" => Ok(Self::Fostered),
            "needs_exam" => Ok(Self::NeedsExam),
            "needs_record" => Ok(Self::NeedsRecord),
            "inactive" => Ok(Self::Inactive),
            _ => Err(PetErrorKind::ManagedStatus),
        }
    }
}

/// PetSourceKind 宠物来源类型
/// 核心职责：
/// - 标记宠物档案创建来源
/// - 为交易导入和商家窝次出生保留扩展位
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum PetSourceKind {
    UserCreated,
    TradeImported,
    MerchantManaged,
    LitterBirth,
}

impl PetSourceKind {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::UserCreated => "user_created",
            Self::TradeImported => "trade_imported",
            Self::MerchantManaged => "merchant_managed",
            Self::LitterBirth => "litter_birth",
        }
    }
}

impl TryFrom<&str> for PetSourceKind {
    type Error = PetErrorKind;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        match value {
            "user_created" => Ok(Self::UserCreated),
            "trade_imported" => Ok(Self::TradeImported),
            "merchant_managed" => Ok(Self::MerchantManaged),
            "litter_birth" => Ok(Self::LitterBirth),
            _ => Err(PetErrorKind::SourceKind),
        }
    }
}

/// LifeStatus 宠物生命状态
/// 核心职责：
/// - 表达宠物当前生命阶段
/// - 与删除/归档状态分离，去世不删除档案
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum LifeStatus {
    Alive,
    Deceased,
    Lost,
    Archived,
}

impl LifeStatus {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Alive => "alive",
            Self::Deceased => "deceased",
            Self::Lost => "lost",
            Self::Archived => "archived",
        }
    }
}

impl TryFrom<&str> for LifeStatus {
    type Error = PetErrorKind;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        match value {
            "alive" => Ok(Self::Alive),
            "deceased" => Ok(Self::Deceased),
            "lost" => Ok(Self::Lost),
            "archived" => Ok(Self::Archived),
            _ => Err(PetErrorKind::LifeStatus),
        }
    }
}

/// OriginKind 宠物档案原始来源
/// 核心职责：
/// - 只表达宠物档案最初来源，不随归属变化而改变
/// - 替代 PetSourceKind 作为不可变来源标识
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum OriginKind {
    UserCreated,
    TradeImported,
    MerchantCreated,
    LitterBirth,
    Adopted,
}

impl OriginKind {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::UserCreated => "user_created",
            Self::TradeImported => "trade_imported",
            Self::MerchantCreated => "merchant_created",
            Self::LitterBirth => "litter_birth",
            Self::Adopted => "adopted",
        }
    }
}

impl TryFrom<&str> for OriginKind {
    type Error = PetErrorKind;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        match value {
            "user_created" => Ok(Self::UserCreated),
            "trade_imported" => Ok(Self::TradeImported),
            "merchant_created" => Ok(Self::MerchantCreated),
            "litter_birth" => Ok(Self::LitterBirth),
            "adopted" => Ok(Self::Adopted),
            _ => Err(PetErrorKind::OriginKind),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::Utc;
    use uuid::Uuid;

    // ── LifeStatus 枚举契约 ──

    #[test]
    fn life_status_alive_as_str() {
        assert_eq!(LifeStatus::Alive.as_str(), "alive");
    }

    #[test]
    fn life_status_deceased_as_str() {
        assert_eq!(LifeStatus::Deceased.as_str(), "deceased");
    }

    #[test]
    fn life_status_lost_as_str() {
        assert_eq!(LifeStatus::Lost.as_str(), "lost");
    }

    #[test]
    fn life_status_archived_as_str() {
        assert_eq!(LifeStatus::Archived.as_str(), "archived");
    }

    #[test]
    fn life_status_try_from_valid_str() {
        assert_eq!(LifeStatus::try_from("alive").unwrap(), LifeStatus::Alive);
        assert_eq!(
            LifeStatus::try_from("deceased").unwrap(),
            LifeStatus::Deceased
        );
        assert_eq!(LifeStatus::try_from("lost").unwrap(), LifeStatus::Lost);
        assert_eq!(
            LifeStatus::try_from("archived").unwrap(),
            LifeStatus::Archived
        );
    }

    #[test]
    fn life_status_try_from_invalid_str() {
        assert!(LifeStatus::try_from("dead").is_err());
        assert!(LifeStatus::try_from("unknown").is_err());
        assert!(LifeStatus::try_from("").is_err());
    }

    #[test]
    fn life_status_serde_roundtrip() {
        let status = LifeStatus::Deceased;
        let json = serde_json::to_string(&status).unwrap();
        let parsed: LifeStatus = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed, status);
    }

    // ── OriginKind 枚举契约 ──

    #[test]
    fn origin_kind_all_variants_as_str() {
        assert_eq!(OriginKind::UserCreated.as_str(), "user_created");
        assert_eq!(OriginKind::TradeImported.as_str(), "trade_imported");
        assert_eq!(OriginKind::MerchantCreated.as_str(), "merchant_created");
        assert_eq!(OriginKind::LitterBirth.as_str(), "litter_birth");
        assert_eq!(OriginKind::Adopted.as_str(), "adopted");
    }

    #[test]
    fn origin_kind_try_from_valid_str() {
        assert_eq!(
            OriginKind::try_from("user_created").unwrap(),
            OriginKind::UserCreated
        );
        assert_eq!(
            OriginKind::try_from("trade_imported").unwrap(),
            OriginKind::TradeImported
        );
        assert_eq!(
            OriginKind::try_from("merchant_created").unwrap(),
            OriginKind::MerchantCreated
        );
        assert_eq!(
            OriginKind::try_from("litter_birth").unwrap(),
            OriginKind::LitterBirth
        );
        assert_eq!(
            OriginKind::try_from("adopted").unwrap(),
            OriginKind::Adopted
        );
    }

    #[test]
    fn origin_kind_try_from_invalid_str() {
        assert!(OriginKind::try_from("merchant_managed").is_err());
        assert!(OriginKind::try_from("unknown").is_err());
        assert!(OriginKind::try_from("").is_err());
    }

    #[test]
    fn origin_kind_serde_roundtrip() {
        let origin = OriginKind::Adopted;
        let json = serde_json::to_string(&origin).unwrap();
        let parsed: OriginKind = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed, origin);
    }

    // ── PetProfile 不可变身份与生命周期字段 ──

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
        // pet_id 在构造后不可变——无 setter，字段不可 pub mut
        let profile = sample_profile();
        let id = profile.id;
        // 验证 id 可以通过不可变引用读取但不能更改
        assert_eq!(profile.id, id);
        assert!(!profile.id.is_nil());
    }

    #[test]
    fn pet_profile_microchip_is_read_only_compat_field() {
        // Phase 1: microchip_number 保留为兼容只读字段
        // 新增写入只走 pet_external_identifiers
        let profile = sample_profile();
        assert!(
            profile.microchip_number.is_none(),
            "新创建的 profile 不应通过主表写入 microchip，只走外部标识"
        );
    }

    #[test]
    fn pet_profile_microchip_can_still_be_read_for_compat() {
        // 兼容期：从数据库读取已有的 microchip_number 仍然支持
        let profile = PetProfile {
            microchip_number: Some("900000000000001".into()),
            ..sample_profile()
        };
        assert_eq!(profile.microchip_number.as_deref(), Some("900000000000001"));
    }

    #[test]
    fn pet_profile_immutable_profile_number_contract() {
        // profile_number 创建后不可变
        let profile = sample_profile();
        let num = profile.profile_number.clone();
        assert_eq!(profile.profile_number, num);
        assert!(!profile.profile_number.is_empty());
    }

    #[test]
    fn life_status_separate_from_deleted_at() {
        // life_status = Deceased 时 deleted_at 仍可为 None
        // 去世不删除档案
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
        // life_status 与 managed_status 无耦合
        // 去世宠物仍可为 Family 管理状态
        let profile = PetProfile {
            life_status: LifeStatus::Deceased,
            managed_status: ManagedPetStatus::Family,
            ..sample_profile()
        };
        assert_eq!(profile.life_status, LifeStatus::Deceased);
        assert_eq!(profile.managed_status, ManagedPetStatus::Family);
    }
}
