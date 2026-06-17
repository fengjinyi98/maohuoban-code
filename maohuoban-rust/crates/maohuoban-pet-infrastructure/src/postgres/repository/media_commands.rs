mod derivatives;
mod diagnostics;

use std::io::Cursor;

use chrono::{Duration, Utc};
use image::ImageFormat;
use maohuoban_media_storage::MediaObjectStore;
use maohuoban_pet_application::pet::{
    BindUploadedPetMediaInput, PendingPetLivePhotoUploadInput, PendingPetMediaUploadInput,
};
use maohuoban_pet_domain::pet::{
    MediaAsset, MediaAssetComponent, MediaAssetComponentKind, MediaDerivative, MediaDerivativeKind,
    MediaUsageKind, PetBackgroundMediaKind, PetError, PetMediaUploadResult, PetResult,
};
use serde_json::Value;
use sqlx::{Postgres, Transaction};
use uuid::Uuid;

use super::PostgresPetRepository;
use super::rows::{MediaAssetComponentRow, MediaAssetRow, MediaBindingRow, MediaDerivativeRow};
use super::storage::{sanitized_file_name, sha256_hex, to_infrastructure_error};
use derivatives::{average_theme_color, prepare_derivative_object, prepare_video_derivatives};
use diagnostics::{record_binding_stage, record_upload_failure, record_upload_stage};

/// PreparedMediaObject 已持久化媒体对象
/// 核心职责：
/// - 保存数据库写入前生成的对象存储字段
/// - 避免上传命令在事务内重复计算对象元数据
pub(super) struct PreparedMediaObject {
    pub(super) asset_id: Uuid,
    pub(super) bucket: String,
    pub(super) object_key: String,
    pub(super) sha256_hex: String,
    pub(super) byte_size: i64,
    pub(super) width: Option<i32>,
    pub(super) height: Option<i32>,
}

/// MediaUploadObjectInput 媒体对象写入上下文
/// 核心职责：
/// - 统一 pending 上传的对象字段
/// - 避免派生生成逻辑分叉
pub(super) struct MediaUploadObjectInput<'a> {
    pub(super) owner_user_id: Uuid,
    pub(super) pet_id: Option<Uuid>,
    pub(super) usage_kind: MediaUsageKind,
    pub(super) file_name: &'a str,
    pub(super) mime_type: &'a str,
    pub(super) content: &'a [u8],
    pub(super) source_client: Option<&'a str>,
}

impl<'a> From<&'a PendingPetMediaUploadInput> for MediaUploadObjectInput<'a> {
    fn from(input: &'a PendingPetMediaUploadInput) -> Self {
        Self {
            owner_user_id: input.owner_user_id,
            pet_id: None,
            usage_kind: input.usage_kind,
            file_name: &input.file_name,
            mime_type: &input.mime_type,
            content: &input.content,
            source_client: input.source_client.as_deref(),
        }
    }
}

/// PreparedMediaDerivative 已持久化派生媒体对象
/// 核心职责：
/// - 保存派生对象写入后的元数据
/// - 为数据库派生记录提供统一输入
pub(super) struct PreparedMediaDerivative {
    pub(super) id: Uuid,
    pub(super) derivative_kind: MediaDerivativeKind,
    pub(super) bucket: String,
    pub(super) object_key: String,
    pub(super) mime_type: String,
    pub(super) byte_size: i64,
    pub(super) sha256_hex: String,
    pub(super) metadata: Value,
}

/// PreparedMediaComponent 已持久化媒体组件对象
/// 核心职责：
/// - 保存组合媒体组件对象字段
/// - 为 Live Photo 静态图和配对视频提供独立寻址
pub(super) struct PreparedMediaComponent {
    pub(super) id: Uuid,
    pub(super) component_kind: MediaAssetComponentKind,
    pub(super) bucket: String,
    pub(super) object_key: String,
    pub(super) mime_type: String,
    pub(super) byte_size: i64,
    pub(super) sha256_hex: String,
    pub(super) width: Option<i32>,
    pub(super) height: Option<i32>,
    pub(super) duration_ms: Option<i32>,
}

