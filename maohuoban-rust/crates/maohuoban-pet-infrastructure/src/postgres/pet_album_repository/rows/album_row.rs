use chrono::{DateTime, Utc};
use maohuoban_pet_domain::pet::{PetAlbum, PetError};
use sqlx::FromRow;
use uuid::Uuid;

#[derive(Debug, FromRow)]
pub(crate) struct PetAlbumRow {
    pub(crate) id: Uuid,
    pub(crate) pet_id: Option<Uuid>,
    pub(crate) owner_user_id: Uuid,
    pub(crate) title: String,
    pub(crate) description: Option<String>,
    pub(crate) is_private: bool,
    pub(crate) is_pinned: bool,
    pub(crate) cover_asset_id: Option<Uuid>,
    pub(crate) photo_count: i32,
    pub(crate) archived_at: Option<DateTime<Utc>>,
    pub(crate) created_at: DateTime<Utc>,
    pub(crate) updated_at: DateTime<Utc>,
}

impl TryFrom<PetAlbumRow> for PetAlbum {
    type Error = PetError;

    fn try_from(row: PetAlbumRow) -> Result<Self, Self::Error> {
        Ok(Self {
            id: row.id,
            pet_id: row.pet_id,
            owner_user_id: row.owner_user_id,
            title: row.title,
            description: row.description,
            is_private: row.is_private,
            is_pinned: row.is_pinned,
            cover_asset_id: row.cover_asset_id,
            cover_url: row
                .cover_asset_id
                .map(|asset_id| format!("/api/v1/media/assets/{asset_id}/content")),
            photo_count: row.photo_count,
            archived_at: row.archived_at,
            created_at: row.created_at,
            updated_at: row.updated_at,
        })
    }
}
