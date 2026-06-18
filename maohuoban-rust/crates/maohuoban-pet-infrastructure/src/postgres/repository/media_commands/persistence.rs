use maohuoban_pet_domain::pet::PetResult;
use sqlx::{Postgres, Transaction};
use uuid::Uuid;

use super::diagnostics::record_upload_failure;
use super::{
    MediaUploadObjectInput, PreparedMediaComponent, PreparedMediaDerivative, PreparedMediaObject,
};
use crate::postgres::repository::PostgresPetRepository;
use crate::postgres::repository::rows::{
    MediaAssetComponentRow, MediaAssetRow, MediaDerivativeRow,
};
use crate::postgres::repository::storage::to_infrastructure_error;

impl PostgresPetRepository {
    pub(super) async fn insert_pending_media_upload(
        &self,
        object_input: &MediaUploadObjectInput<'_>,
        prepared: &PreparedMediaObject,
        prepared_derivatives: &[PreparedMediaDerivative],
    ) -> PetResult<(MediaAssetRow, Vec<MediaDerivativeRow>)> {
        let mut transaction = match self.pool.begin().await.map_err(to_infrastructure_error) {
            Ok(transaction) => transaction,
            Err(error) => {
                record_upload_failure(
                    object_input,
                    Some(prepared.asset_id),
                    "repository.transaction_started",
                );
                return Err(error);
            }
        };
        let asset_row =
            match Self::insert_media_asset(&mut transaction, object_input, prepared, "uploaded")
                .await
            {
                Ok(asset_row) => asset_row,
                Err(error) => {
                    record_upload_failure(
                        object_input,
                        Some(prepared.asset_id),
                        "repository.asset_inserted",
                    );
                    return Err(error);
                }
            };
        let derivative_rows = match Self::insert_media_derivatives(
            &mut transaction,
            prepared.asset_id,
            prepared_derivatives,
        )
        .await
        {
            Ok(derivative_rows) => derivative_rows,
            Err(error) => {
                record_upload_failure(
                    object_input,
                    Some(prepared.asset_id),
                    "repository.derivatives_inserted",
                );
                return Err(error);
            }
        };
        if let Err(error) = transaction.commit().await.map_err(to_infrastructure_error) {
            record_upload_failure(
                object_input,
                Some(prepared.asset_id),
                "repository.committed",
            );
            return Err(error);
        }
        Ok((asset_row, derivative_rows))
    }

    pub(super) async fn insert_pending_live_photo_upload(
        &self,
        object_input: &MediaUploadObjectInput<'_>,
        prepared: &PreparedMediaObject,
        prepared_components: &[PreparedMediaComponent],
        prepared_derivatives: &[PreparedMediaDerivative],
    ) -> PetResult<(
        MediaAssetRow,
        Vec<MediaAssetComponentRow>,
        Vec<MediaDerivativeRow>,
    )> {
        let mut transaction = self.pool.begin().await.map_err(to_infrastructure_error)?;
        let asset_row =
            Self::insert_media_asset(&mut transaction, object_input, prepared, "uploaded").await?;
        let component_rows = Self::insert_media_asset_components(
            &mut transaction,
            prepared.asset_id,
            prepared_components,
        )
        .await?;
        let derivative_rows = Self::insert_media_derivatives(
            &mut transaction,
            prepared.asset_id,
            prepared_derivatives,
        )
        .await?;
        transaction
            .commit()
            .await
            .map_err(to_infrastructure_error)?;
        Ok((asset_row, component_rows, derivative_rows))
    }

