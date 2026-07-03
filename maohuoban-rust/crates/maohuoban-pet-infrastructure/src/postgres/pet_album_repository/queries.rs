use maohuoban_pet_application::pet::{PetAlbumAssetPage, PetAlbumListPage};
use maohuoban_pet_domain::pet::{HomeGalleryAlbumSummary, PetAlbum, PetResult};
use uuid::Uuid;

use super::PostgresPetAlbumRepository;
use super::cursor::{
    decode_album_asset_cursor, decode_album_cursor, encode_album_asset_cursor, encode_album_cursor,
};
use super::errors::to_infrastructure_error;
use super::rows::{HomeGalleryAlbumSummaryRow, PetAlbumAssetRow, PetAlbumRow};

impl PostgresPetAlbumRepository {
    pub(super) async fn list_user_pet_albums_query(
        &self,
        owner_user_id: Uuid,
        limit: i64,
        cursor: Option<String>,
    ) -> PetResult<PetAlbumListPage> {
        let (cursor_pinned, cursor_updated_at, cursor_id) = decode_album_cursor(cursor)?;
        let rows = sqlx::query_as::<_, PetAlbumRow>(ALBUM_SELECT_SQL)
            .bind(owner_user_id)
            .bind(limit + 1)
            .bind(cursor_pinned)
            .bind(cursor_updated_at)
            .bind(cursor_id)
            .fetch_all(&self.pool)
            .await
            .map_err(to_infrastructure_error)?;

        let (items, next_cursor) = album_page(rows, limit)?;
        Ok(PetAlbumListPage { items, next_cursor })
    }

    pub(super) async fn load_pet_album_query(
        &self,
        album_id: Uuid,
        owner_user_id: Uuid,
    ) -> PetResult<Option<PetAlbum>> {
        let row = sqlx::query_as::<_, PetAlbumRow>(ALBUM_DETAIL_SQL)
            .bind(album_id)
            .bind(owner_user_id)
            .fetch_optional(&self.pool)
            .await
            .map_err(to_infrastructure_error)?;
        row.map(TryInto::try_into).transpose()
    }

    pub(super) async fn list_pet_album_assets_query(
        &self,
        album_id: Uuid,
        owner_user_id: Uuid,
        limit: i64,
        cursor: Option<String>,
    ) -> PetResult<PetAlbumAssetPage> {
        let (cursor_sort_taken_at, cursor_created_at, cursor_id) =
            decode_album_asset_cursor(cursor)?;
        let rows = sqlx::query_as::<_, PetAlbumAssetRow>(ALBUM_ASSET_SELECT_SQL)
            .bind(album_id)
            .bind(owner_user_id)
            .bind(limit + 1)
            .bind(cursor_sort_taken_at)
            .bind(cursor_created_at)
            .bind(cursor_id)
            .fetch_all(&self.pool)
            .await
            .map_err(to_infrastructure_error)?;

        let (items, next_cursor) = album_asset_page(rows, limit)?;
        Ok(PetAlbumAssetPage { items, next_cursor })
    }

