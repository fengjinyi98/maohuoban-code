use maohuoban_pet_application::pet::{
    DeletePetWeightRecord, DeletedPetWeightRecord, NewPetWeightRecord, PetWeightRecord,
    PetWeightRecordSource, UpdatePetWeightRecord,
};
use maohuoban_pet_domain::pet::{PetError, PetResult};
use serde_json::Value;
use sqlx::FromRow;
use uuid::Uuid;

use super::PostgresPetRepository;
use super::storage::to_infrastructure_error;

/// WeightRecordRow 体重记录数据库行
/// 核心职责：
/// - 从 pet_events 投影体重专用读模型
/// - 隔离 JSON payload 字段解析
#[derive(Debug, FromRow)]
struct WeightRecordRow {
    id: Uuid,
    pet_id: Uuid,
    event_payload: Value,
    occurred_at: chrono::DateTime<chrono::Utc>,
    record_revision: i32,
    created_at: chrono::DateTime<chrono::Utc>,
    updated_at: chrono::DateTime<chrono::Utc>,
}

impl TryFrom<WeightRecordRow> for PetWeightRecord {
    type Error = PetError;

    fn try_from(row: WeightRecordRow) -> Result<Self, Self::Error> {
        let weight_grams = row
            .event_payload
            .get("weight_grams")
            .and_then(serde_json::Value::as_i64)
            .and_then(|value| i32::try_from(value).ok())
            .ok_or_else(|| PetError::Infrastructure("weight record missing grams".to_owned()))?;
        let note = row
            .event_payload
            .get("note")
            .and_then(serde_json::Value::as_str)
            .map(ToOwned::to_owned);
        let source = match row
            .event_payload
            .get("source")
            .and_then(serde_json::Value::as_str)
        {
            Some("profile_initial") => PetWeightRecordSource::ProfileInitial,
            _ => PetWeightRecordSource::Manual,
        };

        Ok(Self {
            id: row.id,
            pet_id: row.pet_id,
            weight_grams,
            note,
            source,
            occurred_at: row.occurred_at,
            record_revision: row.record_revision,
            created_at: row.created_at,
            updated_at: row.updated_at,
        })
    }
}

impl PostgresPetRepository {
    pub(super) async fn create_pet_weight_record_command(
        &self,
        input: NewPetWeightRecord,
    ) -> PetResult<PetWeightRecord> {
        insert_weight_event(
            &self.pool,
            Uuid::new_v4(),
            input.pet_id,
            input.actor_user_id,
            input.weight_grams,
            input.note,
            input.source,
            input.occurred_at,
            1,
        )
        .await
    }

