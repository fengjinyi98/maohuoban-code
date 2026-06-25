// 生命周期事件仓储实现
// 核心职责：
// - 实现 append_lifecycle_event / list_lifecycle_events
// - 去世不删除档案，只追加事件

use chrono::{DateTime, Utc};
use maohuoban_pet_domain::pet::{LifecycleEventKind, PetError, PetLifecycleEvent, PetResult};
use sqlx::FromRow;
use uuid::Uuid;

use super::storage::to_infrastructure_error;
use crate::postgres::PostgresPetRepository;

#[derive(Debug, FromRow)]
struct LifecycleEventRow {
    id: Uuid,
    pet_id: Uuid,
    event_kind: String,
    from_guardian_type: Option<String>,
    from_guardian_id: Option<Uuid>,
    to_guardian_type: Option<String>,
    to_guardian_id: Option<Uuid>,
    actor_user_id: Option<Uuid>,
    source_ref_type: Option<String>,
    source_ref_id: Option<Uuid>,
    note: Option<String>,
    occurred_at: DateTime<Utc>,
    created_at: DateTime<Utc>,
}

impl TryFrom<LifecycleEventRow> for PetLifecycleEvent {
    type Error = PetError;

    fn try_from(row: LifecycleEventRow) -> Result<Self, Self::Error> {
        Ok(Self {
            id: row.id,
            pet_id: row.pet_id,
            event_kind: LifecycleEventKind::try_from(row.event_kind.as_str()).map_err(|_| {
                PetError::Infrastructure("unknown lifecycle event kind from database".to_owned())
            })?,
            from_guardian_type: row.from_guardian_type,
            from_guardian_id: row.from_guardian_id,
            to_guardian_type: row.to_guardian_type,
            to_guardian_id: row.to_guardian_id,
            actor_user_id: row.actor_user_id,
            source_ref_type: row.source_ref_type,
            source_ref_id: row.source_ref_id,
            note: row.note,
            occurred_at: row.occurred_at,
            created_at: row.created_at,
        })
    }
}

impl PostgresPetRepository {
    /// append_lifecycle_event_command 追加生命周期事件
    /// 核心职责：
    /// - 写入一条新的生命周期事件
    pub(super) async fn append_lifecycle_event_command(
        &self,
        pet_id: Uuid,
        event_kind: LifecycleEventKind,
        actor_user_id: Option<Uuid>,
        note: Option<String>,
    ) -> PetResult<PetLifecycleEvent> {
        let row = sqlx::query_as::<_, LifecycleEventRow>(
            r#"
            INSERT INTO pet_lifecycle_events (
                id,
                pet_id,
                event_kind,
                actor_user_id,
                note,
                occurred_at
            )
            VALUES ($1, $2, $3, $4, $5, now())
            RETURNING
                id,
                pet_id,
                event_kind,
                from_guardian_type,
                from_guardian_id,
                to_guardian_type,
                to_guardian_id,
                actor_user_id,
                source_ref_type,
                source_ref_id,
                note,
                occurred_at,
                created_at
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(pet_id)
        .bind(event_kind.as_str())
        .bind(actor_user_id)
        .bind(&note)
        .fetch_one(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        row.try_into()
    }

    /// list_lifecycle_events_query 查询生命周期事件列表
    /// 核心职责：
    /// - 返回宠物所有生命周期事件，按发生时间倒序
    pub(super) async fn list_lifecycle_events_query(
        &self,
        pet_id: Uuid,
    ) -> PetResult<Vec<PetLifecycleEvent>> {
        let rows = sqlx::query_as::<_, LifecycleEventRow>(
            r#"
            SELECT
                id,
                pet_id,
                event_kind,
                from_guardian_type,
                from_guardian_id,
                to_guardian_type,
                to_guardian_id,
                actor_user_id,
                source_ref_type,
                source_ref_id,
                note,
                occurred_at,
                created_at
            FROM pet_lifecycle_events
            WHERE pet_id = $1
            ORDER BY occurred_at DESC
            "#,
        )
        .bind(pet_id)
        .fetch_all(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        rows.into_iter().map(TryInto::try_into).collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn lifecycle_event_row_try_from_created() {
        let row = LifecycleEventRow {
            id: Uuid::new_v4(),
            pet_id: Uuid::new_v4(),
            event_kind: "created".into(),
            from_guardian_type: None,
            from_guardian_id: None,
            to_guardian_type: None,
            to_guardian_id: None,
            actor_user_id: Some(Uuid::new_v4()),
            source_ref_type: None,
            source_ref_id: None,
            note: None,
            occurred_at: Utc::now(),
            created_at: Utc::now(),
        };
        let event = PetLifecycleEvent::try_from(row).unwrap();
        assert_eq!(event.event_kind, LifecycleEventKind::Created);
    }

    #[test]
    fn lifecycle_event_row_try_from_invalid() {
        let row = LifecycleEventRow {
            id: Uuid::new_v4(),
            pet_id: Uuid::new_v4(),
            event_kind: "invalid".into(),
            from_guardian_type: None,
            from_guardian_id: None,
            to_guardian_type: None,
            to_guardian_id: None,
            actor_user_id: None,
            source_ref_type: None,
            source_ref_id: None,
            note: None,
            occurred_at: Utc::now(),
            created_at: Utc::now(),
        };
        assert!(PetLifecycleEvent::try_from(row).is_err());
    }
}
