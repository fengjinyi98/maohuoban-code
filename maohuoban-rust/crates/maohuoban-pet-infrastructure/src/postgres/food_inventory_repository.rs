use async_trait::async_trait;
use maohuoban_pet_application::pet::{
    FoodInventoryAmountDistributionItem, FoodInventoryConsumptionSummary,
    FoodInventoryFeedingTimelineEntry, FoodInventoryItemDetail, FoodInventoryLinkedPet,
    FoodInventoryRepository, NewFoodInventoryItem, UpdateFoodInventoryItem,
};
use maohuoban_pet_domain::pet::{
    FoodInventoryCategory, FoodInventoryItem, FoodInventoryStatus, FoodScopeType, FoodSnapshot,
    PetError, PetResult, PetSex, PetSpecies,
};
use sqlx::{PgPool, Row};
use std::collections::HashMap;
use uuid::Uuid;

use super::food_inventory_rows::FoodInventoryItemRow;

/// parse_pet_species 解析宠物物种数据库值
/// 核心职责：
/// - 将 pet_profiles.species 映射为领域枚举
/// - 在数据库出现未知值时显式暴露基础设施错误
fn parse_pet_species(value: String) -> PetResult<PetSpecies> {
    PetSpecies::try_from(value.as_str())
        .map_err(|_| PetError::Infrastructure(format!("unknown pet species: {value}")))
}

/// parse_pet_sex 解析宠物性别数据库值
/// 核心职责：
/// - 将 pet_profiles.sex 映射为领域枚举
/// - 在数据库出现未知值时显式暴露基础设施错误
fn parse_pet_sex(value: String) -> PetResult<PetSex> {
    PetSex::try_from(value.as_str())
        .map_err(|_| PetError::Infrastructure(format!("unknown pet sex: {value}")))
}

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
                p.species AS pet_species,
                p.sex AS pet_sex,
                p.avatar_asset_id AS pet_avatar_asset_id,
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
                let pet_avatar_asset_id: Option<Uuid> = row.get("pet_avatar_asset_id");
                let pet_species = parse_pet_species(row.get("pet_species"))?;
                let pet_sex = parse_pet_sex(row.get("pet_sex"))?;
                let food_snapshot = payload
                    .get("food_snapshot")
                    .cloned()
                    .and_then(|value| serde_json::from_value::<FoodSnapshot>(value).ok());
                Ok(FoodInventoryFeedingTimelineEntry {
                    event_id: row.get("id"),
                    pet_id: row.get("pet_id"),
                    pet_name: row.get("pet_name"),
                    pet_species,
                    pet_sex,
                    pet_avatar_asset_id,
                    pet_avatar_url: pet_avatar_asset_id
                        .map(|id| format!("/api/v1/media/assets/{id}/content")),
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
                })
            })
            .collect::<PetResult<Vec<_>>>()?;

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
                p.species,
                p.sex,
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
            GROUP BY p.id, p.name, p.species, p.sex, p.avatar_asset_id
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
                species: parse_pet_species(row.get("species"))?,
                sex: parse_pet_sex(row.get("sex"))?,
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
                p.species,
                p.sex,
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
                species: parse_pet_species(row.get("species"))?,
                sex: parse_pet_sex(row.get("sex"))?,
                avatar_asset_id,
                avatar_url: avatar_asset_id.map(|id| format!("/api/v1/media/assets/{id}/content")),
                source: "diet_assignment".to_owned(),
            });
        }

        Ok(linked)
    }
}

fn build_consumption_summary(
    item: &FoodInventoryItem,
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

    let headline = build_consumption_headline(item, feeding_count, active_days);
    let usage_rhythm = build_usage_rhythm(feeding_count, active_days);
    let portion_stability = build_portion_stability(&amount_distribution);
    let calibration_state = build_calibration_state(item);
    let observations = build_consumption_observations(
        item,
        feeding_count,
        &usage_rhythm,
        &portion_stability,
        &calibration_state,
    );

    FoodInventoryConsumptionSummary {
        feeding_count,
        first_fed_at,
        last_fed_at,
        active_days,
        amount_distribution,
        headline,
        usage_rhythm,
        portion_stability,
        calibration_state,
        observations,
    }
}

