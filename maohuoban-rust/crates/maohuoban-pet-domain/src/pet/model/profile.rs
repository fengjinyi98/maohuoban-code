use chrono::{DateTime, NaiveDate, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use super::PetErrorKind;

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
