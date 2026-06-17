use async_trait::async_trait;
use maohuoban_pet_application::pet::{
    MerchantAvailableStatusPublication, MerchantLitterDetail, MerchantLitterSummary,
    MerchantRepository, NewMerchantPetProfile, PublishAvailableStatusInput,
};
use maohuoban_pet_domain::pet::{
    ManagedPetStatus, MerchantProfile, MerchantStatusCount, PetError, PetEvent, PetProfile,
    PetRelationship, PetResult,
};
use sqlx::{Postgres, Transaction};
use uuid::Uuid;

use super::PostgresPetRepository;

mod merchant_detail;
mod merchant_helpers;
mod merchant_rows;

use merchant_helpers::{profile_number_from_uuid, to_infrastructure_error};
use merchant_rows::{
    MerchantLitterSummaryRow, MerchantManagedPetRow, MerchantPetEventRow, MerchantProfileRow,
    MerchantStatusCountRow, PetRelationshipRow,
};

impl PostgresPetRepository {
    /// update_merchant_pet_available_status 更新商家宠物可售状态
    /// 核心职责：
    /// - 校验宠物归属当前商家
    /// - 返回更新后的宠物档案行
    async fn update_merchant_pet_available_status(
        transaction: &mut Transaction<'_, Postgres>,
        input: &PublishAvailableStatusInput,
    ) -> PetResult<MerchantManagedPetRow> {
        sqlx::query_as::<_, MerchantManagedPetRow>(
            r#"
            UPDATE pet_profiles
            SET
                managed_status = 'available',
                updated_at = now()
            WHERE id = $1 AND merchant_id = $2
            RETURNING
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
                created_at,
                updated_at
            "#,
        )
        .bind(input.pet_id)
        .bind(input.merchant_id)
        .fetch_optional(&mut **transaction)
        .await
        .map_err(to_infrastructure_error)?
        .ok_or(PetError::PetNotFound)
    }

    /// insert_available_status_event 写入可售状态事件
    /// 核心职责：
    /// - 记录商家发布可售状态的业务事件
    /// - 返回事件账本行用于接口响应
    async fn insert_available_status_event(
        transaction: &mut Transaction<'_, Postgres>,
        input: &PublishAvailableStatusInput,
    ) -> PetResult<MerchantPetEventRow> {
        sqlx::query_as::<_, MerchantPetEventRow>(
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
            VALUES (
                $1,
                $2,
                'merchant',
                'available_status',
                '已发布可售状态',
                $3,
                'buyer_visible',
                $4,
                $5,
                $6,
                1
            )
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
        .bind(Uuid::new_v4())
        .bind(input.pet_id)
        .bind(&input.summary)
        .bind(serde_json::json!({
            "managed_status": "available",
            "merchant_id": input.merchant_id
        }))
        .bind(input.occurred_at)
        .bind(input.actor_user_id)
        .fetch_one(&mut **transaction)
        .await
        .map_err(to_infrastructure_error)
    }
}

#[async_trait]
impl MerchantRepository for PostgresPetRepository {
    async fn find_verified_merchant_for_owner(
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

    async fn load_merchant_status_counts(
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

    async fn list_merchant_litter_summaries(
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

    async fn list_merchant_relationships(
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

    async fn load_merchant_recent_events(
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

    async fn list_merchant_pets(
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

    async fn create_merchant_pet(&self, input: NewMerchantPetProfile) -> PetResult<PetProfile> {
        let pet_id = Uuid::new_v4();
        let row = sqlx::query_as::<_, MerchantManagedPetRow>(
            r#"
            INSERT INTO pet_profiles (
                id,
                merchant_id,
                name,
                species,
                breed,
                sex,
                birthday,
                profile_number,
                managed_status,
                source_kind
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
            RETURNING
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
                created_at,
                updated_at
            "#,
        )
        .bind(pet_id)
        .bind(input.merchant_id)
        .bind(input.name)
        .bind(input.species.as_str())
        .bind(input.breed)
        .bind(input.sex.as_str())
        .bind(input.birthday)
        .bind(profile_number_from_uuid(pet_id))
        .bind(input.managed_status.as_str())
        .bind(input.source_kind.as_str())
        .fetch_one(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        row.try_into()
    }

    async fn publish_available_status(
        &self,
        input: PublishAvailableStatusInput,
    ) -> PetResult<MerchantAvailableStatusPublication> {
        let mut transaction = self.pool.begin().await.map_err(to_infrastructure_error)?;
        let pet_row = Self::update_merchant_pet_available_status(&mut transaction, &input).await?;
        let event_row = Self::insert_available_status_event(&mut transaction, &input).await?;

        transaction
            .commit()
            .await
            .map_err(to_infrastructure_error)?;

        Ok(MerchantAvailableStatusPublication {
            pet: pet_row.try_into()?,
            event: event_row.try_into()?,
        })
    }

    async fn load_merchant_litter_detail(
        &self,
        merchant_id: Uuid,
        litter_id: Uuid,
    ) -> PetResult<Option<MerchantLitterDetail>> {
        self.load_merchant_litter_detail_command(merchant_id, litter_id)
            .await
    }
}
