use async_trait::async_trait;
use maohuoban_pet_application::pet::{
    FoodInventoryAmountDistributionItem, FoodInventoryConsumptionSummary,
    FoodInventoryFeedingTimelineEntry, FoodInventoryItemDetail, FoodInventoryLinkedPet,
    FoodInventoryRepository, NewFoodInventoryItem, UpdateFoodInventoryItem,
};
use maohuoban_pet_domain::pet::{
    FoodInventoryCategory, FoodInventoryItem, FoodInventoryStatus, FoodScopeType, FoodSnapshot,
    PetError, PetResult,
};
use sqlx::{PgPool, Row};
use std::collections::HashMap;
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

    async fn load_item_feeding_timeline(
        &self,
        item_id: Uuid,
        owner_user_id: Uuid,
    ) -> PetResult<Vec<FoodInventoryFeedingTimelineEntry>> {
        let rows = sqlx::query(
            r#"
            SELECT
                e.id,
                e.pet_id,
                p.name AS pet_name,
                e.occurred_at,
                e.title,
                e.summary,
                e.event_payload
            FROM pet_events e
            INNER JOIN pet_profiles p ON p.id = e.pet_id
            WHERE p.owner_user_id = $1
              AND p.deleted_at IS NULL
              AND e.event_kind = 'daily'
              AND e.event_subkind = 'feeding'
              AND e.superseded_by_event_id IS NULL
              AND e.event_payload->>'food_item_id' = $2
            ORDER BY e.occurred_at DESC, e.created_at DESC
            LIMIT 100
            "#,
        )
        .bind(owner_user_id)
        .bind(item_id.to_string())
        .fetch_all(&self.pool)
        .await
        .map_err(|error| {
            PetError::Infrastructure(format!(
                "failed to load food inventory feeding timeline: {error}"
            ))
        })?;

        let timeline = rows
            .into_iter()
            .map(|row| {
                let payload: serde_json::Value = row.get("event_payload");
                let food_snapshot = payload
                    .get("food_snapshot")
                    .cloned()
                    .and_then(|value| serde_json::from_value::<FoodSnapshot>(value).ok());
                FoodInventoryFeedingTimelineEntry {
                    event_id: row.get("id"),
                    pet_id: row.get("pet_id"),
                    pet_name: row.get("pet_name"),
                    occurred_at: row.get("occurred_at"),
                    title: row.get("title"),
                    summary: row.get("summary"),
                    amount_text: payload
                        .get("amount_text")
                        .and_then(|value| value.as_str())
                        .unwrap_or("正常")
                        .to_owned(),
                    food_role: payload
                        .get("food_role")
                        .and_then(|value| value.as_str())
                        .map(str::to_owned),
                    food_snapshot,
                }
            })
            .collect();

        Ok(timeline)
    }

    async fn load_item_linked_pets(
        &self,
        item_id: Uuid,
        owner_user_id: Uuid,
    ) -> PetResult<Vec<FoodInventoryLinkedPet>> {
        let feeding_rows = sqlx::query(
            r#"
            SELECT
                p.id AS pet_id,
                p.name AS pet_name,
                p.avatar_asset_id,
                MAX(e.occurred_at) AS last_used_at
            FROM pet_events e
            INNER JOIN pet_profiles p ON p.id = e.pet_id
            WHERE p.owner_user_id = $1
              AND p.deleted_at IS NULL
              AND e.event_kind = 'daily'
              AND e.event_subkind = 'feeding'
              AND e.superseded_by_event_id IS NULL
              AND e.event_payload->>'food_item_id' = $2
            GROUP BY p.id, p.name, p.avatar_asset_id
            ORDER BY last_used_at DESC
            "#,
        )
        .bind(owner_user_id)
        .bind(item_id.to_string())
        .fetch_all(&self.pool)
        .await
        .map_err(|error| {
            PetError::Infrastructure(format!("failed to load food item linked pets: {error}"))
        })?;

        let mut linked = Vec::new();
        let mut sources = HashMap::new();
        for row in feeding_rows {
            let pet_id: Uuid = row.get("pet_id");
            sources.insert(pet_id, "feeding_event".to_owned());
            let avatar_asset_id: Option<Uuid> = row.get("avatar_asset_id");
            linked.push(FoodInventoryLinkedPet {
                pet_id,
                pet_name: row.get("pet_name"),
                avatar_asset_id,
                avatar_url: avatar_asset_id.map(|id| format!("/api/v1/media/assets/{id}/content")),
                source: "feeding_event".to_owned(),
            });
        }

        let assignment_rows = sqlx::query(
            r#"
            SELECT DISTINCT
                p.id AS pet_id,
                p.name AS pet_name,
                p.avatar_asset_id
            FROM pet_diet_assignments a
            INNER JOIN pet_profiles p ON p.id = a.pet_id
            WHERE p.owner_user_id = $1
              AND p.deleted_at IS NULL
              AND a.food_item_id = $2
              AND a.status = 'active'
            ORDER BY p.name ASC
            "#,
        )
        .bind(owner_user_id)
        .bind(item_id)
        .fetch_all(&self.pool)
        .await
        .map_err(|error| {
            PetError::Infrastructure(format!(
                "failed to load food item assignment linked pets: {error}"
            ))
        })?;

        for row in assignment_rows {
            let pet_id: Uuid = row.get("pet_id");
            if sources.contains_key(&pet_id) {
                continue;
            }
            let avatar_asset_id: Option<Uuid> = row.get("avatar_asset_id");
            linked.push(FoodInventoryLinkedPet {
                pet_id,
                pet_name: row.get("pet_name"),
                avatar_asset_id,
                avatar_url: avatar_asset_id.map(|id| format!("/api/v1/media/assets/{id}/content")),
                source: "diet_assignment".to_owned(),
            });
        }

        Ok(linked)
    }
}

