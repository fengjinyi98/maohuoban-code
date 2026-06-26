use serde::{Deserialize, Serialize};

use super::PetErrorKind;

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
}
