use maohuoban_pet_domain::pet::HomeGalleryAlbumSummary;
use sqlx::FromRow;
use uuid::Uuid;

#[derive(Debug, FromRow)]
pub(crate) struct HomeGalleryAlbumSummaryRow {
    id: Uuid,
    pet_id: Uuid,
    title: String,
    cover_asset_id: Option<Uuid>,
    photo_count: i32,
}

impl From<HomeGalleryAlbumSummaryRow> for HomeGalleryAlbumSummary {
    fn from(row: HomeGalleryAlbumSummaryRow) -> Self {
        Self {
            id: row.id,
            pet_id: row.pet_id,
            title: row.title,
            cover_asset_id: row.cover_asset_id,
            cover_url: row
                .cover_asset_id
                .map(|asset_id| format!("/api/v1/media/assets/{asset_id}/content")),
            photo_count: row.photo_count,
        }
    }
}
