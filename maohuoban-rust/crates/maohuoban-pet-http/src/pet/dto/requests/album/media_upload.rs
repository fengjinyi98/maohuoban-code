use maohuoban_pet_application::pet::PendingPetMediaUploadInput;
use maohuoban_pet_domain::pet::MediaUsageKind;
use uuid::Uuid;

use crate::pet::dto::requests::media::UploadPetMediaRequest;

impl UploadPetMediaRequest {
    pub(crate) fn into_pending_album_photo_input(
        self,
        owner_user_id: Uuid,
    ) -> PendingPetMediaUploadInput {
        self.into_pending_input(owner_user_id, MediaUsageKind::PetAlbumPhoto)
    }
}
