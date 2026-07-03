use chrono::{DateTime, Utc};
use maohuoban_pet_domain::pet::{PetAlbumAsset, PetError};
use sqlx::FromRow;
use uuid::Uuid;

#[derive(Debug, FromRow)]
pub(crate) struct PetAlbumAssetRow {
    pub(crate) id: Uuid,
    pub(crate) album_id: Uuid,
    pub(crate) pet_id: Uuid,
    pub(crate) asset_id: Uuid,
    pub(crate) added_by_user_id: Uuid,
    pub(crate) caption: Option<String>,
    pub(crate) sort_taken_at: DateTime<Utc>,
    pub(crate) removed_at: Option<DateTime<Utc>>,
    pub(crate) created_at: DateTime<Utc>,
    pub(crate) updated_at: DateTime<Utc>,
}

impl TryFrom<PetAlbumAssetRow> for PetAlbumAsset {
    type Error = PetError;

    fn try_from(row: PetAlbumAssetRow) -> Result<Self, Self::Error> {
        Ok(Self {
            id: row.id,
            album_id: row.album_id,
            pet_id: row.pet_id,
            asset_id: row.asset_id,
            asset_url: format!("/api/v1/media/assets/{}/content", row.asset_id),
            added_by_user_id: row.added_by_user_id,
            caption: row.caption,
            sort_taken_at: row.sort_taken_at,
            removed_at: row.removed_at,
            created_at: row.created_at,
            updated_at: row.updated_at,
        })
    }
}