fn build_consumption_headline(
    item: &FoodInventoryItem,
    feeding_count: i64,
    active_days: i64,
) -> String {
    if feeding_count == 0 {
        return format!("{}还没有喂食记录", item.name);
    }

    format!(
        "{}近 {} 天被记录 {} 次",
        item.name, active_days, feeding_count
    )
}

fn build_usage_rhythm(feeding_count: i64, active_days: i64) -> String {
    if feeding_count == 0 || active_days == 0 {
        return "还没有形成使用节奏".to_owned();
    }

    let daily_average = round_one(count_ratio(feeding_count, active_days));
    if daily_average >= 1.0 {
        format!("平均每天约 {daily_average:.1} 次")
    } else {
        format!("平均约每 {} 天 1 次", (1.0 / daily_average).round())
    }
}

fn build_portion_stability(distribution: &[FoodInventoryAmountDistributionItem]) -> String {
    let Some(primary) = distribution.iter().max_by_key(|item| item.count) else {
        return "还没有份量结构".to_owned();
    };

    format!(
        "以{}为主，占 {}%",
        primary.amount_text,
        percentage_text(primary.ratio)
    )
}

fn build_calibration_state(item: &FoodInventoryItem) -> String {
    match item.package_weight_grams {
        Some(weight) if weight > 0 => "已有规格数据，等待完整库存消耗闭环后输出克数估算".to_owned(),
        _ => "缺少结构化规格，暂不输出克数估算".to_owned(),
    }
}

fn build_consumption_observations(
    item: &FoodInventoryItem,
    feeding_count: i64,
    usage_rhythm: &str,
    portion_stability: &str,
    calibration_state: &str,
) -> Vec<String> {
    if feeding_count == 0 {
        return vec!["开始喂食并关联该物品后，会生成物品维度的消耗趋势。".to_owned()];
    }

    let category_text = food_category_text(item.category);
    vec![
        format!("该物品作为{category_text}参与饮食趋势统计。"),
        usage_rhythm.to_owned(),
        portion_stability.to_owned(),
        calibration_state.to_owned(),
    ]
}

