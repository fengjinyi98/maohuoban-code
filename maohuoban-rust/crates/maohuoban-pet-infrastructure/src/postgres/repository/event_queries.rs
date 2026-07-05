use maohuoban_pet_application::pet::{
    DeletePetEvent, DeletedPetEvent, NewPetEvent, TradePetImport, TradePetImportInput,
    UpdatePetEvent,
};
use maohuoban_pet_domain::pet::{
    PetError, PetEvent, PetEventAttachmentAsset, PetResult, PetTimeline, PetTimelineEntry,
};
use uuid::Uuid;

use super::PostgresPetRepository;
use super::event_attachments::event_attachment_asset_ids;
use super::event_rows::PetEventRow;
use super::storage::{to_infrastructure_error, to_pet_event_write_error};
use super::trade_import::{insert_trade_import_event, insert_trade_import_pet};

impl PostgresPetRepository {
    pub(super) async fn create_pet_event_command(&self, input: NewPetEvent) -> PetResult<PetEvent> {
        let mut transaction = self.pool.begin().await.map_err(to_infrastructure_error)?;
        let event_id = Uuid::new_v4();
        Self::bind_event_attachment_assets_in_transaction(
            &mut transaction,
            input.pet_id,
            input.actor_user_id,
            &input.event_payload,
        )
        .await?;
        let row = sqlx::query_as::<_, PetEventRow>(
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
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 1)
            RETURNING
                id,
                pet_id,
                litter_id,
                event_kind,
                event_subkind,
                title,
                summary,
                visibility,
                event_payload,
                occurred_at,
                actor_user_id,
                evidence_snapshot_id,
                record_revision,
                created_at,
                updated_at
            "#,
        )
        .bind(event_id)
        .bind(input.pet_id)
        .bind(input.event_kind.as_str())
        .bind(input.event_subkind)
        .bind(input.title)
        .bind(input.summary)
        .bind(input.visibility.as_str())
        .bind(input.event_payload)
        .bind(input.occurred_at)
        .bind(input.actor_user_id)
        .fetch_one(&mut *transaction)
        .await
        .map_err(to_pet_event_write_error)?;

        transaction
            .commit()
            .await
            .map_err(to_infrastructure_error)?;

