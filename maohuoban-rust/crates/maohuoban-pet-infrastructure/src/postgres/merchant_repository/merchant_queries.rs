use maohuoban_pet_application::pet::MerchantLitterSummary;
use maohuoban_pet_domain::pet::{
    ManagedPetStatus, MerchantProfile, MerchantStatusCount, PetEvent, PetProfile, PetRelationship,
    PetResult,
};
use uuid::Uuid;

use super::merchant_helpers::to_infrastructure_error;
use super::merchant_pet_rows::MerchantManagedPetRow;
use super::merchant_rows::{
    MerchantLitterSummaryRow, MerchantPetEventRow, MerchantProfileRow, MerchantStatusCountRow,
    PetRelationshipRow,
};
use crate::postgres::PostgresPetRepository;

impl PostgresPetRepository {
    pub(super) async fn find_verified_merchant_for_owner_query(
        &self,
        owner_user_id: Uuid,
    ) -> PetResult<Option<MerchantProfile>> {
        let row = sqlx::query_as::<_, MerchantProfileRow>(
            r#"
            SELECT
                id,
                owner_user_id,
                merchant_type,
                name,
                city,
                verification_status,
                verified_at,
                created_at,
                updated_at
            FROM merchant_profiles
            WHERE owner_user_id = $1 AND verification_status = 'verified'
            ORDER BY verified_at DESC NULLS LAST, created_at ASC
            LIMIT 1
            "#,
        )
        .bind(owner_user_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        row.map(TryInto::try_into).transpose()
    }

    pub(super) async fn load_merchant_status_counts_query(
        &self,
        merchant_id: Uuid,
    ) -> PetResult<Vec<MerchantStatusCount>> {
        let rows = sqlx::query_as::<_, MerchantStatusCountRow>(
            r#"
            SELECT
                managed_status AS status,
                COUNT(*)::bigint AS count
            FROM pet_profiles
            WHERE merchant_id = $1
                AND managed_status IN (
                    'available',
                    'reserved',
                    'sold',
                    'needs_exam',
                    'needs_record'
                )
            GROUP BY managed_status
            ORDER BY CASE managed_status
                WHEN 'available' THEN 1
                WHEN 'reserved' THEN 2
                WHEN 'sold' THEN 3
                WHEN 'needs_exam' THEN 4
                WHEN 'needs_record' THEN 5
                ELSE 99
            END
            "#,
        )
        .bind(merchant_id)
        .fetch_all(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        rows.into_iter().map(TryInto::try_into).collect()
    }

    pub(super) async fn list_merchant_litter_summaries_query(
        &self,
        merchant_id: Uuid,
        limit: i64,
    ) -> PetResult<Vec<MerchantLitterSummary>> {
        let rows = sqlx::query_as::<_, MerchantLitterSummaryRow>(
            r#"
            SELECT
                l.id,
                l.name,
                sire.name AS sire_name,
                dam.name AS dam_name,
                l.born_at,
                l.born_count,
                l.alive_count,
                COUNT(DISTINCT child.id)
                    FILTER (WHERE child.managed_status = 'available') AS available_count
            FROM litters l
            LEFT JOIN pet_profiles sire ON sire.id = l.sire_pet_id
            LEFT JOIN pet_profiles dam ON dam.id = l.dam_pet_id
            LEFT JOIN pet_relationships rel
                ON rel.litter_id = l.id
                AND rel.relationship_kind = 'same_litter'
            LEFT JOIN pet_profiles child
                ON child.id = rel.subject_pet_id
                AND child.merchant_id = l.merchant_id
            WHERE l.merchant_id = $1
            GROUP BY
                l.id,
                l.name,
                sire.name,
                dam.name,
                l.born_at,
                l.born_count,
                l.alive_count
            ORDER BY l.born_at DESC, l.created_at DESC
            LIMIT $2
            "#,
        )
        .bind(merchant_id)
        .bind(limit)
        .fetch_all(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        Ok(rows.into_iter().map(Into::into).collect())
    }

    pub(super) async fn list_merchant_relationships_query(
        &self,
        merchant_id: Uuid,
        limit: i64,
    ) -> PetResult<Vec<PetRelationship>> {
        let rows = sqlx::query_as::<_, PetRelationshipRow>(
            r#"
            SELECT
                rel.id,
                rel.subject_pet_id,
                rel.related_pet_id,
                rel.litter_id,
                rel.relationship_kind,
                rel.source_kind,
                rel.evidence_snapshot_id,
                rel.created_at
            FROM pet_relationships rel
            INNER JOIN pet_profiles subject ON subject.id = rel.subject_pet_id
            LEFT JOIN litters l ON l.id = rel.litter_id
            WHERE subject.merchant_id = $1 OR l.merchant_id = $1
            ORDER BY rel.created_at DESC
            LIMIT $2
            "#,
        )
        .bind(merchant_id)
        .bind(limit)
        .fetch_all(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        rows.into_iter().map(TryInto::try_into).collect()
    }

    pub(super) async fn load_merchant_recent_events_query(
        &self,
        merchant_id: Uuid,
        limit: i64,
    ) -> PetResult<Vec<PetEvent>> {
        let rows = sqlx::query_as::<_, MerchantPetEventRow>(
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
            WHERE p.merchant_id = $1 OR l.merchant_id = $1
            ORDER BY e.occurred_at DESC, e.created_at DESC
            LIMIT $2
            "#,
        )
        .bind(merchant_id)
        .bind(limit)
        .fetch_all(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        rows.into_iter().map(TryInto::try_into).collect()
    }

    pub(super) async fn list_merchant_pets_query(
        &self,
        merchant_id: Uuid,
        status: ManagedPetStatus,
        limit: i64,
    ) -> PetResult<Vec<PetProfile>> {
        let rows = sqlx::query_as::<_, MerchantManagedPetRow>(
            r#"
            SELECT
                id,
                owner_user_id,
                merchant_id,
                name,
                species,
                breed,
                sex,
                birthday,
                profile_number,
                microchip_number,
                arrival_date,
                weight_grams,
                neuter_status,
                personality_tags,
                note,
                avatar_asset_id,
                background_asset_id,
                background_media_kind,
                deleted_at,
                delete_requested_by_user_id,
                recoverable_until,
                delete_reason,
                managed_status,
                source_kind,
                life_status,
                origin_kind,
                created_at,
                updated_at
            FROM pet_profiles
            WHERE merchant_id = $1 AND managed_status = $2 AND deleted_at IS NULL
            ORDER BY created_at ASC, name ASC
            LIMIT $3
            "#,
        )
        .bind(merchant_id)
        .bind(status.as_str())
        .bind(limit)
        .fetch_all(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        rows.into_iter().map(TryInto::try_into).collect()
    }
}
