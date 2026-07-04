use async_trait::async_trait;
use chrono::{DateTime, Utc};

use maohuoban_pet_application::pet::{
    DietContextItem, DietRepository, FoodInventoryChangeHint, FoodInventoryChangeHints,
    PetCurrentDietContext, RecentDietChangeFact, RecentFeedingFact, SetPetCurrentStapleInput,
    SetPetDietAssignmentInput,
};
use maohuoban_pet_domain::pet::{
    DietAssignmentRole, DietTrendFeedingSample, FoodInventoryCategory, FoodInventoryItem,
    FoodScopeType, FoodSnapshot, PetDietAssignment, PetError, PetResult,
};
use sqlx::{PgPool, Row};
use uuid::Uuid;

use super::diet_assignment_rows::DietAssignmentRow;
use super::food_inventory_rows::FoodInventoryItemRow;

#[derive(Debug, Clone)]
pub struct PostgresDietRepository {
    pool: PgPool,
}

impl PostgresDietRepository {
    #[must_use]
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }

    async fn fetch_food_item(&self, id: Uuid) -> Option<FoodInventoryItem> {
        sqlx::query_as::<_, FoodInventoryItemRow>(
            "SELECT * FROM food_inventory_items WHERE id = $1",
        )
        .bind(id)
        .fetch_optional(&self.pool)
        .await
        .ok()
        .flatten()
        .and_then(|row| FoodInventoryItem::try_from(row).ok())
    }
}

#[async_trait]
#[allow(clippy::too_many_lines)]
impl DietRepository for PostgresDietRepository {
    async fn set_current_staple(
        &self,
        input: SetPetCurrentStapleInput,
    ) -> PetResult<PetDietAssignment> {
        let mut tx = self.pool.begin().await.map_err(|error| {
            PetError::Infrastructure(format!("failed to begin transaction: {error}"))
        })?;

        sqlx::query(
            "UPDATE pet_diet_assignments SET status = 'ended', ended_at = now(), updated_at = now() WHERE pet_id = $1 AND role = 'current_staple' AND status = 'active'",
        )
        .bind(input.pet_id)
        .execute(&mut *tx)
        .await
        .map_err(|error| {
            PetError::Infrastructure(format!("failed to end old current_staple: {error}"))
        })?;

        let row: DietAssignmentRow = sqlx::query_as(
            "INSERT INTO pet_diet_assignments (id, pet_id, food_item_id, role, status, reason, created_by_user_id) VALUES ($1, $2, $3, 'current_staple', 'active', $4, $5) RETURNING *",
        )
        .bind(Uuid::new_v4())
        .bind(input.pet_id)
        .bind(input.food_item_id)
        .bind(input.reason.as_deref())
        .bind(input.created_by_user_id)
        .fetch_one(&mut *tx)
        .await
        .map_err(|error| {
            PetError::Infrastructure(format!("failed to create current_staple: {error}"))
        })?;

        tx.commit().await.map_err(|error| {
            PetError::Infrastructure(format!("failed to commit transaction: {error}"))
        })?;

        PetDietAssignment::try_from(row)
    }

    async fn set_assignment(
        &self,
        input: SetPetDietAssignmentInput,
    ) -> PetResult<PetDietAssignment> {
        let row: DietAssignmentRow = sqlx::query_as(
            "INSERT INTO pet_diet_assignments (id, pet_id, food_item_id, role, status, reason, created_by_user_id) VALUES ($1, $2, $3, $4, 'active', $5, $6) RETURNING *",
        )
        .bind(Uuid::new_v4())
        .bind(input.pet_id)
        .bind(input.food_item_id)
        .bind(input.role.as_str())
        .bind(input.reason.as_deref())
        .bind(input.created_by_user_id)
        .fetch_one(&self.pool)
        .await
        .map_err(|error| {
            PetError::Infrastructure(format!("failed to create assignment: {error}"))
        })?;

        PetDietAssignment::try_from(row)
    }

