use std::sync::Arc;

use maohuoban_pet_domain::pet::{
    FoodInventoryCategory, FoodInventoryItem, FoodInventoryStatus, FoodScopeType, PetError,
    PetResult,
};
use uuid::Uuid;

use super::super::{FoodInventoryRepository, NewFoodInventoryItem, UpdateFoodInventoryItem};

/// PetService food inventory 方法组
pub(super) async fn create_food_inventory_item(
    food_inventory: &Arc<dyn FoodInventoryRepository>,
    input: NewFoodInventoryItem,
) -> PetResult<FoodInventoryItem> {
    reject_direct_archived_status(input.inventory_status)?;
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

pub(super) async fn update_food_inventory_item(
    food_inventory: &Arc<dyn FoodInventoryRepository>,
    input: UpdateFoodInventoryItem,
) -> PetResult<FoodInventoryItem> {
    if let Some(status) = input.inventory_status {
        reject_direct_archived_status(status)?;
    }
    ensure_food_inventory_editor(food_inventory, input.item_id, input.editor_user_id).await?;
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
