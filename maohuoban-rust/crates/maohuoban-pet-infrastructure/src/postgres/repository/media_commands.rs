mod derivatives;

use std::io::Cursor;

use chrono::{Duration, Utc};
use image::ImageFormat;
use maohuoban_media_storage::MediaObjectStore;
use maohuoban_pet_application::pet::PetMediaUploadInput;
use maohuoban_pet_domain::pet::{
    MediaDerivative, MediaDerivativeKind, MediaUsageKind, PetBackgroundMediaKind, PetError,
    PetMediaUploadResult, PetResult,
};
use serde_json::Value;
use sqlx::{Postgres, Transaction};
use uuid::Uuid;

use super::PostgresPetRepository;
use super::rows::{MediaAssetRow, MediaBindingRow, MediaDerivativeRow};
use super::storage::{sanitized_file_name, sha256_hex, to_infrastructure_error};
use derivatives::{average_theme_color, prepare_derivative_object, prepare_video_derivatives};

/// PreparedMediaObject 已持久化媒体对象
/// 核心职责：
/// - 保存数据库写入前生成的对象存储字段
/// - 避免上传命令在事务内重复计算对象元数据
pub(super) struct PreparedMediaObject {
    pub(super) asset_id: Uuid,
    pub(super) binding_id: Uuid,
    pub(super) bucket: String,
    pub(super) object_key: String,
    pub(super) sha256_hex: String,
    pub(super) byte_size: i64,
    pub(super) width: Option<i32>,
    pub(super) height: Option<i32>,
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

impl PostgresPetRepository {
    pub(super) async fn upload_pet_media_command(
        &self,
        input: PetMediaUploadInput,
    ) -> PetResult<PetMediaUploadResult> {
        let media_store = MediaObjectStore::from_env()
            .map_err(|error| PetError::Infrastructure(error.to_string()))?;
        let mut prepared = Self::prepare_media_object(&media_store, &input).await?;
        let prepared_derivatives =
            Self::prepare_media_derivatives(&media_store, &input, &prepared).await?;
        Self::apply_video_asset_dimensions(&mut prepared, &input, &prepared_derivatives)?;
        let mut transaction = self.pool.begin().await.map_err(to_infrastructure_error)?;

        Self::queue_replaced_media(&mut transaction, input.pet_id, input.usage_kind).await?;
        let asset_row = Self::insert_media_asset(&mut transaction, &input, &prepared).await?;
        let derivative_rows = Self::insert_media_derivatives(
            &mut transaction,
            prepared.asset_id,
            &prepared_derivatives,
        )
        .await?;
        let binding_row = Self::insert_media_binding(&mut transaction, &input, &prepared).await?;
        Self::update_pet_media_reference(&mut transaction, &input, prepared.asset_id).await?;
        Self::insert_bound_audit_event(&mut transaction, &input, prepared.asset_id).await?;

        transaction
            .commit()
            .await
            .map_err(to_infrastructure_error)?;

        Ok(PetMediaUploadResult {
            asset: asset_row.try_into()?,
            binding: binding_row.try_into()?,
            derivatives: derivative_rows
                .into_iter()
                .map(TryInto::try_into)
                .collect::<PetResult<Vec<MediaDerivative>>>()?,
        })
    }

