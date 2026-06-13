use chrono::{DateTime, NaiveDate, Utc};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use uuid::Uuid;

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
    pub managed_status: ManagedPetStatus,
    pub source_kind: PetSourceKind,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
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

/// PetEvent 宠物事件
/// 核心职责：
/// - 表达普通用户和商家共用的追加型记录
/// - 支持时间线和证据快照扩展
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct PetEvent {
    pub id: Uuid,
    pub pet_id: Option<Uuid>,
    pub litter_id: Option<Uuid>,
    pub event_kind: EventKind,
    pub event_subkind: Option<String>,
    pub title: String,
    pub summary: Option<String>,
    pub visibility: EventVisibility,
    pub event_payload: Value,
    pub occurred_at: DateTime<Utc>,
    pub actor_user_id: Option<Uuid>,
    pub evidence_snapshot_id: Option<Uuid>,
    pub record_revision: i32,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// EventKind 宠物事件类型
/// 核心职责：
/// - 固定事件账本一级分类
/// - 让健康、交易、商家记录共享事件底座
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum EventKind {
    Daily,
    Growth,
    Health,
    Hospital,
    Trade,
    Merchant,
    Memorial,
}

impl EventKind {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Daily => "daily",
            Self::Growth => "growth",
            Self::Health => "health",
            Self::Hospital => "hospital",
            Self::Trade => "trade",
            Self::Merchant => "merchant",
            Self::Memorial => "memorial",
        }
    }
}

impl TryFrom<&str> for EventKind {
    type Error = PetErrorKind;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        match value {
            "daily" => Ok(Self::Daily),
            "growth" => Ok(Self::Growth),
            "health" => Ok(Self::Health),
            "hospital" => Ok(Self::Hospital),
            "trade" => Ok(Self::Trade),
            "merchant" => Ok(Self::Merchant),
            "memorial" => Ok(Self::Memorial),
            _ => Err(PetErrorKind::EventKind),
        }
    }
}

/// EventVisibility 事件可见范围
/// 核心职责：
/// - 默认收紧隐私和医疗交易记录
/// - 支持买家可见时间线和公开事件
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum EventVisibility {
    Private,
    CoCaretakers,
    Authorized,
    BuyerVisible,
    Public,
}

impl EventVisibility {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Private => "private",
            Self::CoCaretakers => "co_caretakers",
            Self::Authorized => "authorized",
            Self::BuyerVisible => "buyer_visible",
            Self::Public => "public",
        }
    }
}

impl TryFrom<&str> for EventVisibility {
    type Error = PetErrorKind;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        match value {
            "private" => Ok(Self::Private),
            "co_caretakers" => Ok(Self::CoCaretakers),
            "authorized" => Ok(Self::Authorized),
            "buyer_visible" => Ok(Self::BuyerVisible),
            "public" => Ok(Self::Public),
            _ => Err(PetErrorKind::Visibility),
        }
    }
}

/// PetTimeline 宠物时间线
/// 核心职责：
/// - 承载单只宠物最近事件列表
/// - 为首页和宠物详情页提供稳定读模型
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct PetTimeline {
    pub pet_id: Uuid,
    pub events: Vec<PetEvent>,
}

#[derive(Debug, Clone, Copy)]
pub enum PetErrorKind {
    Species,
    Sex,
    ManagedStatus,
    SourceKind,
    EventKind,
    Visibility,
}
