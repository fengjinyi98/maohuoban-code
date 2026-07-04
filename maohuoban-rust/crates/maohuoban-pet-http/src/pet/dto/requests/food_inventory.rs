use chrono::NaiveDate;
use maohuoban_pet_application::pet::{
    NewFoodInventoryItem, PendingPetMediaUploadInput, UpdateFoodInventoryItem,
};
use maohuoban_pet_domain::pet::{
    FoodInventoryCategory, FoodInventoryStatus, FoodScopeType, FoodSourceKind, MediaUsageKind,
};
use serde::Deserialize;
use uuid::Uuid;

use super::media::UploadPetMediaRequest;

/// CreateFoodInventoryItemRequest 创建食品资产请求
/// 核心职责：
/// - 接收前端储物柜入库表单数据
/// - 转换为应用层输入
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(crate) struct CreateFoodInventoryItemRequest {
    name: String,
    brand: Option<String>,
    #[serde(default = "default_category")]
    category: FoodInventoryCategory,
    #[serde(default = "default_quantity")]
    quantity: i32,
    unit: Option<String>,
    spec: Option<String>,
    package_weight_grams: Option<i32>,
    #[serde(default = "default_package_count")]
    package_count: i32,
    package_unit: Option<String>,
    production_date: Option<NaiveDate>,
    shelf_life_months: Option<i32>,
    cover_asset_id: Option<Uuid>,
    barcode: Option<String>,
    source_kind: Option<FoodSourceKind>,
    note: Option<String>,
}

fn default_category() -> FoodInventoryCategory {
    FoodInventoryCategory::MainFood
}

fn default_quantity() -> i32 {
    1
}

fn default_package_count() -> i32 {
    1
}

impl CreateFoodInventoryItemRequest {
    pub(crate) fn into_new(
        self,
        scope_type: FoodScopeType,
        scope_id: Uuid,
        created_by_user_id: Uuid,
    ) -> NewFoodInventoryItem {
        NewFoodInventoryItem {
            scope_type,
            scope_id,
            created_by_user_id,
            name: self.name,
            brand: self.brand,
            category: self.category,
            inventory_status: FoodInventoryStatus::Sealed,
            quantity: self.quantity,
            unit: self.unit,
            spec: self.spec,
            package_weight_grams: self.package_weight_grams,
            package_count: self.package_count,
            package_unit: self.package_unit,
            production_date: self.production_date,
            shelf_life_months: self.shelf_life_months,
            cover_asset_id: self.cover_asset_id,
            barcode: self.barcode,
            source_kind: self.source_kind.unwrap_or(FoodSourceKind::Manual),
            note: self.note,
        }
    }
}

/// UpdateFoodInventoryItemRequest 编辑食品资产请求
/// 核心职责：
/// - 接收前端编辑表单可选字段
/// - 转换"不限选"为 None
#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
pub(crate) struct UpdateFoodInventoryItemRequest {
    name: Option<String>,
    brand: Option<String>,
    category: Option<FoodInventoryCategory>,
    inventory_status: Option<FoodInventoryStatus>,
    quantity: Option<i32>,
    unit: Option<String>,
    spec: Option<String>,
    package_weight_grams: Option<i32>,
    package_count: Option<i32>,
    package_unit: Option<String>,
    production_date: Option<NaiveDate>,
    shelf_life_months: Option<i32>,
    cover_asset_id: Option<Uuid>,
    barcode: Option<String>,
    note: Option<String>,
}

impl UpdateFoodInventoryItemRequest {
    pub(crate) fn into_update(
        self,
        item_id: Uuid,
        editor_user_id: Uuid,
    ) -> UpdateFoodInventoryItem {
        UpdateFoodInventoryItem {
            item_id,
            editor_user_id,
            name: self.name,
            brand: self.brand,
            category: self.category,
            inventory_status: self.inventory_status,
            quantity: self.quantity,
            unit: self.unit,
            spec: self.spec,
            package_weight_grams: self.package_weight_grams,
            package_count: self.package_count,
            package_unit: self.package_unit,
            production_date: self.production_date,
            shelf_life_months: self.shelf_life_months,
            cover_asset_id: self.cover_asset_id,
            barcode: self.barcode,
            note: self.note,
        }
    }
}

impl UploadPetMediaRequest {
    pub(crate) fn into_pending_food_inventory_cover_input(
        self,
        owner_user_id: Uuid,
    ) -> PendingPetMediaUploadInput {
        self.into_pending_input(owner_user_id, MediaUsageKind::PetFoodInventoryCover)
    }
}
