mod album;
mod binding;
mod diet_assignment;
mod event;
mod food_inventory;
mod media;
mod merchant;
mod profile;
mod trade;
mod weight_record;

pub(crate) use album::{AddPetAlbumAssetRequest, CreatePetAlbumRequest, UpdatePetAlbumRequest};
pub(crate) use binding::BindUploadedPetMediaRequest;
pub(crate) use diet_assignment::{SetPetCurrentStapleRequest, SetPetDietAssignmentRequest};
pub(crate) use event::{CreatePetEventRequest, UpdatePetEventRequest};
pub(crate) use food_inventory::{CreateFoodInventoryItemRequest, UpdateFoodInventoryItemRequest};
pub(crate) use media::{UploadPetLivePhotoRequest, UploadPetMediaRequest};
pub(crate) use merchant::{CreateMerchantPetRequest, PublishAvailableStatusRequest};
pub(crate) use profile::{
    CreatePetProfileRequest, DeletePetProfileRequest, UpdatePetProfileRequest,
};
pub(crate) use trade::TradePetImportRequest;
pub(crate) use weight_record::{CreatePetWeightRecordRequest, UpdatePetWeightRecordRequest};
