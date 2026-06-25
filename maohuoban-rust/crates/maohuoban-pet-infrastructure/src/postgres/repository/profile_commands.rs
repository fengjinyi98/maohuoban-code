use chrono::{Duration, Utc};
use maohuoban_pet_application::pet::{DeletePetProfile, RestorePetProfile};
use maohuoban_pet_domain::pet::{PetError, PetProfile, PetResult};
use sqlx::{Postgres, Transaction};
use uuid::Uuid;

use super::PostgresPetRepository;
use super::rows::PetProfileRow;
use super::storage::to_infrastructure_error;

impl PostgresPetRepository {
    pub(super) async fn soft_delete_pet_profile_command(
        &self,
        input: DeletePetProfile,
    ) -> PetResult<PetProfile> {
        let mut transaction = self.pool.begin().await.map_err(to_infrastructure_error)?;
        let recoverable_until = Utc::now() + Duration::days(30);
        let row = sqlx::query_as::<_, PetProfileRow>(
            r#"
            UPDATE pet_profiles
            SET
                deleted_at = now(),
                delete_requested_by_user_id = $3,
                recoverable_until = $4,
                delete_reason = $5,
                managed_status = 'inactive',
                updated_at = now()
            WHERE id = $1 AND owner_user_id = $2 AND deleted_at IS NULL
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
        .bind(input.owner_user_id)
        .bind(input.owner_user_id)
        .bind(recoverable_until)
        .bind(input.reason)
        .fetch_optional(&mut *transaction)
        .await
        .map_err(to_infrastructure_error)?
        .ok_or(PetError::PetNotFound)?;

        sqlx::query(
            r#"
            UPDATE media_bindings
            SET status = 'deleted', replaced_at = now()
            WHERE pet_id = $1 AND status = 'active'
            "#,
        )
        .bind(input.pet_id)
        .execute(&mut *transaction)
        .await
        .map_err(to_infrastructure_error)?;

        let cleanup_asset_ids = sqlx::query_scalar::<_, Uuid>(
            r#"
            UPDATE media_assets
            SET status = 'cleanup_pending', delete_after = $2, updated_at = now()
            WHERE owner_pet_id = $1 AND deleted_at IS NULL
            RETURNING id
            "#,
        )
        .bind(input.pet_id)
        .bind(recoverable_until)
        .fetch_all(&mut *transaction)
        .await
        .map_err(to_infrastructure_error)?;

        queue_cleanup_jobs(&mut transaction, &cleanup_asset_ids, recoverable_until).await?;
        transaction
            .commit()
            .await
            .map_err(to_infrastructure_error)?;

        row.try_into()
    }

    pub(super) async fn restore_pet_profile_command(
        &self,
        input: RestorePetProfile,
    ) -> PetResult<PetProfile> {
        let mut transaction = self.pool.begin().await.map_err(to_infrastructure_error)?;
        let row = sqlx::query_as::<_, PetProfileRow>(
            r#"
            UPDATE pet_profiles
            SET
                deleted_at = NULL,
                delete_requested_by_user_id = NULL,
                recoverable_until = NULL,
                delete_reason = NULL,
                managed_status = 'family',
                updated_at = now()
            WHERE
                id = $1
                AND owner_user_id = $2
                AND deleted_at IS NOT NULL
                AND recoverable_until > now()
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
        .bind(input.owner_user_id)
        .fetch_optional(&mut *transaction)
        .await
        .map_err(to_infrastructure_error)?
        .ok_or(PetError::PetNotFound)?;

        restore_current_media_bindings(&mut transaction, input.pet_id).await?;
        restore_current_media_assets(&mut transaction, input.pet_id).await?;
        remove_current_media_cleanup_jobs(&mut transaction, input.pet_id).await?;
        transaction
            .commit()
            .await
            .map_err(to_infrastructure_error)?;

        row.try_into()
    }
}

/// queue_cleanup_jobs 为媒体资产创建延迟清理任务
/// 核心职责：
/// - 为待清理资产补充 GC worker 可领取记录
/// - 避免同一资产重复排队
async fn queue_cleanup_jobs(
    transaction: &mut Transaction<'_, Postgres>,
    asset_ids: &[Uuid],
    run_after: chrono::DateTime<Utc>,
) -> PetResult<()> {
    for asset_id in asset_ids {
        sqlx::query(
            r#"
            INSERT INTO media_cleanup_jobs (
                id,
                asset_id,
                status,
                run_after
            )
            SELECT $1, $2, 'queued', $3
            WHERE NOT EXISTS (
                SELECT 1
                FROM media_cleanup_jobs
                WHERE asset_id = $2 AND status IN ('queued', 'running')
            )
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(asset_id)
        .bind(run_after)
        .execute(&mut **transaction)
        .await
        .map_err(to_infrastructure_error)?;
    }

    Ok(())
}

/// restore_current_media_bindings 恢复当前宠物媒体绑定
/// 核心职责：
/// - 只恢复档案当前引用的头像和背景绑定
/// - 保持历史替换绑定继续处于 replaced 状态
async fn restore_current_media_bindings(
    transaction: &mut Transaction<'_, Postgres>,
    pet_id: Uuid,
) -> PetResult<()> {
    sqlx::query(
        r#"
        UPDATE media_bindings
        SET status = 'active', replaced_at = NULL
        WHERE
            pet_id = $1
            AND status = 'deleted'
            AND asset_id IN (
                SELECT avatar_asset_id FROM pet_profiles WHERE id = $1
                UNION
                SELECT background_asset_id FROM pet_profiles WHERE id = $1
            )
        "#,
    )
    .bind(pet_id)
    .execute(&mut **transaction)
    .await
    .map_err(to_infrastructure_error)?;

    Ok(())
}

/// restore_current_media_assets 恢复当前宠物媒体资产
/// 核心职责：
/// - 只恢复档案当前引用的头像和背景资产
/// - 清空恢复窗口内的物理删除时间
async fn restore_current_media_assets(
    transaction: &mut Transaction<'_, Postgres>,
    pet_id: Uuid,
) -> PetResult<()> {
    sqlx::query(
        r#"
        UPDATE media_assets
        SET status = 'bound', delete_after = NULL, updated_at = now()
        WHERE
            owner_pet_id = $1
            AND status = 'cleanup_pending'
            AND id IN (
                SELECT avatar_asset_id FROM pet_profiles WHERE id = $1
                UNION
                SELECT background_asset_id FROM pet_profiles WHERE id = $1
            )
        "#,
    )
    .bind(pet_id)
    .execute(&mut **transaction)
    .await
    .map_err(to_infrastructure_error)?;

    Ok(())
}

/// remove_current_media_cleanup_jobs 移除当前媒体清理任务
/// 核心职责：
/// - 取消恢复宠物仍在使用媒体的待执行清理
/// - 保留历史替换媒体的清理任务
async fn remove_current_media_cleanup_jobs(
    transaction: &mut Transaction<'_, Postgres>,
    pet_id: Uuid,
) -> PetResult<()> {
    sqlx::query(
        r#"
        DELETE FROM media_cleanup_jobs
        WHERE
            status IN ('queued', 'failed')
            AND asset_id IN (
                SELECT avatar_asset_id FROM pet_profiles WHERE id = $1
                UNION
                SELECT background_asset_id FROM pet_profiles WHERE id = $1
            )
        "#,
    )
    .bind(pet_id)
    .execute(&mut **transaction)
    .await
    .map_err(to_infrastructure_error)?;

    Ok(())
}
