use maohuoban_pet_domain::pet::{MediaUsageKind, PetError, PetResult};
use uuid::Uuid;

use super::PetService;
use super::validation::{pet_error_kind, validate_text};
use crate::pet::{
    BindUploadedPetMediaInput, MediaAssetDisplayMetadata, MediaBindingDiagnostics,
    MediaUploadDiagnostics, PendingPetLivePhotoUploadInput, PendingPetMediaUploadInput,
    record_media_binding, record_media_upload,
};

impl PetService {
    pub async fn upload_pending_pet_media(
        &self,
        input: PendingPetMediaUploadInput,
    ) -> PetResult<maohuoban_pet_domain::pet::PetMediaUploadResult> {
        validate_text("文件名", &input.file_name)?;
        validate_text("媒体类型", &input.mime_type)?;
        if input.content.is_empty() {
            return Err(PetError::InvalidInput("媒体内容不能为空".to_owned()));
        }
        let owner_user_id = input.owner_user_id;
        let usage_kind = input.usage_kind;
        let mime_type = input.mime_type.clone();
        let byte_size = i64::try_from(input.content.len()).unwrap_or(i64::MAX);
        record_media_upload(MediaUploadDiagnostics {
            stage: "service.request",
            user_id: owner_user_id,
            asset_id: None,
            usage_kind,
            mime_type: &mime_type,
            byte_size,
            width: None,
            height: None,
            derivative_count: 0,
            success: true,
            error_kind: None,
        });
        let result = self.repository.upload_pending_pet_media(input).await;
        match &result {
            Ok(upload) => record_media_upload(MediaUploadDiagnostics {
                stage: "service.result",
                user_id: owner_user_id,
                asset_id: Some(upload.asset.id),
                usage_kind,
                mime_type: &upload.asset.mime_type,
                byte_size: upload.asset.byte_size,
                width: upload.asset.width,
                height: upload.asset.height,
                derivative_count: upload.derivatives.len(),
                success: true,
                error_kind: None,
            }),
            Err(error) => record_media_upload(MediaUploadDiagnostics {
                stage: "service.result",
                user_id: owner_user_id,
                asset_id: None,
                usage_kind,
                mime_type: &mime_type,
                byte_size,
                width: None,
                height: None,
                derivative_count: 0,
                success: false,
                error_kind: Some(pet_error_kind(error)),
            }),
        }
        result
    }

    pub async fn upload_pending_pet_live_photo(
        &self,
        input: PendingPetLivePhotoUploadInput,
    ) -> PetResult<maohuoban_pet_domain::pet::PetMediaUploadResult> {
        validate_text("静态图文件名", &input.still_file_name)?;
        validate_text("静态图媒体类型", &input.still_mime_type)?;
        validate_text("配对视频文件名", &input.paired_video_file_name)?;
        validate_text("配对视频媒体类型", &input.paired_video_mime_type)?;
        if input.still_content.is_empty() || input.paired_video_content.is_empty() {
            return Err(PetError::InvalidInput("Live Photo 资源不能为空".to_owned()));
        }

        let owner_user_id = input.owner_user_id;
        let mime_type = input.still_mime_type.clone();
        let byte_size = i64::try_from(input.still_content.len() + input.paired_video_content.len())
            .unwrap_or(i64::MAX);
        record_media_upload(MediaUploadDiagnostics {
            stage: "service.request",
            user_id: owner_user_id,
            asset_id: None,
            usage_kind: MediaUsageKind::PetBackgroundLivePhoto,
            mime_type: &mime_type,
            byte_size,
            width: None,
            height: None,
            derivative_count: 0,
            success: true,
            error_kind: None,
        });
        let result = self.repository.upload_pending_pet_live_photo(input).await;
        match &result {
            Ok(upload) => record_media_upload(MediaUploadDiagnostics {
                stage: "service.result",
                user_id: owner_user_id,
                asset_id: Some(upload.asset.id),
                usage_kind: upload.asset.usage_kind,
                mime_type: &upload.asset.mime_type,
                byte_size: upload.asset.byte_size,
                width: upload.asset.width,
                height: upload.asset.height,
                derivative_count: upload.derivatives.len(),
                success: true,
                error_kind: None,
            }),
            Err(error) => record_media_upload(MediaUploadDiagnostics {
                stage: "service.result",
                user_id: owner_user_id,
                asset_id: None,
                usage_kind: MediaUsageKind::PetBackgroundLivePhoto,
                mime_type: &mime_type,
                byte_size,
                width: None,
                height: None,
                derivative_count: 0,
                success: false,
                error_kind: Some(pet_error_kind(error)),
            }),
        }
        result
    }

    pub async fn bind_uploaded_pet_media(
        &self,
        input: BindUploadedPetMediaInput,
    ) -> PetResult<maohuoban_pet_domain::pet::PetMediaUploadResult> {
        if self
            .repository
            .authorize_pet_access(input.pet_id, input.owner_user_id)
            .await?
            .is_none()
        {
            return Err(PetError::PetNotFound);
        }
        let owner_user_id = input.owner_user_id;
        let pet_id = input.pet_id;
        let asset_id = input.asset_id;
        let result = self.repository.bind_uploaded_pet_media(input).await;
        match &result {
            Ok(upload) => record_media_binding(MediaBindingDiagnostics {
                stage: "service.result",
                user_id: owner_user_id,
                pet_id,
                asset_id,
                usage_kind: Some(upload.asset.usage_kind),
                width: upload.asset.width,
                height: upload.asset.height,
                derivative_count: upload.derivatives.len(),
                success: true,
                error_kind: None,
            }),
            Err(error) => record_media_binding(MediaBindingDiagnostics {
                stage: "service.result",
                user_id: owner_user_id,
                pet_id,
                asset_id,
                usage_kind: None,
                width: None,
                height: None,
                derivative_count: 0,
                success: false,
                error_kind: Some(pet_error_kind(error)),
            }),
        }
        result
    }

    pub async fn list_media_display_metadata(
        &self,
        asset_ids: &[Uuid],
    ) -> PetResult<Vec<MediaAssetDisplayMetadata>> {
        self.repository.list_media_display_metadata(asset_ids).await
    }
}
