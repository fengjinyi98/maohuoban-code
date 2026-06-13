use chrono::{DateTime, NaiveDate, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use super::{ManagedPetStatus, PetSpecies};

/// MerchantProfile 商家认证主体
/// 核心职责：
/// - 表达猫舍、犬舍和宠物店等机构身份
/// - 为商家多宠工作台和追溯记录提供主体边界
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct MerchantProfile {
    pub id: Uuid,
    pub owner_user_id: Uuid,
    pub merchant_type: MerchantType,
    pub name: String,
    pub city: Option<String>,
    pub verification_status: MerchantVerificationStatus,
    pub verified_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// MerchantType 商家类型
/// 核心职责：
/// - 固定首批机构类型
/// - 支撑首页和后续认证资料分流
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum MerchantType {
    PetStore,
    CatBreeder,
    DogBreeder,
    Hospital,
    ServiceProvider,
}

impl MerchantType {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::PetStore => "pet_store",
            Self::CatBreeder => "cat_breeder",
            Self::DogBreeder => "dog_breeder",
            Self::Hospital => "hospital",
            Self::ServiceProvider => "service_provider",
        }
    }
}

impl TryFrom<&str> for MerchantType {
    type Error = MerchantParseError;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        match value {
            "pet_store" => Ok(Self::PetStore),
            "cat_breeder" => Ok(Self::CatBreeder),
            "dog_breeder" => Ok(Self::DogBreeder),
            "hospital" => Ok(Self::Hospital),
            "service_provider" => Ok(Self::ServiceProvider),
            _ => Err(MerchantParseError),
        }
    }
}

/// MerchantVerificationStatus 商家认证状态
/// 核心职责：
/// - 表达商家认证生命周期
/// - 驱动首页认证商家和未认证商家分支
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum MerchantVerificationStatus {
    Pending,
    Verified,
    Rejected,
    Suspended,
}

impl MerchantVerificationStatus {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Pending => "pending",
            Self::Verified => "verified",
            Self::Rejected => "rejected",
            Self::Suspended => "suspended",
        }
    }
}

impl TryFrom<&str> for MerchantVerificationStatus {
    type Error = MerchantParseError;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        match value {
            "pending" => Ok(Self::Pending),
            "verified" => Ok(Self::Verified),
            "rejected" => Ok(Self::Rejected),
            "suspended" => Ok(Self::Suspended),
            _ => Err(MerchantParseError),
        }
    }
}

/// Litter 商家窝次
/// 核心职责：
/// - 表达一窝宠物的出生批次和父母关系
/// - 为商家记录从出生开始追溯提供稳定主体
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct Litter {
    pub id: Uuid,
    pub merchant_id: Uuid,
    pub name: String,
    pub species: PetSpecies,
    pub sire_pet_id: Option<Uuid>,
    pub dam_pet_id: Option<Uuid>,
    pub born_at: NaiveDate,
    pub born_count: i32,
    pub alive_count: i32,
    pub status: LitterStatus,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// LitterStatus 窝次状态
/// 核心职责：
/// - 表达窝次从计划到归档的生命周期
/// - 支撑商家工作台筛选活跃窝次
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum LitterStatus {
    Planned,
    Active,
    Closed,
    Archived,
}

impl LitterStatus {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Planned => "planned",
            Self::Active => "active",
            Self::Closed => "closed",
            Self::Archived => "archived",
        }
    }
}

impl TryFrom<&str> for LitterStatus {
    type Error = MerchantParseError;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        match value {
            "planned" => Ok(Self::Planned),
            "active" => Ok(Self::Active),
            "closed" => Ok(Self::Closed),
            "archived" => Ok(Self::Archived),
            _ => Err(MerchantParseError),
        }
    }
}

/// PetRelationship 宠物关系
/// 核心职责：
/// - 表达父母、同窝、转让和共管等关系边
/// - 支撑商家可追溯关系树和买家可见时间线
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct PetRelationship {
    pub id: Uuid,
    pub subject_pet_id: Uuid,
    pub related_pet_id: Option<Uuid>,
    pub litter_id: Option<Uuid>,
    pub relationship_kind: PetRelationshipKind,
    pub source_kind: PetRelationshipSourceKind,
    pub evidence_snapshot_id: Option<Uuid>,
    pub created_at: DateTime<Utc>,
}

/// PetRelationshipKind 宠物关系类型
/// 核心职责：
/// - 固定商家追溯关系边类型
/// - 让关系树和首页摘要共享稳定语义
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum PetRelationshipKind {
    Sire,
    Dam,
    SameLitter,
    SameSource,
    TransferredFrom,
    CoCaretaker,
    MerchantManaged,
}

impl PetRelationshipKind {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Sire => "sire",
            Self::Dam => "dam",
            Self::SameLitter => "same_litter",
            Self::SameSource => "same_source",
            Self::TransferredFrom => "transferred_from",
            Self::CoCaretaker => "co_caretaker",
            Self::MerchantManaged => "merchant_managed",
        }
    }
}

impl TryFrom<&str> for PetRelationshipKind {
    type Error = MerchantParseError;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        match value {
            "sire" => Ok(Self::Sire),
            "dam" => Ok(Self::Dam),
            "same_litter" => Ok(Self::SameLitter),
            "same_source" => Ok(Self::SameSource),
            "transferred_from" => Ok(Self::TransferredFrom),
            "co_caretaker" => Ok(Self::CoCaretaker),
            "merchant_managed" => Ok(Self::MerchantManaged),
            _ => Err(MerchantParseError),
        }
    }
}

/// PetRelationshipSourceKind 宠物关系来源
/// 核心职责：
/// - 标记关系由用户、商家、系统或交易导入产生
/// - 为后续审计和可信度展示预留依据
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum PetRelationshipSourceKind {
    UserRecorded,
    MerchantRecorded,
    SystemDerived,
    TradeImported,
}

impl PetRelationshipSourceKind {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::UserRecorded => "user_recorded",
            Self::MerchantRecorded => "merchant_recorded",
            Self::SystemDerived => "system_derived",
            Self::TradeImported => "trade_imported",
        }
    }
}

impl TryFrom<&str> for PetRelationshipSourceKind {
    type Error = MerchantParseError;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        match value {
            "user_recorded" => Ok(Self::UserRecorded),
            "merchant_recorded" => Ok(Self::MerchantRecorded),
            "system_derived" => Ok(Self::SystemDerived),
            "trade_imported" => Ok(Self::TradeImported),
            _ => Err(MerchantParseError),
        }
    }
}

/// MerchantStatusCount 商家宠物状态统计
/// 核心职责：
/// - 表达商家在管宠物按状态聚合结果
/// - 为首页工作台和多宠筛选提供同一份读模型
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct MerchantStatusCount {
    pub status: ManagedPetStatus,
    pub count: u32,
}

#[derive(Debug, Clone, Copy)]
pub struct MerchantParseError;
