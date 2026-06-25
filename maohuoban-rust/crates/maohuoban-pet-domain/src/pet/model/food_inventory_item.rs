use chrono::{DateTime, NaiveDate, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use super::PetErrorKind;

/// FoodInventoryItem 储物柜食品资产
/// 核心职责：
/// - 表达用户/家庭空间级食品与用品资产
/// - 供多宠共用，不绑定单一 pet_id
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct FoodInventoryItem {
    pub id: Uuid,
    pub scope_type: FoodScopeType,
    pub scope_id: Uuid,
    pub created_by_user_id: Uuid,
    pub name: String,
    pub brand: Option<String>,
    pub category: FoodInventoryCategory,
    pub inventory_status: FoodInventoryStatus,
    pub quantity: i32,
    pub unit: Option<String>,
    pub spec: Option<String>,
    pub expiry_date: Option<NaiveDate>,
    pub cover_asset_id: Option<Uuid>,
    pub barcode: Option<String>,
    pub source_kind: FoodSourceKind,
    pub note: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub archived_at: Option<DateTime<Utc>>,
}

/// FoodScopeType 储物柜资产归属范围
/// 核心职责：
/// - 一期固定 user scope
/// - 预留 household 与 merchant
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum FoodScopeType {
    User,
    Household,
    Merchant,
}

impl FoodScopeType {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::User => "user",
            Self::Household => "household",
            Self::Merchant => "merchant",
        }
    }
}

impl TryFrom<&str> for FoodScopeType {
    type Error = PetErrorKind;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        match value {
            "user" => Ok(Self::User),
            "household" => Ok(Self::Household),
            "merchant" => Ok(Self::Merchant),
            _ => Err(PetErrorKind::FoodScopeType),
        }
    }
}

/// FoodInventoryCategory 食品分类
/// 核心职责：
/// - 约束储物柜分类枚举
/// - 区分 Agent 饮食上下文可消费分类
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum FoodInventoryCategory {
    MainFood,
    WetFood,
    Treats,
    Nutrition,
    Other,
    CatLitter,
    Medicine,
}

impl FoodInventoryCategory {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::MainFood => "main_food",
            Self::WetFood => "wet_food",
            Self::Treats => "treats",
            Self::Nutrition => "nutrition",
            Self::Other => "other",
            Self::CatLitter => "cat_litter",
            Self::Medicine => "medicine",
        }
    }

    #[must_use]
    pub const fn is_diet_context_eligible(self) -> bool {
        matches!(
            self,
            Self::MainFood | Self::WetFood | Self::Treats | Self::Nutrition | Self::Other
        )
    }
}

impl TryFrom<&str> for FoodInventoryCategory {
    type Error = PetErrorKind;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        match value {
            "main_food" => Ok(Self::MainFood),
            "wet_food" => Ok(Self::WetFood),
            "treats" => Ok(Self::Treats),
            "nutrition" => Ok(Self::Nutrition),
            "other" => Ok(Self::Other),
            "cat_litter" => Ok(Self::CatLitter),
            "medicine" => Ok(Self::Medicine),
            _ => Err(PetErrorKind::FoodInventoryCategory),
        }
    }
}

/// FoodInventoryStatus 库存状态
/// 核心职责：
/// - 表达资产当前可用与归档状态
/// - 支持 sealed / in_use / depleted 流转
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum FoodInventoryStatus {
    Active,
    Sealed,
    InUse,
    Depleted,
    Archived,
}

impl FoodInventoryStatus {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Active => "active",
            Self::Sealed => "sealed",
            Self::InUse => "in_use",
            Self::Depleted => "depleted",
            Self::Archived => "archived",
        }
    }

    #[must_use]
    pub const fn is_archived(self) -> bool {
        matches!(self, Self::Archived)
    }
}

impl TryFrom<&str> for FoodInventoryStatus {
    type Error = PetErrorKind;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        match value {
            "active" => Ok(Self::Active),
            "sealed" => Ok(Self::Sealed),
            "in_use" => Ok(Self::InUse),
            "depleted" => Ok(Self::Depleted),
            "archived" => Ok(Self::Archived),
            _ => Err(PetErrorKind::FoodInventoryStatus),
        }
    }
}

/// FoodSourceKind 食品资产来源
/// 核心职责：
/// - 区分手动录入与扫码/OCR/订单导入
/// - 供 Agent 弱线索判断
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum FoodSourceKind {
    Manual,
    Barcode,
    Ocr,
    OrderImported,
    AgentConfirmed,
}

impl FoodSourceKind {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Manual => "manual",
            Self::Barcode => "barcode",
            Self::Ocr => "ocr",
            Self::OrderImported => "order_imported",
            Self::AgentConfirmed => "agent_confirmed",
        }
    }
}

impl TryFrom<&str> for FoodSourceKind {
    type Error = PetErrorKind;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        match value {
            "manual" => Ok(Self::Manual),
            "barcode" => Ok(Self::Barcode),
            "ocr" => Ok(Self::Ocr),
            "order_imported" => Ok(Self::OrderImported),
            "agent_confirmed" => Ok(Self::AgentConfirmed),
            _ => Err(PetErrorKind::FoodSourceKind),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn food_inventory_category_serializes_snake_case() {
        let value = serde_json::to_value(FoodInventoryCategory::MainFood).expect("serialize");
        assert_eq!(value, "main_food");
    }

    #[test]
    fn food_inventory_status_parses_archived() {
        assert_eq!(
            FoodInventoryStatus::try_from("archived").expect("parse"),
            FoodInventoryStatus::Archived
        );
        assert!(FoodInventoryStatus::Archived.is_archived());
    }

    #[test]
    fn diet_context_excludes_cat_litter_and_medicine() {
        assert!(FoodInventoryCategory::MainFood.is_diet_context_eligible());
        assert!(!FoodInventoryCategory::CatLitter.is_diet_context_eligible());
        assert!(!FoodInventoryCategory::Medicine.is_diet_context_eligible());
    }

    #[test]
    fn food_scope_type_defaults_to_user_string() {
        assert_eq!(FoodScopeType::User.as_str(), "user");
    }
}
