use maohuoban_pet_application::pet::{NewPetEvent, TradePetImport, TradePetImportInput};
use maohuoban_pet_domain::pet::{PetEvent, PetResult, PetTimeline};
use uuid::Uuid;

use super::PostgresPetRepository;
use super::event_rows::PetEventRow;
use super::storage::to_infrastructure_error;
use super::trade_import::{insert_trade_import_event, insert_trade_import_pet};

impl PostgresPetRepository {
    pub(super) async fn create_pet_event_command(&self, input: NewPetEvent) -> PetResult<PetEvent> {
        let event_id = Uuid::new_v4();
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
        .fetch_one(&self.pool)
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
            WHERE e.pet_id = $1 AND p.owner_user_id = $2
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
        Ok(PetTimeline { pet_id, events })
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
                AND (
                    p.owner_user_id = $2
                    OR e.actor_user_id = $2
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

        row.map(TryInto::try_into).transpose()
    }
}