fn food_category_text(category: FoodInventoryCategory) -> &'static str {
    match category {
        FoodInventoryCategory::MainFood => "主粮",
        FoodInventoryCategory::WetFood => "湿粮/罐头",
        FoodInventoryCategory::Treats => "零食",
        FoodInventoryCategory::Nutrition => "营养品",
        FoodInventoryCategory::Other => "其他",
        FoodInventoryCategory::CatLitter => "猫砂",
        FoodInventoryCategory::Medicine => "药品",
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

fn round_one(value: f64) -> f64 {
    (value * 10.0).round() / 10.0
}

fn percentage_text(ratio: f64) -> i64 {
    let value = (ratio * 100.0).round().clamp(0.0, 100.0);
    #[expect(
        clippy::cast_possible_truncation,
        reason = "百分比已四舍五入并限制在 0..=100"
    )]
    {
        value as i64
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
                quantity, unit, spec, package_weight_grams, package_count, package_unit,
                production_date, shelf_life_months, expiry_date,
                cover_asset_id, barcode, source_kind, note
            ) VALUES (
                $1, $2, $3, $4, $5, $6, $7, $8, $9,
                $10, $11, $12, $13, $14, $15, $16,
                CASE
                    WHEN $15::date IS NOT NULL AND $16::integer IS NOT NULL
                    THEN ($15::date + make_interval(months => $16::integer))::date
                    ELSE NULL
                END,
                $17, $18, $19, $20
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
        .bind(input.package_weight_grams)
        .bind(input.package_count)
        .bind(input.package_unit.as_deref())
        .bind(input.production_date)
        .bind(input.shelf_life_months)
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
        let consumption_summary = build_consumption_summary(&item, &feeding_timeline);

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
                package_weight_grams = COALESCE($9, package_weight_grams),
                package_count = COALESCE($10, package_count),
                package_unit = COALESCE($11, package_unit),
                production_date = COALESCE($12, production_date),
                shelf_life_months = COALESCE($13, shelf_life_months),
                expiry_date = CASE
                    WHEN COALESCE($12, production_date) IS NOT NULL
                     AND COALESCE($13, shelf_life_months) IS NOT NULL
                    THEN (COALESCE($12, production_date) + make_interval(months => COALESCE($13, shelf_life_months)))::date
                    ELSE expiry_date
                END,
                cover_asset_id = COALESCE($14, cover_asset_id),
                barcode = COALESCE($15, barcode),
                note = COALESCE($16, note),
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
        .bind(input.package_weight_grams)
        .bind(input.package_count)
        .bind(input.package_unit.as_deref())
        .bind(input.production_date)
        .bind(input.shelf_life_months)
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
                    WHEN inventory_status = 'depleted' THEN 'sealed'
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

#[cfg(test)]
mod tests {
    use chrono::{TimeZone, Utc};

    use super::*;

    #[test]
    fn consumption_summary_exposes_item_analysis() {
        let item = food_item(FoodInventoryCategory::MainFood, Some(2_500));
        let timeline = (1..=30)
            .flat_map(|day| {
                [
                    feeding_entry(day, 8, "正常"),
                    feeding_entry(day, 20, if day % 5 == 0 { "少一点" } else { "正常" }),
                ]
            })
            .collect::<Vec<_>>();

        let summary = build_consumption_summary(&item, &timeline);

        assert_eq!(summary.feeding_count, 60);
        assert_eq!(summary.active_days, 30);
        assert_eq!(summary.headline, "梅录主粮近 30 天被记录 60 次");
        assert_eq!(summary.usage_rhythm, "平均每天约 2.0 次");
        assert!(summary.portion_stability.contains("正常"));
        assert!(summary.calibration_state.contains("完整库存消耗闭环"));
        assert!(
            summary
                .observations
                .iter()
                .any(|item| item.contains("主粮"))
        );
    }

    fn food_item(
        category: FoodInventoryCategory,
        package_weight_grams: Option<i32>,
    ) -> FoodInventoryItem {
        let now = Utc.with_ymd_and_hms(2026, 7, 5, 0, 0, 0).unwrap();
        FoodInventoryItem {
            id: Uuid::new_v4(),
            scope_type: FoodScopeType::User,
            scope_id: Uuid::new_v4(),
            created_by_user_id: Uuid::new_v4(),
            name: "梅录主粮".to_owned(),
            brand: None,
            category,
            inventory_status: FoodInventoryStatus::InUse,
            quantity: 1,
            unit: Some("袋".to_owned()),
            spec: Some("2.5kg".to_owned()),
            package_weight_grams,
            package_count: 1,
            package_unit: Some("袋".to_owned()),
            production_date: None,
            shelf_life_months: None,
            expiry_date: None,
            cover_asset_id: None,
            cover_url: None,
            barcode: None,
            source_kind: maohuoban_pet_domain::pet::FoodSourceKind::Manual,
            note: None,
            created_at: now,
            updated_at: now,
            archived_at: None,
        }
    }

    fn feeding_entry(day: u32, hour: u32, amount_text: &str) -> FoodInventoryFeedingTimelineEntry {
        FoodInventoryFeedingTimelineEntry {
            event_id: Uuid::new_v4(),
            pet_id: Uuid::new_v4(),
            pet_name: "梅录".to_owned(),
            pet_species: PetSpecies::Cat,
            pet_sex: PetSex::Female,
            pet_avatar_asset_id: None,
            pet_avatar_url: None,
            occurred_at: Utc.with_ymd_and_hms(2026, 6, day, hour, 0, 0).unwrap(),
            title: "已喂食".to_owned(),
            summary: None,
            amount_text: amount_text.to_owned(),
            food_role: Some("main_food".to_owned()),
            food_snapshot: None,
        }
    }
}