    async fn end_assignment(
        &self,
        pet_id: Uuid,
        assignment_id: Uuid,
        _ended_by_user_id: Uuid,
    ) -> PetResult<PetDietAssignment> {
        let result: Option<DietAssignmentRow> = sqlx::query_as(
            "UPDATE pet_diet_assignments SET status = 'ended', ended_at = now(), updated_at = now() WHERE id = $1 AND pet_id = $2 RETURNING *",
        )
        .bind(assignment_id)
        .bind(pet_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(|error| {
            PetError::Infrastructure(format!("failed to end assignment: {error}"))
        })?;

        match result {
            Some(row) => PetDietAssignment::try_from(row),
            None => Err(PetError::DietAssignmentNotFound),
        }
    }

    async fn list_active_assignments(&self, pet_id: Uuid) -> PetResult<Vec<PetDietAssignment>> {
        let rows: Vec<DietAssignmentRow> = sqlx::query_as(
            "SELECT * FROM pet_diet_assignments WHERE pet_id = $1 AND status = 'active' ORDER BY created_at DESC",
        )
        .bind(pet_id)
        .fetch_all(&self.pool)
        .await
        .map_err(|error| {
            PetError::Infrastructure(format!("failed to list active assignments: {error}"))
        })?;

        rows.into_iter().map(PetDietAssignment::try_from).collect()
    }

    async fn find_current_staple(&self, pet_id: Uuid) -> PetResult<Option<PetDietAssignment>> {
        let result: Option<DietAssignmentRow> = sqlx::query_as(
            "SELECT * FROM pet_diet_assignments WHERE pet_id = $1 AND role = 'current_staple' AND status = 'active' LIMIT 1",
        )
        .bind(pet_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(|error| {
            PetError::Infrastructure(format!("failed to find current staple: {error}"))
        })?;

        result.map(PetDietAssignment::try_from).transpose()
    }

    async fn load_pet_current_diet_context(
        &self,
        pet_id: Uuid,
    ) -> PetResult<PetCurrentDietContext> {
        let assignments = self.list_active_assignments(pet_id).await?;

        let current_staple = {
            let a = assignments
                .iter()
                .find(|a| matches!(a.role, DietAssignmentRole::CurrentStaple));
            match a {
                Some(assignment) => {
                    let food = self.fetch_food_item(assignment.food_item_id).await;
                    Some(DietContextItem {
                        assignment_id: assignment.id,
                        food_item_id: assignment.food_item_id,
                        food_name: food
                            .as_ref()
                            .map_or("已删除的食品".into(), |f| f.name.clone()),
                        food_brand: food.as_ref().and_then(|f| f.brand.clone()),
                        food_category: food
                            .as_ref()
                            .map_or("unknown".into(), |f| f.category.as_str().into()),
                        role: assignment.role.as_str().into(),
                        status: assignment.status.as_str().into(),
                    })
                }
                None => None,
            }
        };

        let mut trying_foods = Vec::new();
        for a in assignments
            .iter()
            .filter(|a| matches!(a.role, DietAssignmentRole::Trying))
        {
            let food = self.fetch_food_item(a.food_item_id).await;
            trying_foods.push(DietContextItem {
                assignment_id: a.id,
                food_item_id: a.food_item_id,
                food_name: food
                    .as_ref()
                    .map_or("已删除的食品".into(), |f| f.name.clone()),
                food_brand: food.as_ref().and_then(|f| f.brand.clone()),
                food_category: food
                    .as_ref()
                    .map_or("unknown".into(), |f| f.category.as_str().into()),
                role: a.role.as_str().into(),
                status: a.status.as_str().into(),
            });
        }

        let mut usual_treats = Vec::new();
        for a in assignments
            .iter()
            .filter(|a| matches!(a.role, DietAssignmentRole::UsualTreat))
        {
            let food = self.fetch_food_item(a.food_item_id).await;
            usual_treats.push(DietContextItem {
                assignment_id: a.id,
                food_item_id: a.food_item_id,
                food_name: food
                    .as_ref()
                    .map_or("已删除的食品".into(), |f| f.name.clone()),
                food_brand: food.as_ref().and_then(|f| f.brand.clone()),
                food_category: food
                    .as_ref()
                    .map_or("unknown".into(), |f| f.category.as_str().into()),
                role: a.role.as_str().into(),
                status: a.status.as_str().into(),
            });
        }

        let mut usual_nutritions = Vec::new();
        for a in assignments
            .iter()
            .filter(|a| matches!(a.role, DietAssignmentRole::UsualNutrition))
        {
            let food = self.fetch_food_item(a.food_item_id).await;
            usual_nutritions.push(DietContextItem {
                assignment_id: a.id,
                food_item_id: a.food_item_id,
                food_name: food
                    .as_ref()
                    .map_or("已删除的食品".into(), |f| f.name.clone()),
                food_brand: food.as_ref().and_then(|f| f.brand.clone()),
                food_category: food
                    .as_ref()
                    .map_or("unknown".into(), |f| f.category.as_str().into()),
                role: a.role.as_str().into(),
                status: a.status.as_str().into(),
            });
        }

        let feeding_rows = sqlx::query(
            "SELECT id, occurred_at, event_payload FROM pet_events WHERE pet_id = $1 AND event_kind = 'daily' AND event_subkind = 'feeding' ORDER BY occurred_at DESC LIMIT 20",
        )
        .bind(pet_id)
        .fetch_all(&self.pool)
        .await
        .map_err(|error| {
            PetError::Infrastructure(format!("failed to load recent feeding events: {error}"))
        })?;

        let mut recent_feeding_events = Vec::new();
        for row in feeding_rows {
            let event_id: Uuid = row.get("id");
            let occurred_at: DateTime<Utc> = row.get("occurred_at");
            let payload: serde_json::Value = row.get("event_payload");

            let food_name = payload
                .get("food_snapshot")
                .and_then(|s| s.get("name"))
                .and_then(|v| v.as_str())
                .unwrap_or("未知食品")
                .to_string();
            let food_snapshot = payload
                .get("food_snapshot")
                .cloned()
                .and_then(|value| serde_json::from_value::<FoodSnapshot>(value).ok());

            recent_feeding_events.push(RecentFeedingFact {
                event_id,
                occurred_at,
                food_item_id: payload
                    .get("food_item_id")
                    .and_then(|v| v.as_str())
                    .and_then(|s| Uuid::parse_str(s).ok()),
                food_name,
                food_snapshot,
            });
        }

        let diet_change_rows = sqlx::query(
            "SELECT id, occurred_at, event_subkind, event_payload FROM pet_events WHERE pet_id = $1 AND event_kind = 'daily' AND event_subkind = 'diet_change' ORDER BY occurred_at DESC LIMIT 20",
        )
        .bind(pet_id)
        .fetch_all(&self.pool)
        .await
        .map_err(|error| {
            PetError::Infrastructure(format!("failed to load recent diet changes: {error}"))
        })?;

        let mut recent_diet_changes = Vec::new();
        for row in diet_change_rows {
            let event_id: Uuid = row.get("id");
            let occurred_at: DateTime<Utc> = row.get("occurred_at");
            let event_subkind: Option<String> = row.get("event_subkind");
            let payload: serde_json::Value = row.get("event_payload");
            let Some(to_food_item_id) = payload
                .get("to_food_item_id")
                .and_then(|v| v.as_str())
                .and_then(|s| Uuid::parse_str(s).ok())
            else {
                continue;
            };
            let Some(assignment_id) = payload
                .get("assignment_id")
                .and_then(|v| v.as_str())
                .and_then(|s| Uuid::parse_str(s).ok())
            else {
                continue;
            };
            let transition_state = payload
                .get("transition_state")
                .and_then(|v| v.as_str())
                .unwrap_or("unknown")
                .to_owned();

            recent_diet_changes.push(RecentDietChangeFact {
                event_id,
                occurred_at,
                event_subkind: event_subkind.unwrap_or_else(|| "diet_change".to_owned()),
                from_food_item_id: payload
                    .get("from_food_item_id")
                    .and_then(|v| v.as_str())
                    .and_then(|s| Uuid::parse_str(s).ok()),
                to_food_item_id,
                assignment_id,
                transition_state,
            });
        }

        Ok(PetCurrentDietContext {
            current_staple,
            trying_foods,
            usual_treats,
            usual_nutritions,
            recent_feeding_events,
            recent_diet_changes,
        })
    }

    async fn load_food_inventory_change_hints(
        &self,
        scope_type: FoodScopeType,
        scope_id: Uuid,
        since: DateTime<Utc>,
    ) -> PetResult<FoodInventoryChangeHints> {
        let rows = sqlx::query(
            r#"
            SELECT food_item_id, item_name, item_category, change_kind, changed_at
            FROM food_inventory_item_changes
            WHERE scope_type = $1 AND scope_id = $2 AND changed_at >= $3
            ORDER BY changed_at DESC
            LIMIT 20
            "#,
        )
        .bind(scope_type.as_str())
        .bind(scope_id)
        .bind(since)
        .fetch_all(&self.pool)
        .await
        .map_err(|error| {
            PetError::Infrastructure(format!(
                "failed to load food inventory change hints: {error}"
            ))
        })?;

        let hints: Vec<FoodInventoryChangeHint> = rows
            .iter()
            .map(|row| FoodInventoryChangeHint {
                item_id: row.get("food_item_id"),
                name: row.get("item_name"),
                category: row.get("item_category"),
                change_kind: row.get("change_kind"),
                changed_at: row.get("changed_at"),
                fact_strength: "weak".to_string(),
            })
            .collect();

        Ok(FoodInventoryChangeHints { hints })
    }

    async fn load_diet_trend_feeding_samples(
        &self,
        pet_id: Uuid,
        since: DateTime<Utc>,
    ) -> PetResult<Vec<DietTrendFeedingSample>> {
        let rows = sqlx::query(
            r#"
            SELECT occurred_at, event_payload
            FROM pet_events
            WHERE pet_id = $1
              AND event_kind = 'daily'
              AND event_subkind = 'feeding'
              AND occurred_at >= $2
              AND superseded_by_event_id IS NULL
            ORDER BY occurred_at ASC
            "#,
        )
        .bind(pet_id)
        .bind(since)
        .fetch_all(&self.pool)
        .await
        .map_err(|error| {
            PetError::Infrastructure(format!(
                "failed to load diet trend feeding samples: {error}"
            ))
        })?;

        let samples = rows
            .into_iter()
            .filter_map(|row| {
                let occurred_at: DateTime<Utc> = row.get("occurred_at");
                let payload: serde_json::Value = row.get("event_payload");
                let category = payload
                    .get("food_role")
                    .and_then(|value| value.as_str())
                    .and_then(|value| FoodInventoryCategory::try_from(value).ok())?;
                let amount_text = payload
                    .get("amount_text")
                    .and_then(|value| value.as_str())
                    .unwrap_or("正常")
                    .to_owned();
                let has_food_item = payload
                    .get("food_item_id")
                    .and_then(|value| value.as_str())
                    .and_then(|value| Uuid::parse_str(value).ok())
                    .is_some();
                let has_inventory_snapshot = payload
                    .get("food_snapshot")
                    .and_then(|value| value.as_object())
                    .is_some_and(|snapshot| {
                        snapshot
                            .get("category")
                            .and_then(|value| value.as_str())
                            .is_some()
                    });
                Some(DietTrendFeedingSample {
                    category,
                    amount_text,
                    occurred_at,
                    has_food_item,
                    has_inventory_snapshot,
                })
            })
            .collect();

        Ok(samples)
    }
}
