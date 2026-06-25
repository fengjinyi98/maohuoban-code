use async_trait::async_trait;
use maohuoban_pet_application::pet::{
    FoodInventoryRepository, NewFoodInventoryItem, UpdateFoodInventoryItem,
};
use maohuoban_pet_domain::pet::{
    FoodInventoryCategory, FoodInventoryItem, FoodInventoryStatus, FoodScopeType, PetError,
    PetResult,
};
use sqlx::PgPool;
use uuid::Uuid;

use super::food_inventory_rows::FoodInventoryItemRow;

/// PostgresFoodInventoryRepository PostgreSQL 食品资产仓储
/// 核心职责：
/// - 持久化储物柜食品资产 CRUD
/// - 支持按 scope 和分类查询
#[derive(Clone)]
pub struct PostgresFoodInventoryRepository {
    pool: PgPool,
}

impl PostgresFoodInventoryRepository {
    #[must_use]
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }

    async fn record_change(
        &self,
        item: &FoodInventoryItem,
        actor_user_id: Uuid,
        change_kind: &str,
    ) -> PetResult<()> {
        sqlx::query(
            r#"
            INSERT INTO food_inventory_item_changes (
                id, food_item_id, scope_type, scope_id, actor_user_id,
                change_kind, item_name, item_category
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(item.id)
        .bind(item.scope_type.as_str())
        .bind(item.scope_id)
        .bind(actor_user_id)
        .bind(change_kind)
        .bind(&item.name)
        .bind(item.category.as_str())
        .execute(&self.pool)
        .await
        .map_err(|error| {
            PetError::Infrastructure(format!("failed to record food inventory change: {error}"))
        })?;
        Ok(())
    }
}

#[async_trait]
impl FoodInventoryRepository for PostgresFoodInventoryRepository {
    async fn create_item(&self, input: NewFoodInventoryItem) -> PetResult<FoodInventoryItem> {
        let row: FoodInventoryItemRow = sqlx::query_as(
            r#"
            INSERT INTO food_inventory_items (
                id, scope_type, scope_id, created_by_user_id,
                name, brand, category, inventory_status,
                quantity, unit, spec, expiry_date,
                cover_asset_id, barcode, source_kind, note
            ) VALUES (
                $1, $2, $3, $4, $5, $6, $7, $8, $9,
                $10, $11, $12, $13, $14, $15, $16
            )
            RETURNING *
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(input.scope_type.as_str())
        .bind(input.scope_id)
        .bind(input.created_by_user_id)
        .bind(&input.name)
        .bind(input.brand.as_deref())
        .bind(input.category.as_str())
        .bind(input.inventory_status.as_str())
        .bind(input.quantity)
        .bind(input.unit.as_deref())
        .bind(input.spec.as_deref())
        .bind(input.expiry_date)
        .bind(input.cover_asset_id)
        .bind(input.barcode.as_deref())
        .bind(input.source_kind.as_str())
        .bind(input.note.as_deref())
        .fetch_one(&self.pool)
        .await
        .map_err(|error| {
            PetError::Infrastructure(format!("failed to create food inventory item: {error}"))
        })?;

        let item = FoodInventoryItem::try_from(row)?;
        self.record_change(&item, item.created_by_user_id, "created")
            .await?;
        Ok(item)
    }

    async fn list_items(
        &self,
        scope_type: FoodScopeType,
        scope_id: Uuid,
        category: Option<FoodInventoryCategory>,
        status: Option<FoodInventoryStatus>,
    ) -> PetResult<Vec<FoodInventoryItem>> {
        let rows: Vec<FoodInventoryItemRow> = sqlx::query_as(
            r#"
            SELECT * FROM food_inventory_items
            WHERE scope_type = $1 AND scope_id = $2
            AND ($3::text IS NULL OR category = $3)
            AND ($4::text IS NULL OR inventory_status = $4)
            AND ($4::text = 'archived' OR archived_at IS NULL)
            ORDER BY created_at DESC
            "#,
        )
        .bind(scope_type.as_str())
        .bind(scope_id)
        .bind(category.map(|c| c.as_str().to_owned()))
        .bind(status.map(|s| s.as_str().to_owned()))
        .fetch_all(&self.pool)
        .await
        .map_err(|error| {
            PetError::Infrastructure(format!("failed to list food inventory items: {error}"))
        })?;

        rows.into_iter().map(FoodInventoryItem::try_from).collect()
    }

    async fn find_item(&self, item_id: Uuid) -> PetResult<Option<FoodInventoryItem>> {
        let result: Option<FoodInventoryItemRow> =
            sqlx::query_as("SELECT * FROM food_inventory_items WHERE id = $1")
                .bind(item_id)
                .fetch_optional(&self.pool)
                .await
                .map_err(|error| {
                    PetError::Infrastructure(format!("failed to find food inventory item: {error}"))
                })?;

        result.map(FoodInventoryItem::try_from).transpose()
    }

    async fn update_item(&self, input: UpdateFoodInventoryItem) -> PetResult<FoodInventoryItem> {
        let result: Option<FoodInventoryItemRow> = sqlx::query_as(
            r#"
            UPDATE food_inventory_items SET
                name = COALESCE($2, name),
                brand = COALESCE($3, brand),
                category = COALESCE($4, category),
                inventory_status = COALESCE($5, inventory_status),
                quantity = COALESCE($6, quantity),
                unit = COALESCE($7, unit),
                spec = COALESCE($8, spec),
                expiry_date = COALESCE($9, expiry_date),
                cover_asset_id = COALESCE($10, cover_asset_id),
                barcode = COALESCE($11, barcode),
                note = COALESCE($12, note),
                updated_at = now()
            WHERE id = $1 AND archived_at IS NULL
            RETURNING *
            "#,
        )
        .bind(input.item_id)
        .bind(input.name.as_deref())
        .bind(input.brand.as_deref())
        .bind(input.category.map(|c| c.as_str().to_owned()))
        .bind(input.inventory_status.map(|s| s.as_str().to_owned()))
        .bind(input.quantity)
        .bind(input.unit.as_deref())
        .bind(input.spec.as_deref())
        .bind(input.expiry_date)
        .bind(input.cover_asset_id)
        .bind(input.barcode.as_deref())
        .bind(input.note.as_deref())
        .fetch_optional(&self.pool)
        .await
        .map_err(|error| {
            PetError::Infrastructure(format!("failed to update food inventory item: {error}"))
        })?;

        match result {
            Some(row) => {
                let item = FoodInventoryItem::try_from(row)?;
                self.record_change(&item, input.editor_user_id, "updated")
                    .await?;
                Ok(item)
            }
            None => Err(PetError::FoodInventoryNotFound),
        }
    }

    async fn archive_item(
        &self,
        item_id: Uuid,
        editor_user_id: Uuid,
    ) -> PetResult<FoodInventoryItem> {
        let result: Option<FoodInventoryItemRow> = sqlx::query_as(
            r#"
            UPDATE food_inventory_items SET
                inventory_status = 'archived',
                archived_at = now(),
                updated_at = now()
            WHERE id = $1 AND archived_at IS NULL
            RETURNING *
            "#,
        )
        .bind(item_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(|error| {
            PetError::Infrastructure(format!("failed to archive food inventory item: {error}"))
        })?;

        match result {
            Some(row) => {
                let item = FoodInventoryItem::try_from(row)?;
                self.record_change(&item, editor_user_id, "archived")
                    .await?;
                Ok(item)
            }
            None => Err(PetError::FoodInventoryNotFound),
        }
    }

    async fn restore_item(
        &self,
        item_id: Uuid,
        editor_user_id: Uuid,
        status: FoodInventoryStatus,
    ) -> PetResult<FoodInventoryItem> {
        let result: Option<FoodInventoryItemRow> = sqlx::query_as(
            r#"
            UPDATE food_inventory_items SET
                inventory_status = $2,
                archived_at = NULL,
                updated_at = now()
            WHERE id = $1 AND archived_at IS NOT NULL
            RETURNING *
            "#,
        )
        .bind(item_id)
        .bind(status.as_str())
        .fetch_optional(&self.pool)
        .await
        .map_err(|error| {
            PetError::Infrastructure(format!("failed to restore food inventory item: {error}"))
        })?;

        match result {
            Some(row) => {
                let item = FoodInventoryItem::try_from(row)?;
                self.record_change(&item, editor_user_id, "restored")
                    .await?;
                Ok(item)
            }
            None => Err(PetError::FoodInventoryNotFound),
        }
    }

    async fn restock_item(
        &self,
        item_id: Uuid,
        editor_user_id: Uuid,
        quantity: i32,
    ) -> PetResult<FoodInventoryItem> {
        if quantity <= 0 {
            return Err(PetError::InvalidInput("补库存数量必须大于 0".to_owned()));
        }

        let result: Option<FoodInventoryItemRow> = sqlx::query_as(
            r#"
            UPDATE food_inventory_items SET
                quantity = quantity + $2,
                inventory_status = CASE
                    WHEN inventory_status = 'depleted' THEN 'active'
                    ELSE inventory_status
                END,
                updated_at = now()
            WHERE id = $1 AND archived_at IS NULL
            RETURNING *
            "#,
        )
        .bind(item_id)
        .bind(quantity)
        .fetch_optional(&self.pool)
        .await
        .map_err(|error| {
            PetError::Infrastructure(format!("failed to restock food inventory item: {error}"))
        })?;

        match result {
            Some(row) => {
                let item = FoodInventoryItem::try_from(row)?;
                self.record_change(&item, editor_user_id, "restocked")
                    .await?;
                Ok(item)
            }
            None => Err(PetError::FoodInventoryNotFound),
        }
    }
}
