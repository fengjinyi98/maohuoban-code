use maohuoban_pet_domain::pet::{
    FoodInventoryCategory, FoodInventoryItem, FoodInventoryStatus, FoodScopeType, PetError,
    PetEvent, PetResult,
};
use uuid::Uuid;

use super::super::{NewFoodInventoryItem, NewPetEvent, UpdateFoodInventoryItem};
use super::PetService;
use super::food_inventory;

/// PetService 食品库存委托方法
/// 核心职责：
/// - 为食品库存 CRUD 操作提供统一的 service 入口
/// - 委托 food_inventory 模块的 free function 完成实际操作
impl PetService {
    pub async fn create_food_inventory_item(
        &self,
        input: NewFoodInventoryItem,
    ) -> PetResult<FoodInventoryItem> {
        food_inventory::create_food_inventory_item(&self.food_inventory, input).await
    }

    pub async fn list_food_inventory_items(
        &self,
        scope_type: FoodScopeType,
        scope_id: Uuid,
        category: Option<FoodInventoryCategory>,
        status: Option<FoodInventoryStatus>,
    ) -> PetResult<Vec<FoodInventoryItem>> {
        food_inventory::list_food_inventory_items(
            &self.food_inventory,
            scope_type,
            scope_id,
            category,
            status,
        )
        .await
    }

    pub async fn find_food_inventory_item(&self, item_id: Uuid) -> PetResult<FoodInventoryItem> {
        food_inventory::find_food_inventory_item(&self.food_inventory, item_id).await
    }

    pub async fn update_food_inventory_item(
        &self,
        input: UpdateFoodInventoryItem,
    ) -> PetResult<FoodInventoryItem> {
        food_inventory::update_food_inventory_item(&self.food_inventory, input).await
    }

    pub async fn delete_food_inventory_item(
        &self,
        item_id: Uuid,
        editor_user_id: Uuid,
    ) -> PetResult<FoodInventoryItem> {
        food_inventory::delete_food_inventory_item(&self.food_inventory, item_id, editor_user_id)
            .await
    }

    pub async fn restock_food_inventory_item(
        &self,
        item_id: Uuid,
        editor_user_id: Uuid,
        quantity: i32,
    ) -> PetResult<FoodInventoryItem> {
        food_inventory::restock_food_inventory_item(
            &self.food_inventory,
            item_id,
            editor_user_id,
            quantity,
        )
        .await
    }

    pub(super) async fn load_food_inventory_consumable_item(
        &self,
        item_id: Uuid,
        editor_user_id: Uuid,
    ) -> PetResult<FoodInventoryItem> {
        food_inventory::load_food_inventory_consumable_item(
            &self.food_inventory,
            item_id,
            editor_user_id,
        )
        .await
    }

    /// enrich_feeding_event_payload 喂食事件载荷增强
    /// 核心职责：
    /// - 为 feeding 事件自动注入带封面的 food_snapshot
    /// - 让详情页和饮食上下文消费同一份事件快照
    pub(super) async fn enrich_feeding_event_payload(
        &self,
        input: &mut NewPetEvent,
    ) -> PetResult<()> {
        if input.event_subkind.as_deref() != Some("feeding") {
            return Ok(());
        }
        let Some(food_item_id_value) = input.event_payload.get("food_item_id") else {
            return Ok(());
        };
        if food_item_id_value.is_null() {
            return Ok(());
        }
        let food_item_id = food_item_id_value
            .as_str()
            .and_then(|value| Uuid::parse_str(value).ok())
            .ok_or_else(|| PetError::InvalidInput("食品资产 ID 格式不正确".to_owned()))?;
        let food_item = self
            .load_food_inventory_consumable_item(food_item_id, input.actor_user_id)
            .await?;
        let payload = input
            .event_payload
            .as_object_mut()
            .ok_or_else(|| PetError::InvalidInput("喂食事件载荷格式不正确".to_owned()))?;
        payload.insert(
            "food_snapshot".to_owned(),
            serde_json::json!({
                "name": food_item.name,
                "brand": food_item.brand,
                "category": food_item.category.as_str(),
                "spec": food_item.spec,
                "package_weight_grams": food_item.package_weight_grams,
                "package_count": food_item.package_count,
                "package_unit": food_item.package_unit,
                "cover_asset_id": food_item.cover_asset_id,
                "cover_url": food_item.cover_url
            }),
        );
        Ok(())
    }

    /// mark_feeding_food_item_in_use 喂食后食品状态流转
    /// 核心职责：
    /// - 仅在 feeding 事件成功写入后处理库存状态
    /// - 将未拆封食品切换为喂食中，保持事件账本与储物柜状态一致
    pub(super) async fn mark_feeding_food_item_in_use(&self, event: &PetEvent) -> PetResult<()> {
        if event.event_subkind.as_deref() != Some("feeding") {
            return Ok(());
        }
        let Some(food_item_id) = event
            .event_payload
            .get("food_item_id")
            .and_then(|value| value.as_str())
            .and_then(|value| Uuid::parse_str(value).ok())
        else {
            return Ok(());
        };
        let Some(food_item) = self.food_inventory.find_item(food_item_id).await? else {
            return Ok(());
        };
        if food_item.inventory_status != FoodInventoryStatus::Sealed {
            return Ok(());
        }
        let Some(editor_user_id) = event.actor_user_id else {
            return Ok(());
        };
        self.update_food_inventory_item(UpdateFoodInventoryItem {
            item_id: food_item_id,
            editor_user_id,
            inventory_status: Some(FoodInventoryStatus::InUse),
            ..UpdateFoodInventoryItem::default()
        })
        .await?;
        Ok(())
    }
}
