use sqlx::{FromRow, PgPool};
use uuid::Uuid;

pub(super) async fn load_media_asset(
    pool: &PgPool,
    asset_id: Uuid,
) -> Result<Option<MediaContentAssetRow>, sqlx::Error> {
    sqlx::query_as::<_, MediaContentAssetRow>(
        r"
        SELECT bucket, object_key, mime_type
        FROM media_assets
        WHERE id = $1
          AND deleted_at IS NULL
          AND status IN ('uploaded', 'bound')
        ",
    )
    .bind(asset_id)
    .fetch_optional(pool)
    .await
}

pub(super) async fn load_media_asset_component(
    pool: &PgPool,
    asset_id: Uuid,
    component_id: Uuid,
) -> Result<Option<MediaContentAssetRow>, sqlx::Error> {
    sqlx::query_as::<_, MediaContentAssetRow>(
        r"
        SELECT component.bucket, component.object_key, component.mime_type
        FROM media_asset_components component
        INNER JOIN media_assets asset ON asset.id = component.asset_id
        WHERE component.asset_id = $1
          AND component.id = $2
          AND asset.deleted_at IS NULL
          AND asset.status IN ('uploaded', 'bound')
        ",
    )
    .bind(asset_id)
    .bind(component_id)
    .fetch_optional(pool)
    .await
}

#[derive(Debug, FromRow)]
pub(super) struct MediaContentAssetRow {
    pub(super) bucket: String,
    pub(super) object_key: String,
    pub(super) mime_type: String,
}