impl PostgresPetRepository {
    pub(super) async fn upload_pending_pet_media_command(
        &self,
        input: PendingPetMediaUploadInput,
    ) -> PetResult<PetMediaUploadResult> {
        let object_input = MediaUploadObjectInput::from(&input);
        let media_store = match MediaObjectStore::from_env() {
            Ok(media_store) => media_store,
            Err(error) => {
                record_upload_failure(&object_input, None, "repository.store_config");
                return Err(PetError::Infrastructure(error.to_string()));
            }
        };
        let mut prepared = match Self::prepare_media_object(&media_store, &object_input).await {
            Ok(prepared) => prepared,
            Err(error) => {
                record_upload_failure(&object_input, None, "repository.object_prepared");
                return Err(error);
            }
        };
        record_upload_stage("repository.object_prepared", &object_input, &prepared, 0);
        let prepared_derivatives =
            Self::prepare_upload_derivatives(&media_store, &object_input, &mut prepared).await?;
        let (asset_row, derivative_rows) = self
            .insert_pending_media_upload(&object_input, &prepared, &prepared_derivatives)
            .await?;

        let upload = PetMediaUploadResult {
            asset: asset_row.try_into()?,
            binding: None,
            derivatives: derivative_rows
                .into_iter()
                .map(TryInto::try_into)
                .collect::<PetResult<Vec<MediaDerivative>>>()?,
            components: Vec::new(),
        };
        record_upload_stage(
            "repository.committed",
            &object_input,
            &prepared,
            upload.derivatives.len(),
        );
        Ok(upload)
    }

    pub(super) async fn upload_pending_pet_live_photo_command(
        &self,
        input: PendingPetLivePhotoUploadInput,
    ) -> PetResult<PetMediaUploadResult> {
        let media_store = MediaObjectStore::from_env()
            .map_err(|error| PetError::Infrastructure(error.to_string()))?;
        let mut primary_input = MediaUploadObjectInput {
            owner_user_id: input.owner_user_id,
            pet_id: None,
            usage_kind: MediaUsageKind::PetBackgroundLivePhoto,
            file_name: &input.still_file_name,
            mime_type: &input.still_mime_type,
            content: &input.still_content,
            source_client: input.source_client.as_deref(),
        };
        let mut prepared = Self::prepare_media_object(&media_store, &primary_input).await?;
        let paired_video_component = Self::prepare_live_photo_component(
            &media_store,
            &prepared,
            MediaAssetComponentKind::PairedVideo,
            &input.paired_video_file_name,
            &input.paired_video_mime_type,
            &input.paired_video_content,
        )
        .await?;
        let still_component =
            Self::prepared_still_component_from_primary(&prepared, &input.still_mime_type);
        let components = vec![still_component, paired_video_component];
        let prepared_derivatives =
            Self::prepare_upload_derivatives(&media_store, &primary_input, &mut prepared).await?;
        primary_input.source_client = input.source_client.as_deref();

        let (asset_row, component_rows, derivative_rows) = self
            .insert_pending_live_photo_upload(
                &primary_input,
                &prepared,
                &components,
                &prepared_derivatives,
            )
            .await?;
        Ok(PetMediaUploadResult {
            asset: asset_row.try_into()?,
            binding: None,
            derivatives: derivative_rows
                .into_iter()
                .map(TryInto::try_into)
                .collect::<PetResult<Vec<MediaDerivative>>>()?,
            components: component_rows
                .into_iter()
                .map(TryInto::try_into)
                .collect::<PetResult<Vec<MediaAssetComponent>>>()?,
        })
    }

    async fn prepare_upload_derivatives(
        media_store: &MediaObjectStore,
        object_input: &MediaUploadObjectInput<'_>,
        prepared: &mut PreparedMediaObject,
    ) -> PetResult<Vec<PreparedMediaDerivative>> {
        let prepared_derivatives =
            match Self::prepare_media_derivatives(media_store, object_input, prepared).await {
                Ok(derivatives) => derivatives,
                Err(error) => {
                    record_upload_failure(
                        object_input,
                        Some(prepared.asset_id),
                        "repository.derivatives_prepared",
                    );
                    return Err(error);
                }
            };
        record_upload_stage(
            "repository.derivatives_prepared",
            object_input,
            prepared,
            prepared_derivatives.len(),
        );
        if let Err(error) =
            Self::apply_video_asset_dimensions(prepared, object_input, &prepared_derivatives)
        {
            record_upload_failure(
                object_input,
                Some(prepared.asset_id),
                "repository.dimensions_applied",
            );
            return Err(error);
        }
        record_upload_stage(
            "repository.dimensions_applied",
            object_input,
            prepared,
            prepared_derivatives.len(),
        );
        Ok(prepared_derivatives)
    }

