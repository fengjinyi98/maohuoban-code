use std::sync::Arc;

use maohuoban_pet_domain::pet::{
    FoodInventoryCategory, FoodInventoryItem, FoodInventoryStatus, FoodScopeType, PetError,
    PetResult,
};
use uuid::Uuid;

use super::super::{
    FoodInventoryItemDetail, FoodInventoryRepository, NewFoodInventoryItem, UpdateFoodInventoryItem,
};

/// PetService food inventory 方法组
pub(super) async fn create_food_inventory_item(
    food_inventory: &Arc<dyn FoodInventoryRepository>,
    mut input: NewFoodInventoryItem,
) -> PetResult<FoodInventoryItem> {
    reject_direct_archived_status(input.inventory_status)?;
    validate_shelf_life_input(input.production_date.is_some(), input.shelf_life_months)?;
    normalize_new_food_inventory_item(&mut input);
    food_inventory.create_item(input).await
}

pub(super) async fn list_food_inventory_items(
    food_inventory: &Arc<dyn FoodInventoryRepository>,
    scope_type: FoodScopeType,
    scope_id: Uuid,
    category: Option<FoodInventoryCategory>,
    status: Option<FoodInventoryStatus>,
) -> PetResult<Vec<FoodInventoryItem>> {
    food_inventory
        .list_items(scope_type, scope_id, category, status)
        .await
}

pub(super) async fn find_food_inventory_item(
    food_inventory: &Arc<dyn FoodInventoryRepository>,
    item_id: Uuid,
) -> PetResult<FoodInventoryItem> {
    food_inventory
        .find_item(item_id)
        .await?
        .ok_or(PetError::FoodInventoryNotFound)
}

pub(super) async fn load_food_inventory_item_detail(
    food_inventory: &Arc<dyn FoodInventoryRepository>,
    item_id: Uuid,
    owner_user_id: Uuid,
) -> PetResult<FoodInventoryItemDetail> {
    food_inventory
        .load_item_detail(item_id, owner_user_id)
        .await
}

pub(super) async fn update_food_inventory_item(
    food_inventory: &Arc<dyn FoodInventoryRepository>,
    mut input: UpdateFoodInventoryItem,
) -> PetResult<FoodInventoryItem> {
    if let Some(status) = input.inventory_status {
        reject_direct_archived_status(status)?;
    }
    validate_update_shelf_life_input(input.production_date.is_some(), input.shelf_life_months)?;
    let current =
        load_food_inventory_editor_item(food_inventory, input.item_id, input.editor_user_id)
            .await?;
    normalize_update_food_inventory_item(&mut input, current.category);
    food_inventory.update_item(input).await
}

pub(super) async fn delete_food_inventory_item(
    food_inventory: &Arc<dyn FoodInventoryRepository>,
    item_id: Uuid,
    editor_user_id: Uuid,
) -> PetResult<FoodInventoryItem> {
    ensure_food_inventory_editor(food_inventory, item_id, editor_user_id).await?;
    food_inventory.delete_item(item_id, editor_user_id).await
}

pub(super) async fn restock_food_inventory_item(
    food_inventory: &Arc<dyn FoodInventoryRepository>,
    item_id: Uuid,
    editor_user_id: Uuid,
    quantity: i32,
) -> PetResult<FoodInventoryItem> {
    ensure_food_inventory_editor(food_inventory, item_id, editor_user_id).await?;
    food_inventory
        .restock_item(item_id, editor_user_id, quantity)
        .await
}

pub(super) async fn ensure_food_inventory_editor(
    food_inventory: &Arc<dyn FoodInventoryRepository>,
    item_id: Uuid,
    editor_user_id: Uuid,
) -> PetResult<()> {
    load_food_inventory_editor_item(food_inventory, item_id, editor_user_id)
        .await
        .map(|_| ())
}

async fn load_food_inventory_editor_item(
    food_inventory: &Arc<dyn FoodInventoryRepository>,
    item_id: Uuid,
    editor_user_id: Uuid,
) -> PetResult<FoodInventoryItem> {
    let item = food_inventory
        .find_item(item_id)
        .await?
        .ok_or(PetError::FoodInventoryNotFound)?;
    if item.scope_type == FoodScopeType::User && item.scope_id == editor_user_id {
        Ok(item)
    } else {
        Err(PetError::FoodInventoryNotFound)
    }
}

pub(super) async fn load_food_inventory_consumable_item(
    food_inventory: &Arc<dyn FoodInventoryRepository>,
    item_id: Uuid,
    editor_user_id: Uuid,
) -> PetResult<FoodInventoryItem> {
    let item = load_food_inventory_editor_item(food_inventory, item_id, editor_user_id).await?;
    if item.inventory_status.is_archived() || item.archived_at.is_some() {
        Err(PetError::InvalidInput(
            "已归档食品资产不能用于饮食配置或喂食记录".to_owned(),
        ))
    } else {
        Ok(item)
    }
}

pub(super) fn reject_direct_archived_status(status: FoodInventoryStatus) -> PetResult<()> {
    if status.is_archived() {
        return Err(PetError::InvalidInput(
            "不能直接创建或恢复为已归档状态".to_owned(),
        ));
    }
    Ok(())
}