fn build_consumption_summary(
    timeline: &[FoodInventoryFeedingTimelineEntry],
) -> FoodInventoryConsumptionSummary {
    let feeding_count = i64::try_from(timeline.len()).unwrap_or(i64::MAX);
    let first_fed_at = timeline.iter().map(|entry| entry.occurred_at).min();
    let last_fed_at = timeline.iter().map(|entry| entry.occurred_at).max();
    let active_days = match (first_fed_at, last_fed_at) {
        (Some(first), Some(last)) => {
            last.date_naive()
                .signed_duration_since(first.date_naive())
                .num_days()
                + 1
        }
        _ => 0,
    };

    let mut counts: HashMap<String, i64> = HashMap::new();
    for entry in timeline {
        *counts.entry(entry.amount_text.clone()).or_insert(0) += 1;
    }

    let mut amount_distribution = Vec::new();
    for label in ["少一点", "正常", "多一点"] {
        if let Some(count) = counts.remove(label) {
            amount_distribution.push(FoodInventoryAmountDistributionItem {
                amount_text: label.to_owned(),
                count,
                ratio: count_ratio(count, feeding_count),
            });
        }
    }
    let mut other_labels: Vec<_> = counts.into_iter().collect();
    other_labels.sort_by(|left, right| left.0.cmp(&right.0));
    for (amount_text, count) in other_labels {
        amount_distribution.push(FoodInventoryAmountDistributionItem {
            amount_text,
            count,
            ratio: count_ratio(count, feeding_count),
        });
    }

    FoodInventoryConsumptionSummary {
        feeding_count,
        first_fed_at,
        last_fed_at,
        active_days,
        amount_distribution,
    }
}

fn count_ratio(count: i64, total: i64) -> f64 {
    let Ok(count) = u32::try_from(count) else {
        return 0.0;
    };
    let Ok(total) = u32::try_from(total) else {
        return 0.0;
    };
    if total == 0 {
        return 0.0;
    }
    f64::from(count) / f64::from(total)
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

    async fn load_item_detail(
        &self,
        item_id: Uuid,
        owner_user_id: Uuid,
    ) -> PetResult<FoodInventoryItemDetail> {
        let item = self
            .find_item(item_id)
            .await?
            .filter(|item| {
                item.scope_type == FoodScopeType::User
                    && item.scope_id == owner_user_id
                    && item.archived_at.is_none()
            })
            .ok_or(PetError::FoodInventoryNotFound)?;

        let feeding_timeline = self
            .load_item_feeding_timeline(item_id, owner_user_id)
            .await?;
        let linked_pets = self.load_item_linked_pets(item_id, owner_user_id).await?;
        let consumption_summary = build_consumption_summary(&feeding_timeline);

        Ok(FoodInventoryItemDetail {
            item,
            linked_pets,
            feeding_timeline,
            consumption_summary,
        })
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

    async fn delete_item(
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
            PetError::Infrastructure(format!("failed to delete food inventory item: {error}"))
        })?;

        match result {
            Some(row) => {
                let item = FoodInventoryItem::try_from(row)?;
                self.record_change(&item, editor_user_id, "deleted").await?;
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