    async fn insert_pending_media_upload(
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

    async fn insert_pending_live_photo_upload(
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

    pub(super) async fn bind_uploaded_pet_media_command(
        &self,
        input: BindUploadedPetMediaInput,
    ) -> PetResult<PetMediaUploadResult> {
        let mut transaction = match self.pool.begin().await.map_err(to_infrastructure_error) {
            Ok(transaction) => transaction,
            Err(error) => {
                record_binding_stage("repository.transaction_started", &input, None, 0, false);
                return Err(error);
            }
        };
        let (asset_row, binding_row, derivative_rows, component_rows) =
            Self::bind_uploaded_media_in_transaction(
                &mut transaction,
                input.pet_id,
                input.owner_user_id,
                input.asset_id,
            )
            .await
            .inspect_err(|_error| {
                record_binding_stage("repository.bound", &input, None, 0, false);
            })?;
        if let Err(error) = transaction.commit().await.map_err(to_infrastructure_error) {
            record_binding_stage("repository.committed", &input, None, 0, false);
            return Err(error);
        }

        let upload = PetMediaUploadResult {
            asset: asset_row.try_into()?,
            binding: Some(binding_row.try_into()?),
            derivatives: derivative_rows
                .into_iter()
                .map(TryInto::try_into)
                .collect::<PetResult<Vec<MediaDerivative>>>()?,
            components: component_rows
                .into_iter()
                .map(TryInto::try_into)
                .collect::<PetResult<Vec<MediaAssetComponent>>>()?,
        };
        record_binding_stage(
            "repository.committed",
            &input,
            Some(&upload.asset),
            upload.derivatives.len(),
            true,
        );
        Ok(upload)
    }

    pub(super) async fn bind_uploaded_media_in_transaction(
        transaction: &mut Transaction<'_, Postgres>,
        pet_id: Uuid,
        owner_user_id: Uuid,
        asset_id: Uuid,
    ) -> PetResult<(
        MediaAssetRow,
        MediaBindingRow,
        Vec<MediaDerivativeRow>,
        Vec<MediaAssetComponentRow>,
    )> {
        let current_asset =
            Self::select_owned_media_asset_for_binding(transaction, asset_id, owner_user_id)
                .await?;
        let usage_kind = current_asset.usage_kind;

        Self::queue_replaced_media(transaction, pet_id, usage_kind).await?;
        let asset_row = Self::mark_media_asset_bound(transaction, asset_id, pet_id).await?;
        let binding_row = Self::insert_media_binding_for_asset(
            transaction,
            asset_id,
            pet_id,
            owner_user_id,
            usage_kind,
        )
        .await?;
        Self::update_pet_media_reference_by_usage(
            transaction,
            pet_id,
            owner_user_id,
            asset_id,
            usage_kind,
        )
        .await?;
        Self::insert_bound_audit_event_for_asset(
            transaction,
            pet_id,
            owner_user_id,
            asset_id,
            usage_kind,
        )
        .await?;
        let derivative_rows = Self::select_media_derivatives(transaction, asset_id).await?;
        let component_rows = Self::select_media_asset_components(transaction, asset_id).await?;

        Ok((asset_row, binding_row, derivative_rows, component_rows))
    }

    /// apply_video_asset_dimensions 回填视频资产尺寸
    /// 核心职责：
    /// - 从视频封面帧派生元数据读取原始展示尺寸
    /// - 让视频资产响应与图片资产保持同一尺寸契约
    fn apply_video_asset_dimensions(
        media: &mut PreparedMediaObject,
        input: &MediaUploadObjectInput<'_>,
        derivatives: &[PreparedMediaDerivative],
    ) -> PetResult<()> {
        if input.usage_kind != MediaUsageKind::PetBackgroundVideo {
            return Ok(());
        }
        let Some(cover_frame) = derivatives
            .iter()
            .find(|derivative| derivative.derivative_kind == MediaDerivativeKind::VideoCoverFrame)
        else {
            return Ok(());
        };
        media.width = metadata_i32(&cover_frame.metadata, "width")?;
        media.height = metadata_i32(&cover_frame.metadata, "height")?;
        Ok(())
    }

    /// prepare_media_object 持久化媒体对象并生成元数据
    /// 核心职责：
    /// - 写入对象存储根目录
    /// - 生成资产和哈希字段
    async fn prepare_media_object(
        media_store: &MediaObjectStore,
        input: &MediaUploadObjectInput<'_>,
    ) -> PetResult<PreparedMediaObject> {
        let asset_id = Uuid::new_v4();
        let bucket = media_store.default_bucket().to_owned();
        let object_key = format!(
            "{}/{}/{}/{}",
            media_object_prefix(input),
            input.usage_kind.as_str().replace('.', "/"),
            asset_id,
            sanitized_file_name(input.file_name)
        );
        media_store
            .put(&bucket, &object_key, input.content)
            .await
            .map_err(|error| PetError::Infrastructure(error.to_string()))?;
        let sha256_hex = sha256_hex(input.content);
        let byte_size = i64::try_from(input.content.len())
            .map_err(|_| PetError::InvalidInput("媒体内容过大".to_owned()))?;
        let (width, height) = image_dimensions(input.content)?;

        Ok(PreparedMediaObject {
            asset_id,
            bucket,
            object_key,
            sha256_hex,
            byte_size,
            width,
            height,
        })
    }

    /// prepare_media_derivatives 生成媒体派生对象
    /// 核心职责：
    /// - 为可解码图片生成缩略图和主题色派生物
    /// - 将派生对象写入对象根并返回元数据
    async fn prepare_media_derivatives(
        media_store: &MediaObjectStore,
        input: &MediaUploadObjectInput<'_>,
        media: &PreparedMediaObject,
    ) -> PetResult<Vec<PreparedMediaDerivative>> {
        if input.usage_kind == MediaUsageKind::PetBackgroundVideo {
            return prepare_video_derivatives(media_store, input, media).await;
        }

        if !matches!(
            input.usage_kind,
            MediaUsageKind::PetAvatar
                | MediaUsageKind::PetBackgroundImage
                | MediaUsageKind::PetBackgroundLivePhoto
        ) {
            return Ok(Vec::new());
        }

        let Ok(image) = image::load_from_memory(input.content) else {
            return Ok(Vec::new());
        };

        let theme_color = average_theme_color(&image);
        let thumbnail = image.thumbnail(512, 512);
        let mut thumbnail_cursor = Cursor::new(Vec::new());
        thumbnail
            .write_to(&mut thumbnail_cursor, ImageFormat::Png)
            .map_err(|error| PetError::Infrastructure(error.to_string()))?;
        let thumbnail_content = thumbnail_cursor.into_inner();
        let theme_payload = serde_json::json!({ "theme_color_hex": theme_color }).to_string();

        Ok(vec![
            prepare_derivative_object(
                media_store,
                media,
                MediaDerivativeKind::Thumbnail,
                "thumbnail.png",
                "image/png",
                thumbnail_content,
                serde_json::json!({
                    "width": thumbnail.width(),
                    "height": thumbnail.height()
                }),
            )
            .await?,
            prepare_derivative_object(
                media_store,
                media,
                MediaDerivativeKind::ThemeColorFrame,
                "theme-color.json",
                "application/json",
                theme_payload.into_bytes(),
                serde_json::json!({ "theme_color_hex": theme_color }),
            )
            .await?,
        ])
    }

    /// queue_replaced_media 将旧媒体绑定加入清理队列
    /// 核心职责：
    /// - 标记当前用途下旧绑定为已替换
    /// - 为旧资产创建延迟清理任务
    async fn queue_replaced_media(
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

    /// insert_media_asset 写入媒体资产记录
    /// 核心职责：
    /// - 保存上传来源和对象存储位置
    /// - 返回数据库标准化后的资产行
    async fn insert_media_asset(
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
    async fn insert_media_derivatives(
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

    async fn insert_media_asset_components(
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

    async fn select_owned_media_asset_for_binding(
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

    async fn mark_media_asset_bound(
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

    async fn insert_media_binding_for_asset(
        transaction: &mut Transaction<'_, Postgres>,
        asset_id: Uuid,
        pet_id: Uuid,
        owner_user_id: Uuid,
        usage_kind: MediaUsageKind,
    ) -> PetResult<MediaBindingRow> {
        sqlx::query_as::<_, MediaBindingRow>(
            r#"
            INSERT INTO media_bindings (
                id,
                asset_id,
                pet_id,
                usage_kind,
                status,
                bound_by_user_id
            )
            VALUES ($1, $2, $3, $4, 'active', $5)
            RETURNING
                id,
                asset_id,
                pet_id,
                usage_kind,
                status,
                bound_by_user_id,
                bound_at,
                replaced_at,
                created_at
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(asset_id)
        .bind(pet_id)
        .bind(usage_kind.as_str())
        .bind(owner_user_id)
        .fetch_one(&mut **transaction)
        .await
        .map_err(to_infrastructure_error)
    }

    async fn update_pet_media_reference_by_usage(
        transaction: &mut Transaction<'_, Postgres>,
        pet_id: Uuid,
        owner_user_id: Uuid,
        asset_id: Uuid,
        usage_kind: MediaUsageKind,
    ) -> PetResult<()> {
        let (avatar_asset_id, background_asset_id, background_media_kind) = match usage_kind {
            MediaUsageKind::PetAvatar => (Some(asset_id), None, None),
            MediaUsageKind::PetBackgroundImage => (
                None,
                Some(asset_id),
                Some(PetBackgroundMediaKind::Image.as_str()),
            ),
            MediaUsageKind::PetBackgroundVideo => (
                None,
                Some(asset_id),
                Some(PetBackgroundMediaKind::Video.as_str()),
            ),
            MediaUsageKind::PetBackgroundLivePhoto => (
                None,
                Some(asset_id),
                Some(PetBackgroundMediaKind::LivePhoto.as_str()),
            ),
        };
        sqlx::query(
            r#"
            UPDATE pet_profiles
            SET
                avatar_asset_id = COALESCE($3, avatar_asset_id),
                background_asset_id = COALESCE($4, background_asset_id),
                background_media_kind = COALESCE($5, background_media_kind),
                updated_at = now()
            WHERE id = $1 AND owner_user_id = $2 AND deleted_at IS NULL
            "#,
        )
        .bind(pet_id)
        .bind(owner_user_id)
        .bind(avatar_asset_id)
        .bind(background_asset_id)
        .bind(background_media_kind)
        .execute(&mut **transaction)
        .await
        .map_err(to_infrastructure_error)?;

        Ok(())
    }

    async fn insert_bound_audit_event_for_asset(
        transaction: &mut Transaction<'_, Postgres>,
        pet_id: Uuid,
        owner_user_id: Uuid,
        asset_id: Uuid,
        usage_kind: MediaUsageKind,
    ) -> PetResult<()> {
        sqlx::query(
            r#"
            INSERT INTO media_audit_events (
                id,
                asset_id,
                pet_id,
                actor_user_id,
                event_kind,
                event_payload
            )
            VALUES ($1, $2, $3, $4, 'bound', $5)
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(asset_id)
        .bind(pet_id)
        .bind(owner_user_id)
        .bind(serde_json::json!({ "usage_kind": usage_kind.as_str() }))
        .execute(&mut **transaction)
        .await
        .map_err(to_infrastructure_error)?;

        Ok(())
    }

    async fn select_media_derivatives(
        transaction: &mut Transaction<'_, Postgres>,
        asset_id: Uuid,
    ) -> PetResult<Vec<MediaDerivativeRow>> {
        sqlx::query_as::<_, MediaDerivativeRow>(
            r#"
            SELECT
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
            FROM media_derivatives
            WHERE parent_asset_id = $1
            ORDER BY created_at ASC
            "#,
        )
        .bind(asset_id)
        .fetch_all(&mut **transaction)
        .await
        .map_err(to_infrastructure_error)
    }

    async fn select_media_asset_components(
        transaction: &mut Transaction<'_, Postgres>,
        asset_id: Uuid,
    ) -> PetResult<Vec<MediaAssetComponentRow>> {
        sqlx::query_as::<_, MediaAssetComponentRow>(
            r#"
            SELECT
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
            FROM media_asset_components
            WHERE asset_id = $1
            ORDER BY created_at ASC
            "#,
        )
        .bind(asset_id)
        .fetch_all(&mut **transaction)
        .await
        .map_err(to_infrastructure_error)
    }

    fn prepared_still_component_from_primary(
        prepared: &PreparedMediaObject,
        mime_type: &str,
    ) -> PreparedMediaComponent {
        PreparedMediaComponent {
            id: Uuid::new_v4(),
            component_kind: MediaAssetComponentKind::Still,
            bucket: prepared.bucket.clone(),
            object_key: prepared.object_key.clone(),
            mime_type: mime_type.to_owned(),
            byte_size: prepared.byte_size,
            sha256_hex: prepared.sha256_hex.clone(),
            width: prepared.width,
            height: prepared.height,
            duration_ms: None,
        }
    }

    async fn prepare_live_photo_component(
        media_store: &MediaObjectStore,
        media: &PreparedMediaObject,
        component_kind: MediaAssetComponentKind,
        file_name: &str,
        mime_type: &str,
        content: &[u8],
    ) -> PetResult<PreparedMediaComponent> {
        let id = Uuid::new_v4();
        let object_prefix = media
            .object_key
            .rsplit_once('/')
            .map_or(media.object_key.as_str(), |(prefix, _)| prefix);
        let object_key = format!(
            "{}/live_photo/{}/{}",
            object_prefix,
            component_kind.as_str(),
            sanitized_file_name(file_name)
        );
        media_store
            .put(&media.bucket, &object_key, content)
            .await
            .map_err(|error| PetError::Infrastructure(error.to_string()))?;
        let byte_size = i64::try_from(content.len())
            .map_err(|_| PetError::InvalidInput("Live Photo 组件内容过大".to_owned()))?;
        let (width, height) = image_dimensions(content)?;
        Ok(PreparedMediaComponent {
            id,
            component_kind,
            bucket: media.bucket.clone(),
            object_key,
            mime_type: mime_type.to_owned(),
            byte_size,
            sha256_hex: sha256_hex(content),
            width,
            height,
            duration_ms: None,
        })
    }
}

/// media_object_prefix 生成媒体对象根路径
/// 核心职责：
/// - 已绑定上传进入宠物目录
/// - 建档前上传进入用户 pending 目录
fn media_object_prefix(input: &MediaUploadObjectInput<'_>) -> String {
    input.pet_id.map_or_else(
        || format!("pet-media/pending/{}", input.owner_user_id),
        |pet_id| format!("pets/{pet_id}"),
    )
}

/// image_dimensions 读取原始图片尺寸
/// 核心职责：
/// - 为可解码图片资产提供原始宽高
/// - 对非图片媒体保持空尺寸由其他派生链路补齐
fn image_dimensions(content: &[u8]) -> PetResult<(Option<i32>, Option<i32>)> {
    let Ok(image) = image::load_from_memory(content) else {
        return Ok((None, None));
    };
    Ok((
        Some(to_i32_dimension(image.width())?),
        Some(to_i32_dimension(image.height())?),
    ))
}

/// metadata_i32 读取派生元数据尺寸
/// 核心职责：
/// - 从 JSON metadata 中提取可写入资产表的整数尺寸
/// - 对缺失字段保持空值兼容
fn metadata_i32(metadata: &Value, key: &str) -> PetResult<Option<i32>> {
    let Some(value) = metadata.get(key).and_then(serde_json::Value::as_u64) else {
        return Ok(None);
    };
    i32::try_from(value)
        .map(Some)
        .map_err(|_| PetError::InvalidInput("媒体尺寸过大".to_owned()))
}

/// to_i32_dimension 转换媒体尺寸
/// 核心职责：
/// - 保护数据库 integer 字段边界
/// - 统一尺寸溢出的错误语义
pub(super) fn to_i32_dimension(value: u32) -> PetResult<i32> {
    i32::try_from(value).map_err(|_| PetError::InvalidInput("媒体尺寸过大".to_owned()))
}
