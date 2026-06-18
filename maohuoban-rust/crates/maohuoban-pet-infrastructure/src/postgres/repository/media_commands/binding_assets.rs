use chrono::{Duration, Utc};
use maohuoban_pet_domain::pet::{MediaAsset, MediaUsageKind, PetError, PetResult};
use sqlx::{Postgres, Transaction};
use uuid::Uuid;

use crate::postgres::repository::PostgresPetRepository;
use crate::postgres::repository::rows::MediaAssetRow;
use crate::postgres::repository::storage::to_infrastructure_error;

impl PostgresPetRepository {
    /// queue_replaced_media 将旧媒体绑定加入清理队列
    /// 核心职责：
    /// - 标记当前用途下旧绑定为已替换
    /// - 为旧资产创建延迟清理任务
    pub(super) async fn queue_replaced_media(
        transaction: &mut Transaction<'_, Postgres>,
        pet_id: Uuid,
        usage_kind: MediaUsageKind,
    ) -> PetResult<()> {
        let replaced_asset_ids = sqlx::query_scalar::<_, Uuid>(
            r#"
            UPDATE media_bindings
            SET status = 'replaced', replaced_at = now()
            WHERE pet_id = $1 AND usage_kind = $2 AND status = 'active'
            RETURNING asset_id
            "#,
        )
        .bind(pet_id)
        .bind(usage_kind.as_str())
        .fetch_all(&mut **transaction)
        .await
        .map_err(to_infrastructure_error)?;

        let cleanup_at = Utc::now() + Duration::days(7);
        for replaced_asset_id in replaced_asset_ids {
            sqlx::query(
                r#"
                UPDATE media_assets
                SET status = 'cleanup_pending', delete_after = $2, updated_at = now()
                WHERE id = $1
                "#,
            )
            .bind(replaced_asset_id)
            .bind(cleanup_at)
            .execute(&mut **transaction)
            .await
            .map_err(to_infrastructure_error)?;

            sqlx::query(
                r#"
                INSERT INTO media_cleanup_jobs (
                    id,
                    asset_id,
                    status,
                    run_after
                )
                VALUES ($1, $2, 'queued', $3)
                "#,
            )
            .bind(Uuid::new_v4())
            .bind(replaced_asset_id)
            .bind(cleanup_at)
            .execute(&mut **transaction)
            .await
            .map_err(to_infrastructure_error)?;
        }

        Ok(())
    }

    pub(super) async fn select_owned_media_asset_for_binding(
        transaction: &mut Transaction<'_, Postgres>,
        asset_id: Uuid,
        owner_user_id: Uuid,
    ) -> PetResult<MediaAsset> {
        let row = sqlx::query_as::<_, MediaAssetRow>(
            r#"
            SELECT
                id,
                uploaded_by_user_id,
                owner_pet_id,
                usage_kind,
                source_client,
                original_file_name,
                mime_type,
                byte_size,
                sha256_hex,
                bucket,
                object_key,
                status,
                width,
                height,
                delete_after,
                deleted_at,
                created_at,
                updated_at
            FROM media_assets
            WHERE
                id = $1
                AND uploaded_by_user_id = $2
                AND status = 'uploaded'
                AND deleted_at IS NULL
            "#,
        )
        .bind(asset_id)
        .bind(owner_user_id)
        .fetch_optional(&mut **transaction)
        .await
        .map_err(to_infrastructure_error)?
        .ok_or(PetError::PetNotFound)?;

        row.try_into()
    }

    pub(super) async fn mark_media_asset_bound(
        transaction: &mut Transaction<'_, Postgres>,
        asset_id: Uuid,
        pet_id: Uuid,
    ) -> PetResult<MediaAssetRow> {
        sqlx::query_as::<_, MediaAssetRow>(
            r#"
            UPDATE media_assets
            SET owner_pet_id = $2, status = 'bound', updated_at = now()
            WHERE id = $1 AND status = 'uploaded'
            RETURNING
                id,
                uploaded_by_user_id,
                owner_pet_id,
                usage_kind,
                source_client,
                original_file_name,
                mime_type,
                byte_size,
                sha256_hex,
                bucket,
                object_key,
                status,
                width,
                height,
                delete_after,
                deleted_at,
                created_at,
                updated_at
            "#,
        )
        .bind(asset_id)
        .bind(pet_id)
        .fetch_one(&mut **transaction)
        .await
        .map_err(to_infrastructure_error)
    }
}
