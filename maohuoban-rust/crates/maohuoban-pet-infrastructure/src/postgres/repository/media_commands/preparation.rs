use std::io::Cursor;

use chrono::Utc;
use image::ImageFormat;
use maohuoban_media_storage::{MediaObjectKind, MediaObjectStore, traceable_media_object_key};
use maohuoban_pet_domain::pet::{MediaDerivativeKind, MediaUsageKind, PetError, PetResult};
use uuid::Uuid;

use super::derivatives::{
    average_theme_color, extract_first_video_frame, prepare_derivative_object,
    prepare_video_derivatives,
};
use super::diagnostics::{record_upload_failure, record_upload_stage};
use super::image_metadata::{
    crop_display_image, crop_metadata_json, image_dimensions, media_derivative_metadata,
    metadata_i32, to_i32_dimension,
};
use super::{MediaUploadObjectInput, PreparedMediaDerivative, PreparedMediaObject};
use crate::postgres::repository::PostgresPetRepository;
use crate::postgres::repository::storage::sha256_hex;

impl PostgresPetRepository {
    pub(super) async fn prepare_upload_derivatives(
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

    pub(super) async fn prepare_live_photo_upload_derivatives(
        media_store: &MediaObjectStore,
        object_input: &MediaUploadObjectInput<'_>,
        paired_video_file_name: &str,
        paired_video_content: &[u8],
        prepared: &mut PreparedMediaObject,
    ) -> PetResult<Vec<PreparedMediaDerivative>> {
        let mut prepared_derivatives =
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

        if prepared_derivatives.is_empty()
            && let Some(frame_content) =
                extract_first_video_frame(paired_video_content, paired_video_file_name)
            && let Ok(frame) = image::load_from_memory(&frame_content)
        {
            prepared.width = Some(to_i32_dimension(frame.width())?);
            prepared.height = Some(to_i32_dimension(frame.height())?);
            prepared_derivatives =
                Self::prepare_image_derivatives(media_store, object_input, prepared, &frame)
                    .await?;
        }

        record_upload_stage(
            "repository.derivatives_prepared",
            object_input,
            prepared,
            prepared_derivatives.len(),
        );
        record_upload_stage(
            "repository.dimensions_applied",
            object_input,
            prepared,
            prepared_derivatives.len(),
        );
        Ok(prepared_derivatives)
    }

    /// apply_video_asset_dimensions 回填视频资产尺寸
    /// 核心职责：
    /// - 从视频封面帧派生元数据读取原始展示尺寸
    /// - 让视频资产响应与图片资产保持同一尺寸契约
    pub(super) fn apply_video_asset_dimensions(
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
    pub(super) async fn prepare_media_object(
        media_store: &MediaObjectStore,
        input: &MediaUploadObjectInput<'_>,
    ) -> PetResult<PreparedMediaObject> {
        let asset_id = Uuid::new_v4();
        let created_at = Utc::now();
        let bucket = media_store.default_bucket().to_owned();
        let object_key = traceable_media_object_key(
            input.owner_user_id,
            asset_id,
            created_at,
            MediaObjectKind::Original {
                file_name: input.file_name,
            },
        );
        media_store
            .put(&bucket, &object_key, input.content)
            .await
            .map_err(|error| PetError::Infrastructure(error.to_string()))?;
        let sha256_hex = sha256_hex(input.content);
        let byte_size = i64::try_from(input.content.len())
            .map_err(|_| PetError::InvalidInput("媒体内容过大".to_owned()))?;
        let (width, height) = image_dimensions(input.content)?;
        validate_required_image_dimensions(input, width, height)?;

        Ok(PreparedMediaObject {
            asset_id,
            owner_user_id: input.owner_user_id,
            bucket,
            object_key,
            sha256_hex,
            byte_size,
            width,
            height,
            created_at,
        })
    }

    /// prepare_media_derivatives 生成媒体派生对象
    /// 核心职责：
    /// - 为可解码图片生成缩略图和主题色派生物
    /// - 将派生对象写入对象根并返回元数据
    pub(super) async fn prepare_media_derivatives(
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
                | MediaUsageKind::PetAlbumPhoto
        ) {
            return Ok(Vec::new());
        }

        let Ok(image) = image::load_from_memory(input.content) else {
            return Ok(Vec::new());
        };

        Self::prepare_image_derivatives(media_store, input, media, &image).await
    }

    pub(super) async fn prepare_image_derivatives(
        media_store: &MediaObjectStore,
        input: &MediaUploadObjectInput<'_>,
        media: &PreparedMediaObject,
        image: &image::DynamicImage,
    ) -> PetResult<Vec<PreparedMediaDerivative>> {
        let display_image = crop_display_image(image, input.crop_metadata);
        let crop_metadata = input.crop_metadata.map(crop_metadata_json);
        let theme_color = average_theme_color(&display_image);
        let thumbnail = display_image.thumbnail(512, 512);
        let mut thumbnail_cursor = Cursor::new(Vec::new());
        thumbnail
            .write_to(&mut thumbnail_cursor, ImageFormat::Png)
            .map_err(|error| PetError::Infrastructure(error.to_string()))?;
        let thumbnail_content = thumbnail_cursor.into_inner();
        let theme_metadata = media_derivative_metadata(
            serde_json::json!({ "theme_color_hex": theme_color }),
            crop_metadata.clone(),
        );
        let theme_payload = theme_metadata.to_string();

        Ok(vec![
            prepare_derivative_object(
                media_store,
                media,
                MediaDerivativeKind::Thumbnail,
                "thumbnail.png",
                "image/png",
                thumbnail_content,
                media_derivative_metadata(
                    serde_json::json!({
                        "width": thumbnail.width(),
                        "height": thumbnail.height()
                    }),
                    crop_metadata.clone(),
                ),
            )
            .await?,
            prepare_derivative_object(
                media_store,
                media,
                MediaDerivativeKind::ThemeColorFrame,
                "theme-color.json",
                "application/json",
                theme_payload.into_bytes(),
                theme_metadata,
            )
            .await?,
        ])
    }
}

/// validate_required_image_dimensions 校验图片媒资尺寸
/// 核心职责：
/// - 固定图片类业务用途必须保留宽高元数据
/// - 阻止不可解析内容进入相册、头像和图片背景资产表
fn validate_required_image_dimensions(
    input: &MediaUploadObjectInput<'_>,
    width: Option<i32>,
    height: Option<i32>,
) -> PetResult<()> {
    if width.is_some() && height.is_some() {
        return Ok(());
    }

    match input.usage_kind {
        MediaUsageKind::PetAlbumPhoto => Err(PetError::InvalidInput(
            "相册照片必须是可解析图片".to_owned(),
        )),
        MediaUsageKind::PetAvatar => Err(PetError::InvalidInput(
            "宠物头像必须是可解析图片".to_owned(),
        )),
        MediaUsageKind::PetBackgroundImage => Err(PetError::InvalidInput(
            "宠物背景图必须是可解析图片".to_owned(),
        )),
        MediaUsageKind::PetBackgroundLivePhoto | MediaUsageKind::PetBackgroundVideo => Ok(()),
    }
}
