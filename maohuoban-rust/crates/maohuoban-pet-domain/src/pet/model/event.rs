use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use uuid::Uuid;

use super::PetErrorKind;

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
