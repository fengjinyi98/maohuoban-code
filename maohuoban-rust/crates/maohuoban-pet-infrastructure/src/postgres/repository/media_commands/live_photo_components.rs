use maohuoban_media_storage::MediaObjectStore;
use maohuoban_pet_domain::pet::{MediaAssetComponentKind, PetError, PetResult};
use uuid::Uuid;

use super::image_metadata::image_dimensions;
use super::{PreparedMediaComponent, PreparedMediaObject};
use crate::postgres::repository::PostgresPetRepository;
use crate::postgres::repository::storage::{sanitized_file_name, sha256_hex};

impl PostgresPetRepository {
    pub(super) fn prepared_still_component_from_primary(
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

    pub(super) async fn prepare_live_photo_component(
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
