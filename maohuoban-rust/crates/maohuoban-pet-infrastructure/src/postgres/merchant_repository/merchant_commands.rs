use maohuoban_pet_application::pet::{
    MerchantAvailableStatusPublication, NewMerchantPetProfile, PublishAvailableStatusInput,
};
use maohuoban_pet_domain::pet::{PetError, PetProfile, PetResult};
use sqlx::{Postgres, Transaction};
use uuid::Uuid;

use super::merchant_helpers::{profile_number_from_uuid, to_infrastructure_error};
use super::merchant_pet_rows::MerchantManagedPetRow;
use super::merchant_rows::MerchantPetEventRow;
use crate::postgres::PostgresPetRepository;

impl PostgresPetRepository {
    pub(super) async fn create_merchant_pet_command(
        &self,
        input: NewMerchantPetProfile,
    ) -> PetResult<PetProfile> {
        let pet_id = Uuid::new_v4();
        let mut transaction = self.pool.begin().await.map_err(to_infrastructure_error)?;
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
                life_status,
                origin_kind,
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
        .fetch_one(&mut *transaction)
        .await
        .map_err(to_infrastructure_error)?;

        // Phase 1: 同步写入 guardian + lifecycle
        sqlx::query(
            r#"
            INSERT INTO pet_guardians (id, pet_id, guardian_type, guardian_merchant_id, role, status, started_at)
            VALUES ($1, $2, 'merchant', $3, 'merchant_manager', 'active', now())
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(pet_id)
        .bind(input.merchant_id)
        .execute(&mut *transaction)
        .await
        .map_err(to_infrastructure_error)?;

        sqlx::query(
            r#"
            INSERT INTO pet_lifecycle_events (id, pet_id, event_kind, actor_user_id, note, occurred_at)
            VALUES ($1, $2, 'created', $3, $4, now())
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(pet_id)
        .bind::<Option<Uuid>>(None)
        .bind::<Option<String>>(None)
        .execute(&mut *transaction)
        .await
        .map_err(to_infrastructure_error)?;

        transaction
            .commit()
            .await
            .map_err(to_infrastructure_error)?;

        row.try_into()
    }

    pub(super) async fn publish_available_status_command(
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
                life_status,
                origin_kind,
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
