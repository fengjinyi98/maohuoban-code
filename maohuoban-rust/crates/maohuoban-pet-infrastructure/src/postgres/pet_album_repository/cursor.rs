use chrono::{DateTime, SecondsFormat, Utc};
use maohuoban_pet_domain::pet::{PetError, PetResult};
use uuid::Uuid;

use super::rows::{PetAlbumAssetRow, PetAlbumRow};

type AlbumCursorParts = (Option<bool>, Option<DateTime<Utc>>, Option<Uuid>);
type AlbumAssetCursorParts = (Option<DateTime<Utc>>, Option<DateTime<Utc>>, Option<Uuid>);

pub(super) fn encode_album_cursor(row: &PetAlbumRow) -> String {
    format!(
        "{}~{}~{}",
        i32::from(row.is_pinned),
        row.updated_at.to_rfc3339_opts(SecondsFormat::Nanos, true),
        row.id
    )
}

pub(super) fn decode_album_cursor(cursor: Option<String>) -> PetResult<AlbumCursorParts> {
    let Some(cursor) = cursor else {
        return Ok((None, None, None));
    };
    let parts = cursor.split('~').collect::<Vec<_>>();
    if parts.len() != 3 {
        return Err(PetError::InvalidInput("相册分页游标无效".to_owned()));
    }
    let is_pinned = match parts[0] {
        "1" => true,
        "0" => false,
        _ => return Err(PetError::InvalidInput("相册分页游标无效".to_owned())),
    };
    let updated_at = DateTime::parse_from_rfc3339(parts[1])
        .map_err(|_| PetError::InvalidInput("相册分页游标无效".to_owned()))?
        .with_timezone(&Utc);
    let id = Uuid::parse_str(parts[2])
        .map_err(|_| PetError::InvalidInput("相册分页游标无效".to_owned()))?;
    Ok((Some(is_pinned), Some(updated_at), Some(id)))
}

pub(super) fn encode_album_asset_cursor(row: &PetAlbumAssetRow) -> String {
    format!(
        "{}~{}~{}",
        row.sort_taken_at
            .to_rfc3339_opts(SecondsFormat::Nanos, true),
        row.created_at.to_rfc3339_opts(SecondsFormat::Nanos, true),
        row.id
    )
}

pub(super) fn decode_album_asset_cursor(
    cursor: Option<String>,
) -> PetResult<AlbumAssetCursorParts> {
    let Some(cursor) = cursor else {
        return Ok((None, None, None));
    };
    let parts = cursor.split('~').collect::<Vec<_>>();
    if parts.len() != 3 {
        return Err(PetError::InvalidInput("相册照片分页游标无效".to_owned()));
    }
    let sort_taken_at = DateTime::parse_from_rfc3339(parts[0])
        .map_err(|_| PetError::InvalidInput("相册照片分页游标无效".to_owned()))?
        .with_timezone(&Utc);
    let created_at = DateTime::parse_from_rfc3339(parts[1])
        .map_err(|_| PetError::InvalidInput("相册照片分页游标无效".to_owned()))?
        .with_timezone(&Utc);
    let id = Uuid::parse_str(parts[2])
        .map_err(|_| PetError::InvalidInput("相册照片分页游标无效".to_owned()))?;
    Ok((Some(sort_taken_at), Some(created_at), Some(id)))
}
