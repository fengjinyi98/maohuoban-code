use maohuoban_pet_domain::pet::{ManagedPetStatus, PetError, PetProfile, PetResult};
use uuid::Uuid;

use super::PetService;
use super::validation::{
    normalize_compact_text, normalize_optional_compact_text, validate_pet_name,
};
use crate::pet::{
    MerchantAvailableStatusPublication, MerchantDashboardSummary, MerchantLitterDetail,
    NewMerchantPetProfile, PublishAvailableStatusInput,
};

impl PetService {
    pub async fn load_merchant_dashboard(
        &self,
        owner_user_id: Uuid,
    ) -> PetResult<Option<MerchantDashboardSummary>> {
        let Some(merchant) = self
            .merchant_repository
            .find_verified_merchant_for_owner(owner_user_id)
            .await?
        else {
            return Ok(None);
        };

        let status_counts = self
            .merchant_repository
            .load_merchant_status_counts(merchant.id)
            .await?;
        let litters = self
            .merchant_repository
            .list_merchant_litter_summaries(merchant.id, 5)
            .await?;
        let relationships = self
            .merchant_repository
            .list_merchant_relationships(merchant.id, 20)
            .await?;
        let recent_events = self
            .merchant_repository
            .load_merchant_recent_events(merchant.id, 5)
            .await?;

        Ok(Some(MerchantDashboardSummary {
            merchant,
            status_counts,
            litters,
            relationships,
            recent_events,
        }))
    }

    pub async fn list_merchant_pets(
        &self,
        owner_user_id: Uuid,
        merchant_id: Uuid,
        status: ManagedPetStatus,
    ) -> PetResult<Vec<PetProfile>> {
        let Some(merchant) = self
            .merchant_repository
            .find_verified_merchant_for_owner(owner_user_id)
            .await?
        else {
            return Err(PetError::Forbidden);
        };
        if merchant.id != merchant_id {
            return Err(PetError::Forbidden);
        }

        self.merchant_repository
            .list_merchant_pets(merchant_id, status, 100)
            .await
    }

    pub async fn create_merchant_pet(
        &self,
        owner_user_id: Uuid,
        mut input: NewMerchantPetProfile,
    ) -> PetResult<PetProfile> {
        input.name = normalize_compact_text(&input.name);
        input.breed = normalize_optional_compact_text(input.breed);
        validate_pet_name(&input.name)?;
        if input.managed_status == ManagedPetStatus::Family {
            return Err(PetError::InvalidInput("商家宠物状态无效".to_owned()));
        }

        let Some(merchant) = self
            .merchant_repository
            .find_verified_merchant_for_owner(owner_user_id)
            .await?
        else {
            return Err(PetError::Forbidden);
        };
        if merchant.id != input.merchant_id {
            return Err(PetError::Forbidden);
        }

        self.merchant_repository.create_merchant_pet(input).await
    }

    pub async fn publish_available_status(
        &self,
        owner_user_id: Uuid,
        input: PublishAvailableStatusInput,
    ) -> PetResult<MerchantAvailableStatusPublication> {
        let Some(merchant) = self
            .merchant_repository
            .find_verified_merchant_for_owner(owner_user_id)
            .await?
        else {
            return Err(PetError::Forbidden);
        };
        if merchant.id != input.merchant_id || input.actor_user_id != owner_user_id {
            return Err(PetError::Forbidden);
        }

        self.merchant_repository
            .publish_available_status(input)
            .await
    }

    pub async fn load_merchant_litter_detail(
        &self,
        owner_user_id: Uuid,
        merchant_id: Uuid,
        litter_id: Uuid,
    ) -> PetResult<MerchantLitterDetail> {
        let Some(merchant) = self
            .merchant_repository
            .find_verified_merchant_for_owner(owner_user_id)
            .await?
        else {
            return Err(PetError::Forbidden);
        };
        if merchant.id != merchant_id {
            return Err(PetError::Forbidden);
        }

        self.merchant_repository
            .load_merchant_litter_detail(merchant_id, litter_id)
            .await?
            .ok_or(PetError::PetNotFound)
    }
}