    pub(super) async fn list_pet_weight_records_query(
        &self,
        owner_user_id: Uuid,
        pet_id: Uuid,
        limit: i64,
    ) -> PetResult<Vec<PetWeightRecord>> {
        let rows = sqlx::query_as::<_, WeightRecordRow>(
            r#"
            SELECT
                e.id,
                e.pet_id,
                e.event_payload,
                e.occurred_at,
                e.record_revision,
                e.created_at,
                e.updated_at
            FROM pet_events e
            INNER JOIN pet_profiles p ON p.id = e.pet_id
            WHERE e.pet_id = $1
              AND e.event_kind = 'health'
              AND e.event_subkind = 'weight'
              AND e.superseded_by_event_id IS NULL
              AND (
                  p.owner_user_id = $2
                  OR EXISTS (
                      SELECT 1 FROM pet_guardians g
                      WHERE g.pet_id = p.id AND g.guardian_user_id = $2 AND g.status = 'active'
                  )
              )
            ORDER BY e.occurred_at DESC, e.created_at DESC
            LIMIT $3
            "#,
        )
        .bind(pet_id)
        .bind(owner_user_id)
        .bind(limit)
        .fetch_all(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        rows.into_iter()
            .map(TryInto::try_into)
            .collect::<PetResult<Vec<_>>>()
    }

    pub(super) async fn load_pet_weight_record_query(
        &self,
        owner_user_id: Uuid,
        record_id: Uuid,
    ) -> PetResult<Option<PetWeightRecord>> {
        let row = sqlx::query_as::<_, WeightRecordRow>(
            r#"
            SELECT
                e.id,
                e.pet_id,
                e.event_payload,
                e.occurred_at,
                e.record_revision,
                e.created_at,
                e.updated_at
            FROM pet_events e
            INNER JOIN pet_profiles p ON p.id = e.pet_id
            WHERE e.id = $1
              AND e.event_kind = 'health'
              AND e.event_subkind = 'weight'
              AND e.superseded_by_event_id IS NULL
              AND (
                  p.owner_user_id = $2
                  OR EXISTS (
                      SELECT 1 FROM pet_guardians g
                      WHERE g.pet_id = p.id AND g.guardian_user_id = $2 AND g.status = 'active'
                  )
              )
            "#,
        )
        .bind(record_id)
        .bind(owner_user_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        row.map(TryInto::try_into).transpose()
    }

    pub(super) async fn update_pet_weight_record_command(
        &self,
        input: UpdatePetWeightRecord,
    ) -> PetResult<PetWeightRecord> {
        let current = self
            .load_pet_weight_record_query(input.actor_user_id, input.record_id)
            .await?
            .ok_or(PetError::WeightRecordNotFound)?;
        let payload = weight_payload(input.weight_grams, input.note, current.source);
        let summary = weight_summary(input.weight_grams);
        let row = sqlx::query_as::<_, WeightRecordRow>(
            r#"
            UPDATE pet_events
            SET summary = $2,
                event_payload = $3,
                occurred_at = $4,
                record_revision = record_revision + 1,
                updated_at = now()
            WHERE id = $1 AND superseded_by_event_id IS NULL
            RETURNING
                id,
                pet_id,
                event_payload,
                occurred_at,
                record_revision,
                created_at,
                updated_at
            "#,
        )
        .bind(input.record_id)
        .bind(summary)
        .bind(payload)
        .bind(input.occurred_at)
        .fetch_optional(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        row.ok_or(PetError::WeightRecordNotFound)?.try_into()
    }

    pub(super) async fn delete_pet_weight_record_command(
        &self,
        input: DeletePetWeightRecord,
    ) -> PetResult<DeletedPetWeightRecord> {
        let result = sqlx::query(
            r#"
            UPDATE pet_events e
            SET superseded_by_event_id = e.id, updated_at = now()
            FROM pet_profiles p
            WHERE e.id = $1
              AND p.id = e.pet_id
              AND e.event_kind = 'health'
              AND e.event_subkind = 'weight'
              AND e.superseded_by_event_id IS NULL
              AND (
                  p.owner_user_id = $2
                  OR EXISTS (
                      SELECT 1 FROM pet_guardians g
                      WHERE g.pet_id = p.id AND g.guardian_user_id = $2 AND g.status = 'active'
                  )
              )
            "#,
        )
        .bind(input.record_id)
        .bind(input.actor_user_id)
        .execute(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        if result.rows_affected() == 0 {
            return Err(PetError::WeightRecordNotFound);
        }

        Ok(DeletedPetWeightRecord {
            id: input.record_id,
            deleted: true,
        })
    }
}

#[allow(clippy::too_many_arguments)]
async fn insert_weight_event(
    pool: &sqlx::PgPool,
    event_id: Uuid,
    pet_id: Uuid,
    actor_user_id: Uuid,
    weight_grams: i32,
    note: Option<String>,
    source: PetWeightRecordSource,
    occurred_at: chrono::DateTime<chrono::Utc>,
    record_revision: i32,
) -> PetResult<PetWeightRecord> {
    let payload = weight_payload(weight_grams, note, source);
    let summary = weight_summary(weight_grams);
    let row = sqlx::query_as::<_, WeightRecordRow>(
        r#"
        INSERT INTO pet_events (
            id,
            pet_id,
            event_kind,
            event_subkind,
            title,
            summary,
            visibility,
            event_payload,
            occurred_at,
            actor_user_id,
            record_revision
        )
        VALUES ($1, $2, 'health', 'weight', '体重记录', $3, 'private', $4, $5, $6, $7)
        RETURNING
            id,
            pet_id,
            event_payload,
            occurred_at,
            record_revision,
            created_at,
            updated_at
        "#,
    )
    .bind(event_id)
    .bind(pet_id)
    .bind(summary)
    .bind(payload)
    .bind(occurred_at)
    .bind(actor_user_id)
    .bind(record_revision)
    .fetch_one(pool)
    .await
    .map_err(to_infrastructure_error)?;

    row.try_into()
}

fn weight_payload(weight_grams: i32, note: Option<String>, source: PetWeightRecordSource) -> Value {
    serde_json::json!({
        "weight_grams": weight_grams,
        "weight_kg": f64::from(weight_grams) / 1000.0,
        "note": note,
        "source": source.as_str(),
    })
}

fn weight_summary(weight_grams: i32) -> String {
    format!("{:.2}kg", f64::from(weight_grams) / 1000.0)
}