    pub(super) async fn list_home_gallery_album_summaries_query(
        &self,
        _pet_id: Uuid,
        owner_user_id: Uuid,
        limit: i64,
    ) -> PetResult<Vec<HomeGalleryAlbumSummary>> {
        let rows = sqlx::query_as::<_, HomeGalleryAlbumSummaryRow>(
            r#"
            SELECT
                album.id,
                album.pet_id,
                album.title,
                album.cover_asset_id,
                album.photo_count
            FROM pet_albums album
            WHERE album.owner_user_id = $1
              AND album.archived_at IS NULL
            ORDER BY album.is_pinned DESC, album.updated_at DESC, album.id DESC
            LIMIT $2
            "#,
        )
        .bind(owner_user_id)
        .bind(limit)
        .fetch_all(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        Ok(rows.into_iter().map(Into::into).collect())
    }
}

fn album_page(rows: Vec<PetAlbumRow>, limit: i64) -> PetResult<(Vec<PetAlbum>, Option<String>)> {
    let mut rows = rows;
    let has_next = rows.len() > usize::try_from(limit).unwrap_or(usize::MAX);
    if has_next {
        rows.truncate(usize::try_from(limit).unwrap_or(usize::MAX));
    }
    let next_cursor = if has_next {
        rows.last().map(encode_album_cursor)
    } else {
        None
    };
    let items = rows
        .into_iter()
        .map(TryInto::try_into)
        .collect::<PetResult<Vec<_>>>()?;
    Ok((items, next_cursor))
}

fn album_asset_page(
    rows: Vec<PetAlbumAssetRow>,
    limit: i64,
) -> PetResult<(
    Vec<maohuoban_pet_domain::pet::PetAlbumAsset>,
    Option<String>,
)> {
    let mut rows = rows;
    let has_next = rows.len() > usize::try_from(limit).unwrap_or(usize::MAX);
    if has_next {
        rows.truncate(usize::try_from(limit).unwrap_or(usize::MAX));
    }
    let next_cursor = if has_next {
        rows.last().map(encode_album_asset_cursor)
    } else {
        None
    };
    let items = rows
        .into_iter()
        .map(TryInto::try_into)
        .collect::<PetResult<Vec<_>>>()?;
    Ok((items, next_cursor))
}

const ALBUM_SELECT_SQL: &str = r#"
    SELECT
        album.id,
        album.pet_id,
        album.owner_user_id,
        album.title,
        album.description,
        album.is_private,
        album.is_pinned,
        album.cover_asset_id,
        album.photo_count,
        album.archived_at,
        album.created_at,
        album.updated_at
    FROM pet_albums album
    WHERE album.owner_user_id = $1
      AND album.archived_at IS NULL
      AND (
          $3::boolean IS NULL
          OR album.is_pinned < $3
          OR (
              album.is_pinned = $3
              AND (album.updated_at, album.id) < ($4::timestamptz, $5::uuid)
          )
      )
    ORDER BY album.is_pinned DESC, album.updated_at DESC, album.id DESC
    LIMIT $2
    "#;

const ALBUM_DETAIL_SQL: &str = r#"
    SELECT
        album.id,
        album.pet_id,
        album.owner_user_id,
        album.title,
        album.description,
        album.is_private,
        album.is_pinned,
        album.cover_asset_id,
        album.photo_count,
        album.archived_at,
        album.created_at,
        album.updated_at
    FROM pet_albums album
    WHERE album.id = $1
      AND album.archived_at IS NULL
      AND album.owner_user_id = $2
    "#;

const ALBUM_ASSET_SELECT_SQL: &str = r#"
    SELECT
        album_asset.id,
        album_asset.album_id,
        album_asset.pet_id,
        album_asset.asset_id,
        media.width,
        media.height,
        album_asset.added_by_user_id,
        album_asset.caption,
        album_asset.sort_taken_at,
        album_asset.removed_at,
        album_asset.created_at,
        album_asset.updated_at
    FROM pet_album_assets album_asset
    INNER JOIN pet_albums album ON album.id = album_asset.album_id
    INNER JOIN media_assets media ON media.id = album_asset.asset_id
    WHERE album_asset.album_id = $1
      AND album_asset.removed_at IS NULL
      AND album.archived_at IS NULL
      AND album.owner_user_id = $2
      AND (
          $4::timestamptz IS NULL
          OR album_asset.sort_taken_at < $4
          OR (
              album_asset.sort_taken_at = $4
              AND (album_asset.created_at, album_asset.id) < ($5::timestamptz, $6::uuid)
          )
      )
    ORDER BY album_asset.sort_taken_at DESC, album_asset.created_at DESC, album_asset.id DESC
    LIMIT $3
    "#;
