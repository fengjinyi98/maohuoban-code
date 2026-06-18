use maohuoban_media_storage::MediaObjectStore;
use maohuoban_pet_application::pet::{PendingPetLivePhotoUploadInput, PendingPetMediaUploadInput};
use maohuoban_pet_domain::pet::{
    MediaAssetComponent, MediaAssetComponentKind, MediaDerivative, MediaUsageKind, PetError,
    PetMediaUploadResult, PetResult,
};

use super::MediaUploadObjectInput;
use super::diagnostics::{record_upload_failure, record_upload_stage};
use crate::postgres::repository::PostgresPetRepository;

impl PostgresPetRepository {
    pub(in crate::postgres::repository) async fn upload_pending_pet_media_command(
        &self,
        input: PendingPetMediaUploadInput,
    ) -> PetResult<PetMediaUploadResult> {
        let object_input = MediaUploadObjectInput::from(&input);
        let media_store = match MediaObjectStore::from_env() {
            Ok(media_store) => media_store,
            Err(error) => {
                record_upload_failure(&object_input, None, "repository.store_config");
                return Err(PetError::Infrastructure(error.to_string()));
            }
        };
        let mut prepared = match Self::prepare_media_object(&media_store, &object_input).await {
            Ok(prepared) => prepared,
            Err(error) => {
                record_upload_failure(&object_input, None, "repository.object_prepared");
                return Err(error);
            }
        };
        record_upload_stage("repository.object_prepared", &object_input, &prepared, 0);
        let prepared_derivatives =
            Self::prepare_upload_derivatives(&media_store, &object_input, &mut prepared).await?;
        let (asset_row, derivative_rows) = self
            .insert_pending_media_upload(&object_input, &prepared, &prepared_derivatives)
            .await?;

        let upload = PetMediaUploadResult {
            asset: asset_row.try_into()?,
            binding: None,
            derivatives: derivative_rows
                .into_iter()
                .map(TryInto::try_into)
                .collect::<PetResult<Vec<MediaDerivative>>>()?,
            components: Vec::new(),
        };
        record_upload_stage(
            "repository.committed",
            &object_input,
            &prepared,
            upload.derivatives.len(),
        );
        Ok(upload)
    }

    pub(in crate::postgres::repository) async fn upload_pending_pet_live_photo_command(
        &self,
        input: PendingPetLivePhotoUploadInput,
    ) -> PetResult<PetMediaUploadResult> {
        let media_store = MediaObjectStore::from_env()
            .map_err(|error| PetError::Infrastructure(error.to_string()))?;
        let mut primary_input = MediaUploadObjectInput {
            owner_user_id: input.owner_user_id,
            pet_id: None,
            usage_kind: MediaUsageKind::PetBackgroundLivePhoto,
            file_name: &input.still_file_name,
            mime_type: &input.still_mime_type,
            content: &input.still_content,
            source_client: input.source_client.as_deref(),
            crop_metadata: input.crop_metadata,
        };
        let mut prepared = Self::prepare_media_object(&media_store, &primary_input).await?;
        let paired_video_component = Self::prepare_live_photo_component(
            &media_store,
            &prepared,
            MediaAssetComponentKind::PairedVideo,
            &input.paired_video_file_name,
            &input.paired_video_mime_type,
            &input.paired_video_content,
        )
        .await?;
        let still_component =
            Self::prepared_still_component_from_primary(&prepared, &input.still_mime_type);
        let components = vec![still_component, paired_video_component];
        let prepared_derivatives = Self::prepare_live_photo_upload_derivatives(
            &media_store,
            &primary_input,
            &input.paired_video_file_name,
            &input.paired_video_content,
            &mut prepared,
        )
        .await?;
        primary_input.source_client = input.source_client.as_deref();

        let (asset_row, component_rows, derivative_rows) = self
            .insert_pending_live_photo_upload(
                &primary_input,
                &prepared,
                &components,
                &prepared_derivatives,
            )
            .await?;
        Ok(PetMediaUploadResult {
            asset: asset_row.try_into()?,
            binding: None,
            derivatives: derivative_rows
                .into_iter()
                .map(TryInto::try_into)
                .collect::<PetResult<Vec<MediaDerivative>>>()?,
            components: component_rows
                .into_iter()
                .map(TryInto::try_into)
                .collect::<PetResult<Vec<MediaAssetComponent>>>()?,
        })
    }
}