fn validate_shelf_life_input(
    has_production_date: bool,
    shelf_life_months: Option<i32>,
) -> PetResult<()> {
    match (has_production_date, shelf_life_months) {
        (true, Some(months)) if months > 0 => Ok(()),
        _ => Err(PetError::InvalidInput(
            "请填写生产日期和保质期月份".to_owned(),
        )),
    }
}

fn validate_update_shelf_life_input(
    has_production_date: bool,
    shelf_life_months: Option<i32>,
) -> PetResult<()> {
    if let Some(months) = shelf_life_months
        && months <= 0
    {
        return Err(PetError::InvalidInput("保质期月份必须大于 0".to_owned()));
    }
    if has_production_date ^ shelf_life_months.is_some() {
        return Err(PetError::InvalidInput(
            "生产日期和保质期月份需要同时填写".to_owned(),
        ));
    }
    Ok(())
}

/// normalize_new_food_inventory_item 规范化新建食品资产输入
/// 核心职责：
/// - 将规格文本补充为服务端统一的结构化克重
/// - 保持食品资产写入前的数据契约完整
fn normalize_new_food_inventory_item(input: &mut NewFoodInventoryItem) {
    if input.package_weight_grams.is_some() {
        return;
    }
    input.package_weight_grams = derive_package_weight_grams(input.category, input.spec.as_deref());
}

/// normalize_update_food_inventory_item 规范化编辑食品资产输入
/// 核心职责：
/// - 在编辑规格时补齐结构化克重
/// - 使用当前品类作为未提交品类时的推导上下文
fn normalize_update_food_inventory_item(
    input: &mut UpdateFoodInventoryItem,
    current_category: FoodInventoryCategory,
) {
    if input.package_weight_grams.is_some() {
        return;
    }
    let Some(spec) = input.spec.as_deref() else {
        return;
    };
    let category = input.category.unwrap_or(current_category);
    input.package_weight_grams = derive_package_weight_grams(category, Some(spec));
}

/// derive_package_weight_grams 从食品规格推导单件克重
/// 核心职责：
/// - 解析带明确单位的 kg/g/克/千克规格
/// - 对语义明确的食品品类把无单位数字视为克
fn derive_package_weight_grams(category: FoodInventoryCategory, spec: Option<&str>) -> Option<i32> {
    let normalized = normalize_spec_text(spec?);
    if normalized.is_empty() {
        return None;
    }
    if let Some(value) = parse_weight_with_unit(&normalized) {
        return Some(value);
    }
    if unitless_spec_means_grams(category) {
        return parse_positive_grams(&normalized);
    }
    None
}

fn normalize_spec_text(spec: &str) -> String {
    spec.trim()
        .to_lowercase()
        .replace(' ', "")
        .replace('　', "")
}

fn parse_weight_with_unit(spec: &str) -> Option<i32> {
    for suffix in ["kg", "千克", "公斤"] {
        if let Some(number) = spec.strip_suffix(suffix) {
            return parse_positive_number(number).map(|value| round_grams(value * 1000.0));
        }
    }
    for suffix in ["g", "克"] {
        if let Some(number) = spec.strip_suffix(suffix) {
            return parse_positive_number(number).map(round_grams);
        }
    }
    None
}

fn parse_positive_grams(spec: &str) -> Option<i32> {
    parse_positive_number(spec).map(round_grams)
}

fn parse_positive_number(value: &str) -> Option<f64> {
    let number = value.parse::<f64>().ok()?;
    if number.is_finite() && number > 0.0 {
        Some(number)
    } else {
        None
    }
}

fn round_grams(value: f64) -> i32 {
    let rounded = value.round().clamp(1.0, f64::from(i32::MAX));
    #[expect(
        clippy::cast_possible_truncation,
        reason = "克重已四舍五入并限制在 i32 范围内"
    )]
    {
        rounded as i32
    }
}

fn unitless_spec_means_grams(category: FoodInventoryCategory) -> bool {
    matches!(
        category,
        FoodInventoryCategory::WetFood
            | FoodInventoryCategory::Treats
            | FoodInventoryCategory::Nutrition
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn derive_package_weight_parses_explicit_units() {
        assert_eq!(
            derive_package_weight_grams(FoodInventoryCategory::MainFood, Some("1.5kg")),
            Some(1500)
        );
        assert_eq!(
            derive_package_weight_grams(FoodInventoryCategory::Treats, Some("500g")),
            Some(500)
        );
        assert_eq!(
            derive_package_weight_grams(FoodInventoryCategory::MainFood, Some("2公斤")),
            Some(2000)
        );
    }

    #[test]
    fn derive_package_weight_treats_unitless_wet_food_as_grams() {
        assert_eq!(
            derive_package_weight_grams(FoodInventoryCategory::WetFood, Some("185")),
            Some(185)
        );
        assert_eq!(
            derive_package_weight_grams(FoodInventoryCategory::Nutrition, Some("50")),
            Some(50)
        );
    }

    #[test]
    fn derive_package_weight_keeps_unitless_main_food_unresolved() {
        assert_eq!(
            derive_package_weight_grams(FoodInventoryCategory::MainFood, Some("2.5")),
            None
        );
    }
}