    /// apply_video_asset_dimensions 回填视频资产尺寸
    /// 核心职责：
    /// - 从视频封面帧派生元数据读取原始展示尺寸
    /// - 让视频资产响应与图片资产保持同一尺寸契约
    fn apply_video_asset_dimensions(
        media: &mut PreparedMediaObject,
        input: &PetMediaUploadInput,
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
    /// - 生成资产、绑定和哈希字段
    async fn prepare_media_object(
        media_store: &MediaObjectStore,
        input: &PetMediaUploadInput,
    ) -> PetResult<PreparedMediaObject> {
        let asset_id = Uuid::new_v4();
        let binding_id = Uuid::new_v4();
        let bucket = media_store.default_bucket().to_owned();
        let object_key = format!(
            "pets/{}/{}/{}/{}",
            input.pet_id,
            input.usage_kind.as_str().replace('.', "/"),
            asset_id,
            sanitized_file_name(&input.file_name)
        );
        media_store
            .put(&bucket, &object_key, &input.content)
            .await
            .map_err(|error| PetError::Infrastructure(error.to_string()))?;
        let sha256_hex = sha256_hex(&input.content);
        let byte_size = i64::try_from(input.content.len())
            .map_err(|_| PetError::InvalidInput("媒体内容过大".to_owned()))?;
        let (width, height) = image_dimensions(&input.content)?;

        Ok(PreparedMediaObject {
            asset_id,
            binding_id,
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
        input: &PetMediaUploadInput,
        media: &PreparedMediaObject,
    ) -> PetResult<Vec<PreparedMediaDerivative>> {
        if input.usage_kind == MediaUsageKind::PetBackgroundVideo {
            return prepare_video_derivatives(media_store, input, media).await;
        }

        if !matches!(
            input.usage_kind,
            MediaUsageKind::PetAvatar | MediaUsageKind::PetBackgroundImage
        ) {
            return Ok(Vec::new());
        }

        let Ok(image) = image::load_from_memory(&input.content) else {
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
        input: &PetMediaUploadInput,
        prepared: &PreparedMediaObject,
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
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, 'bound', $12, $13)
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
        .bind(&input.source_client)
        .bind(&input.file_name)
        .bind(&input.mime_type)
        .bind(prepared.byte_size)
        .bind(&prepared.sha256_hex)
        .bind(&prepared.bucket)
        .bind(&prepared.object_key)
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

    /// insert_media_binding 写入当前有效媒体绑定
    /// 核心职责：
    /// - 建立媒体资产与宠物业务用途的 active 关系
    /// - 返回数据库标准化后的绑定行
    async fn insert_media_binding(
        transaction: &mut Transaction<'_, Postgres>,
        input: &PetMediaUploadInput,
        prepared: &PreparedMediaObject,
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
        .bind(prepared.binding_id)
        .bind(prepared.asset_id)
        .bind(input.pet_id)
        .bind(input.usage_kind.as_str())
        .bind(input.owner_user_id)
        .fetch_one(&mut **transaction)
        .await
        .map_err(to_infrastructure_error)
    }

    /// update_pet_media_reference 更新宠物档案当前媒体引用
    /// 核心职责：
    /// - 根据媒体用途写入头像或背景资产 ID
    /// - 同步背景媒体类型以供前端渲染
    async fn update_pet_media_reference(
        transaction: &mut Transaction<'_, Postgres>,
        input: &PetMediaUploadInput,
        asset_id: Uuid,
    ) -> PetResult<()> {
        let (avatar_asset_id, background_asset_id, background_media_kind) = match input.usage_kind {
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
        .bind(input.pet_id)
        .bind(input.owner_user_id)
        .bind(avatar_asset_id)
        .bind(background_asset_id)
        .bind(background_media_kind)
        .execute(&mut **transaction)
        .await
        .map_err(to_infrastructure_error)?;

        Ok(())
    }

    /// insert_bound_audit_event 记录媒体绑定审计事件
    /// 核心职责：
    /// - 追踪媒体资产绑定动作
    /// - 保存业务用途用于后续审计查询
    async fn insert_bound_audit_event(
        transaction: &mut Transaction<'_, Postgres>,
        input: &PetMediaUploadInput,
        asset_id: Uuid,
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
        .bind(input.pet_id)
        .bind(input.owner_user_id)
        .bind(serde_json::json!({ "usage_kind": input.usage_kind.as_str() }))
        .execute(&mut **transaction)
        .await
        .map_err(to_infrastructure_error)?;

        Ok(())
    }
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