    /// insert_media_asset 写入媒体资产记录
    /// 核心职责：
    /// - 保存上传来源和对象存储位置
    /// - 返回数据库标准化后的资产行
    pub(super) async fn insert_media_asset(
        transaction: &mut Transaction<'_, Postgres>,
        input: &MediaUploadObjectInput<'_>,
        prepared: &PreparedMediaObject,
        status: &str,
    ) -> PetResult<MediaAssetRow> {
        sqlx::query_as::<_, MediaAssetRow>(
            r#"
            INSERT INTO media_assets (
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
                height
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
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
        .bind(prepared.asset_id)
        .bind(input.owner_user_id)
        .bind(input.pet_id)
        .bind(input.usage_kind.as_str())
        .bind(input.source_client)
        .bind(input.file_name)
        .bind(input.mime_type)
        .bind(prepared.byte_size)
        .bind(&prepared.sha256_hex)
        .bind(&prepared.bucket)
        .bind(&prepared.object_key)
        .bind(status)
        .bind(prepared.width)
        .bind(prepared.height)
        .fetch_one(&mut **transaction)
        .await
        .map_err(to_infrastructure_error)
    }

    /// insert_media_derivatives 写入媒体派生记录
    /// 核心职责：
    /// - 持久化缩略图、封面帧和主题色派生对象索引
    /// - 返回数据库标准化后的派生记录
    pub(super) async fn insert_media_derivatives(
        transaction: &mut Transaction<'_, Postgres>,
        asset_id: Uuid,
        derivatives: &[PreparedMediaDerivative],
    ) -> PetResult<Vec<MediaDerivativeRow>> {
        let mut rows = Vec::with_capacity(derivatives.len());
        for derivative in derivatives {
            let row = sqlx::query_as::<_, MediaDerivativeRow>(
                r#"
                INSERT INTO media_derivatives (
                    id,
                    parent_asset_id,
                    derivative_kind,
                    bucket,
                    object_key,
                    mime_type,
                    byte_size,
                    sha256_hex,
                    metadata
                )
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
                RETURNING
                    id,
                    parent_asset_id,
                    derivative_kind,
                    bucket,
                    object_key,
                    mime_type,
                    byte_size,
                    sha256_hex,
                    metadata,
                    created_at
                "#,
            )
            .bind(derivative.id)
            .bind(asset_id)
            .bind(derivative.derivative_kind.as_str())
            .bind(&derivative.bucket)
            .bind(&derivative.object_key)
            .bind(&derivative.mime_type)
            .bind(derivative.byte_size)
            .bind(&derivative.sha256_hex)
            .bind(&derivative.metadata)
            .fetch_one(&mut **transaction)
            .await
            .map_err(to_infrastructure_error)?;
            rows.push(row);
        }

        Ok(rows)
    }

    pub(super) async fn insert_media_asset_components(
        transaction: &mut Transaction<'_, Postgres>,
        asset_id: Uuid,
        components: &[PreparedMediaComponent],
    ) -> PetResult<Vec<MediaAssetComponentRow>> {
        let mut rows = Vec::with_capacity(components.len());
        for component in components {
            let row = sqlx::query_as::<_, MediaAssetComponentRow>(
                r#"
                INSERT INTO media_asset_components (
                    id,
                    asset_id,
                    component_kind,
                    bucket,
                    object_key,
                    mime_type,
                    byte_size,
                    sha256_hex,
                    width,
                    height,
                    duration_ms
                )
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
                RETURNING
                    id,
                    asset_id,
                    component_kind,
                    bucket,
                    object_key,
                    mime_type,
                    byte_size,
                    sha256_hex,
                    width,
                    height,
                    duration_ms,
                    created_at
                "#,
            )
            .bind(component.id)
            .bind(asset_id)
            .bind(component.component_kind.as_str())
            .bind(&component.bucket)
            .bind(&component.object_key)
            .bind(&component.mime_type)
            .bind(component.byte_size)
            .bind(&component.sha256_hex)
            .bind(component.width)
            .bind(component.height)
            .bind(component.duration_ms)
            .fetch_one(&mut **transaction)
            .await
            .map_err(to_infrastructure_error)?;
            rows.push(row);
        }
        Ok(rows)
    }
}
