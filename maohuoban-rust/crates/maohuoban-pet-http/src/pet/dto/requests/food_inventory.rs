use chrono::{Datelike, Months, NaiveDate};
use maohuoban_pet_application::pet::{
    NewFoodInventoryItem, PendingPetMediaUploadInput, UpdateFoodInventoryItem,
};
use maohuoban_pet_domain::pet::{
    FoodInventoryCategory, FoodInventoryStatus, FoodScopeType, FoodSourceKind, MediaUsageKind,
    PetError, PetResult,
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
    #[serde(default = "default_initial_status")]
    inventory_status: FoodInventoryStatus,
    #[serde(default = "default_quantity")]
    quantity: i32,
    unit: Option<String>,
    spec: Option<String>,
    production_date: NaiveDate,
    shelf_life_months: i32,
    cover_asset_id: Option<Uuid>,
    barcode: Option<String>,
    source_kind: Option<FoodSourceKind>,
    note: Option<String>,
}

fn default_category() -> FoodInventoryCategory {
    FoodInventoryCategory::MainFood
}

fn default_initial_status() -> FoodInventoryStatus {
    FoodInventoryStatus::Sealed
}

fn default_quantity() -> i32 {
    1
}

impl CreateFoodInventoryItemRequest {
    pub(crate) fn into_new(
        self,
        scope_type: FoodScopeType,
        scope_id: Uuid,
        created_by_user_id: Uuid,
    ) -> PetResult<NewFoodInventoryItem> {
        Ok(NewFoodInventoryItem {
            scope_type,
            scope_id,
            created_by_user_id,
            name: self.name,
            brand: self.brand,
            category: self.category,
            inventory_status: self.inventory_status,
            quantity: self.quantity,
            unit: self.unit,
            spec: self.spec,
            expiry_date: derive_expiry_date(self.production_date, self.shelf_life_months)?,
            production_date: self.production_date,
            shelf_life_months: self.shelf_life_months,
            cover_asset_id: self.cover_asset_id,
            barcode: self.barcode,
            source_kind: self.source_kind.unwrap_or(FoodSourceKind::Manual),
            note: self.note,
        })
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
    ) -> PetResult<UpdateFoodInventoryItem> {
        Ok(UpdateFoodInventoryItem {
            item_id,
            editor_user_id,
            name: self.name,
            brand: self.brand,
            category: self.category,
            inventory_status: self.inventory_status,
            quantity: self.quantity,
            unit: self.unit,
            spec: self.spec,
            expiry_date: derive_update_expiry_date(self.production_date, self.shelf_life_months)?,
            production_date: self.production_date,
            shelf_life_months: self.shelf_life_months,
            cover_asset_id: self.cover_asset_id,
            barcode: self.barcode,
            note: self.note,
        })
    }
}

// derive_expiry_date 计算食品过期日期
// 核心职责：
// - 只使用生产日期和保质期月份作为输入源
// - 将月末溢出日期收敛到目标月份最后一天
fn derive_expiry_date(production_date: NaiveDate, shelf_life_months: i32) -> PetResult<NaiveDate> {
    let months = u32::try_from(shelf_life_months)
        .map_err(|_| PetError::InvalidInput("保质期月份必须大于 0".to_owned()))?;
    production_date
        .checked_add_months(Months::new(months))
        .or_else(|| end_of_target_month(production_date, months))
        .ok_or_else(|| PetError::InvalidInput("过期日期无法由生产日期和保质期月份生成".to_owned()))
}

fn derive_update_expiry_date(
    production_date: Option<NaiveDate>,
    shelf_life_months: Option<i32>,
) -> PetResult<Option<NaiveDate>> {
    match (production_date, shelf_life_months) {
        (Some(date), Some(months)) => derive_expiry_date(date, months).map(Some),
        _ => Ok(None),
    }
}

fn end_of_target_month(date: NaiveDate, months: u32) -> Option<NaiveDate> {
    let first_of_month = date.with_day(1)?;
    let target_first = first_of_month.checked_add_months(Months::new(months))?;
    let next_month_first = target_first.checked_add_months(Months::new(1))?;
    next_month_first.pred_opt()
}

impl UploadPetMediaRequest {
    pub(crate) fn into_pending_food_inventory_cover_input(
        self,
        owner_user_id: Uuid,
    ) -> PendingPetMediaUploadInput {
        self.into_pending_input(owner_user_id, MediaUsageKind::PetFoodInventoryCover)
    }
}
