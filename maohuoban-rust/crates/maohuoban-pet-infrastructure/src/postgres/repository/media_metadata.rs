use maohuoban_pet_application::pet::{MediaAssetDisplayMetadata, MediaCropMetadata};
use maohuoban_pet_domain::pet::PetResult;
use serde_json::Value;
use sqlx::FromRow;
use uuid::Uuid;

use super::PostgresPetRepository;
use super::storage::to_infrastructure_error;

/// MediaAssetDisplayMetadataRow 媒体展示元数据行
/// 核心职责：
/// - 聚合媒体资产尺寸字段
/// - 读取主题色派生物元数据
#[derive(Debug, FromRow)]
struct MediaAssetDisplayMetadataRow {
    asset_id: Uuid,
    width: Option<i32>,
    height: Option<i32>,
    theme_color_hex: Option<String>,
    crop_metadata: Option<Value>,
    live_photo_still_component_id: Option<Uuid>,
    live_photo_still_width: Option<i32>,
    live_photo_still_height: Option<i32>,
    live_photo_paired_video_component_id: Option<Uuid>,
    live_photo_paired_video_width: Option<i32>,
    live_photo_paired_video_height: Option<i32>,
    live_photo_paired_video_duration_ms: Option<i32>,
}

impl PostgresPetRepository {
    pub(super) async fn list_media_display_metadata_query(
        &self,
        asset_ids: &[Uuid],
    ) -> PetResult<Vec<MediaAssetDisplayMetadata>> {
        if asset_ids.is_empty() {
            return Ok(Vec::new());
        }

        let rows = sqlx::query_as::<_, MediaAssetDisplayMetadataRow>(
            r#"
            SELECT
                asset.id AS asset_id,
                asset.width,
                asset.height,
                derivative.metadata ->> 'theme_color_hex' AS theme_color_hex,
                derivative.metadata -> 'crop' AS crop_metadata,
                still_component.id AS live_photo_still_component_id,
                COALESCE(still_component.width, asset.width) AS live_photo_still_width,
                COALESCE(still_component.height, asset.height) AS live_photo_still_height,
                paired_video_component.id AS live_photo_paired_video_component_id,
                COALESCE(paired_video_component.width, asset.width) AS live_photo_paired_video_width,
                COALESCE(paired_video_component.height, asset.height) AS live_photo_paired_video_height,
                paired_video_component.duration_ms AS live_photo_paired_video_duration_ms
            FROM media_assets asset
            LEFT JOIN media_derivatives derivative
                ON derivative.parent_asset_id = asset.id
                AND derivative.derivative_kind = 'theme_color_frame'
            LEFT JOIN media_asset_components still_component
                ON still_component.asset_id = asset.id
                AND still_component.component_kind = 'still'
            LEFT JOIN media_asset_components paired_video_component
                ON paired_video_component.asset_id = asset.id
                AND paired_video_component.component_kind = 'paired_video'
            WHERE asset.id = ANY($1)
              AND asset.deleted_at IS NULL
              AND asset.status IN ('uploaded', 'bound')
            "#,
        )
        .bind(asset_ids)
        .fetch_all(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        Ok(rows
            .into_iter()
            .map(|row| MediaAssetDisplayMetadata {
                asset_id: row.asset_id,
                width: row.width,
                height: row.height,
                theme_color_hex: row.theme_color_hex,
                crop_metadata: media_crop_metadata(row.crop_metadata.as_ref()),
                live_photo_still_url: row
                    .live_photo_still_component_id
                    .map(|component_id| media_asset_component_url(row.asset_id, component_id)),
                live_photo_still_width: row.live_photo_still_width,
                live_photo_still_height: row.live_photo_still_height,
                live_photo_paired_video_url: row
                    .live_photo_paired_video_component_id
                    .map(|component_id| media_asset_component_url(row.asset_id, component_id)),
                live_photo_paired_video_width: row.live_photo_paired_video_width,
                live_photo_paired_video_height: row.live_photo_paired_video_height,
                live_photo_paired_video_duration_ms: row.live_photo_paired_video_duration_ms,
            })
            .collect())
    }
}

fn media_asset_component_url(asset_id: Uuid, component_id: Uuid) -> String {
    format!("/api/v1/media/assets/{asset_id}/components/{component_id}/content")
}

/// media_crop_metadata 读取媒体展示裁剪元数据
/// 核心职责：
/// - 从派生 metadata JSON 中恢复归一化裁剪区域
/// - 让首页 DTO 使用后端持久化的展示契约
fn media_crop_metadata(value: Option<&Value>) -> Option<MediaCropMetadata> {
    let value = value?;
    Some(MediaCropMetadata {
        x: value.get("x")?.as_f64()?,
        y: value.get("y")?.as_f64()?,
        width: value.get("width")?.as_f64()?,
        height: value.get("height")?.as_f64()?,
    })
}