        row.try_into()
    }

    pub(super) async fn import_trade_pet_command(
        &self,
        input: TradePetImportInput,
    ) -> PetResult<TradePetImport> {
        let mut transaction = self.pool.begin().await.map_err(to_infrastructure_error)?;
        let pet_id = Uuid::new_v4();
        let pet_row = insert_trade_import_pet(&mut transaction, pet_id, &input).await?;
        let event_row = insert_trade_import_event(&mut transaction, pet_id, &input).await?;

        // Phase 1: 同步写入 guardian + lifecycle
        sqlx::query(
            r#"
            INSERT INTO pet_guardians (id, pet_id, guardian_type, guardian_user_id, role, status, started_at)
            VALUES ($1, $2, 'user', $3, 'owner', 'active', now())
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(pet_id)
        .bind(input.owner_user_id)
        .execute(&mut *transaction)
        .await
        .map_err(to_infrastructure_error)?;

        sqlx::query(
            r#"
            INSERT INTO pet_lifecycle_events (id, pet_id, event_kind, actor_user_id, note, occurred_at)
            VALUES ($1, $2, 'imported', $3, $4, now())
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(pet_id)
        .bind(input.owner_user_id)
        .bind::<Option<String>>(None)
        .execute(&mut *transaction)
        .await
        .map_err(to_infrastructure_error)?;

        transaction
            .commit()
            .await
            .map_err(to_infrastructure_error)?;

        Ok(TradePetImport {
            pet: pet_row.try_into()?,
            event: event_row.try_into()?,
        })
    }

    pub(super) async fn load_pet_timeline_query(
        &self,
        owner_user_id: Uuid,
        pet_id: Uuid,
        limit: i64,
    ) -> PetResult<PetTimeline> {
        let rows = sqlx::query_as::<_, PetEventRow>(
            r#"
            SELECT
                e.id,
                e.pet_id,
                e.litter_id,
                e.event_kind,
                e.event_subkind,
                e.title,
                e.summary,
                e.visibility,
                e.event_payload,
                e.occurred_at,
                e.actor_user_id,
                e.evidence_snapshot_id,
                e.record_revision,
                e.created_at,
                e.updated_at
            FROM pet_events e
            INNER JOIN pet_profiles p ON p.id = e.pet_id
            WHERE e.pet_id = $1
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

        let events = rows
            .into_iter()
            .map(TryInto::try_into)
            .collect::<PetResult<Vec<_>>>()?;
        let entries = events
            .iter()
            .filter_map(PetTimelineEntry::from_event)
            .collect();
        Ok(PetTimeline {
            pet_id,
            events,
            entries,
        })
    }

    pub(super) async fn load_pet_event_detail_query(
        &self,
        owner_user_id: Uuid,
        event_id: Uuid,
    ) -> PetResult<Option<PetEvent>> {
        let row = sqlx::query_as::<_, PetEventRow>(
            r#"
            SELECT
                e.id,
                e.pet_id,
                e.litter_id,
                e.event_kind,
                e.event_subkind,
                e.title,
                e.summary,
                e.visibility,
                e.event_payload,
                e.occurred_at,
                e.actor_user_id,
                e.evidence_snapshot_id,
                e.record_revision,
                e.created_at,
                e.updated_at
            FROM pet_events e
            LEFT JOIN pet_profiles p ON p.id = e.pet_id
            LEFT JOIN litters l ON l.id = e.litter_id
            LEFT JOIN merchant_profiles merchant
                ON merchant.id = COALESCE(p.merchant_id, l.merchant_id)
            WHERE e.id = $1
                AND e.superseded_by_event_id IS NULL
                AND (
                    p.owner_user_id = $2
                    OR e.actor_user_id = $2
                    OR EXISTS (
                        SELECT 1 FROM pet_guardians g
                        WHERE g.pet_id = p.id
                          AND g.guardian_user_id = $2
                          AND g.status = 'active'
                    )
                    OR (
                        merchant.owner_user_id = $2
                        AND merchant.verification_status = 'verified'
                    )
                )
            "#,
        )
        .bind(event_id)
        .bind(owner_user_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        let Some(row) = row else {
            return Ok(None);
        };
        let mut event: PetEvent = row.try_into()?;
        event.attachment_assets = self
            .load_event_attachment_assets(event.pet_id, &event.event_payload)
            .await?;
        Ok(Some(event))
    }

    /// load_event_attachment_assets 加载事件附件媒资元数据
    /// 核心职责：
    /// - 从事件 payload 的附件 ID 读取已绑定媒资尺寸
    /// - 为前端大图预览提供稳定尺寸输入
    async fn load_event_attachment_assets(
        &self,
        pet_id: Option<Uuid>,
        event_payload: &serde_json::Value,
    ) -> PetResult<Vec<PetEventAttachmentAsset>> {
        let Some(pet_id) = pet_id else {
            return Ok(Vec::new());
        };
        let asset_ids = event_attachment_asset_ids(event_payload)?;
        if asset_ids.is_empty() {
            return Ok(Vec::new());
        }

        let rows = sqlx::query_as::<_, EventAttachmentAssetRow>(
            r#"
            SELECT id, width, height
            FROM media_assets
            WHERE id = ANY($1)
              AND owner_pet_id = $2
              AND usage_kind = 'pet.event.attachment'
              AND status = 'bound'
              AND deleted_at IS NULL
            "#,
        )
        .bind(&asset_ids)
        .bind(pet_id)
        .fetch_all(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        if rows.len() != asset_ids.len() {
            return Ok(Vec::new());
        }

        let attachment_assets: Vec<PetEventAttachmentAsset> = asset_ids
            .iter()
            .filter_map(|asset_id| {
                rows.iter()
                    .find(|row| row.id == *asset_id)
                    .and_then(EventAttachmentAssetRow::to_domain)
            })
            .collect();
        if attachment_assets.len() != asset_ids.len() {
            return Ok(Vec::new());
        }
        Ok(attachment_assets)
    }

    pub(super) async fn update_pet_event_command(
        &self,
        input: UpdatePetEvent,
    ) -> PetResult<PetEvent> {
        let current = self
            .load_pet_event_detail_query(input.actor_user_id, input.event_id)
            .await?
            .ok_or(PetError::PetEventNotFound)?;
        let pet_id = current.pet_id.ok_or(PetError::PetEventNotFound)?;

        let mut transaction = self.pool.begin().await.map_err(to_infrastructure_error)?;
        Self::bind_event_attachment_assets_in_transaction(
            &mut transaction,
            pet_id,
            input.actor_user_id,
            &input.event_payload,
        )
        .await?;

        let row = sqlx::query_as::<_, PetEventRow>(
            r#"
            UPDATE pet_events
            SET event_kind = $2,
                event_subkind = $3,
                title = $4,
                summary = $5,
                visibility = $6,
                event_payload = $7,
                occurred_at = $8,
                record_revision = record_revision + 1,
                updated_at = now()
            WHERE id = $1
              AND superseded_by_event_id IS NULL
            RETURNING
                id,
                pet_id,
                litter_id,
                event_kind,
                event_subkind,
                title,
                summary,
                visibility,
                event_payload,
                occurred_at,
                actor_user_id,
                evidence_snapshot_id,
                record_revision,
                created_at,
                updated_at
            "#,
        )
        .bind(input.event_id)
        .bind(input.event_kind.as_str())
        .bind(input.event_subkind)
        .bind(input.title)
        .bind(input.summary)
        .bind(input.visibility.as_str())
        .bind(input.event_payload)
        .bind(input.occurred_at)
        .fetch_optional(&mut *transaction)
        .await
        .map_err(to_pet_event_write_error)?;

        transaction
            .commit()
            .await
            .map_err(to_infrastructure_error)?;

        row.ok_or(PetError::PetEventNotFound)?.try_into()
    }

    pub(super) async fn delete_pet_event_command(
        &self,
        input: DeletePetEvent,
    ) -> PetResult<DeletedPetEvent> {
        let mut transaction = self.pool.begin().await.map_err(to_infrastructure_error)?;
        let result = sqlx::query(
            r#"
            UPDATE pet_events e
            SET superseded_by_event_id = e.id, updated_at = now()
            FROM pet_profiles p
            LEFT JOIN merchant_profiles merchant ON merchant.id = p.merchant_id
            WHERE e.id = $1
              AND p.id = e.pet_id
              AND e.superseded_by_event_id IS NULL
              AND (
                  p.owner_user_id = $2
                  OR e.actor_user_id = $2
                  OR EXISTS (
                      SELECT 1 FROM pet_guardians g
                      WHERE g.pet_id = p.id
                        AND g.guardian_user_id = $2
                        AND g.status = 'active'
                  )
                  OR (
                      merchant.owner_user_id = $2
                      AND merchant.verification_status = 'verified'
                  )
              )
            "#,
        )
        .bind(input.event_id)
        .bind(input.actor_user_id)
        .execute(&mut *transaction)
        .await
        .map_err(to_infrastructure_error)?;

        if result.rows_affected() == 0 {
            return Err(PetError::PetEventNotFound);
        }

        let closed_episode_ids = sqlx::query_scalar::<_, Uuid>(
            r#"
            UPDATE abnormal_episodes
            SET status = 'closed',
                next_followup_due_at = NULL,
                last_followup_plan_id = NULL,
                updated_at = now()
            WHERE created_event_id = $1::uuid
              AND status IN ('open', 'watching', 'recovering', 'recovered')
            RETURNING id
            "#,
        )
        .bind(input.event_id)
        .fetch_all(&mut *transaction)
        .await
        .map_err(to_infrastructure_error)?;

        if !closed_episode_ids.is_empty() {
            let closed_episode_id_strings = closed_episode_ids
                .iter()
                .map(Uuid::to_string)
                .collect::<Vec<_>>();
            sqlx::query(
                r#"
                UPDATE pet_events
                SET superseded_by_event_id = id,
                    updated_at = now()
                WHERE event_subkind IN (
                    'symptom_followup',
                    'abnormal_recovery',
                    'clinic_visit_linked'
                )
                  AND superseded_by_event_id IS NULL
                  AND event_payload->>'episode_id' = ANY($1)
                "#,
            )
            .bind(&closed_episode_id_strings)
            .execute(&mut *transaction)
            .await
            .map_err(to_infrastructure_error)?;

            sqlx::query(
                r#"
                UPDATE attention_hints
                SET status = 'resolved',
                    resolved_at = now(),
                    updated_at = now()
                WHERE source_ref_id = ANY($1)
                  AND source_ref_type = 'abnormal_episode'
                  AND kind = 'open_abnormal_episode'
                  AND status = 'active'
                "#,
            )
            .bind(&closed_episode_ids)
            .execute(&mut *transaction)
            .await
            .map_err(to_infrastructure_error)?;

            sqlx::query(
                r#"
                UPDATE agent_proactive_followups
                SET status = 'cancelled',
                    resolved_at = now(),
                    updated_at = now()
                WHERE episode_id = ANY($1)
                  AND status IN ('planning', 'scheduled', 'due')
                "#,
            )
            .bind(&closed_episode_ids)
            .execute(&mut *transaction)
            .await
            .map_err(to_infrastructure_error)?;

            sqlx::query(
                r#"
                UPDATE attention_hints
                SET status = 'resolved',
                    resolved_at = now(),
                    updated_at = now()
                WHERE source_ref_type = 'agent_proactive_followup'
                  AND source_ref_id IN (
                      SELECT id FROM agent_proactive_followups
                      WHERE episode_id = ANY($1)
                  )
                  AND kind = 'abnormal_followup_due'
                  AND status = 'active'
                "#,
            )
            .bind(&closed_episode_ids)
            .execute(&mut *transaction)
            .await
            .map_err(to_infrastructure_error)?;
        }

        transaction
            .commit()
            .await
            .map_err(to_infrastructure_error)?;

        Ok(DeletedPetEvent {
            id: input.event_id,
            deleted: true,
        })
    }
}

#[derive(Debug, sqlx::FromRow)]
struct EventAttachmentAssetRow {
    id: Uuid,
    width: Option<i32>,
    height: Option<i32>,
}

impl EventAttachmentAssetRow {
    fn to_domain(&self) -> Option<PetEventAttachmentAsset> {
        let width = self.width?;
        let height = self.height?;
        if width <= 0 || height <= 0 {
            return None;
        }
        Some(PetEventAttachmentAsset {
            id: self.id,
            url: format!("/api/v1/media/assets/{}/content", self.id),
            width,
            height,
        })
    }
}
