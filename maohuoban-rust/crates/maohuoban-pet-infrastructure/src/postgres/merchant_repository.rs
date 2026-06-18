use async_trait::async_trait;
use maohuoban_pet_application::pet::{
    MerchantAvailableStatusPublication, MerchantLitterDetail, MerchantLitterSummary,
    MerchantRepository, NewMerchantPetProfile, PublishAvailableStatusInput,
};
use maohuoban_pet_domain::pet::{
    ManagedPetStatus, MerchantProfile, MerchantStatusCount, PetEvent, PetProfile, PetRelationship,
    PetResult,
};
use uuid::Uuid;

use super::PostgresPetRepository;

mod merchant_commands;
mod merchant_detail;
mod merchant_helpers;
mod merchant_pet_rows;
mod merchant_queries;
mod merchant_rows;

#[async_trait]
impl MerchantRepository for PostgresPetRepository {
    async fn find_verified_merchant_for_owner(
        &self,
        owner_user_id: Uuid,
    ) -> PetResult<Option<MerchantProfile>> {
        self.find_verified_merchant_for_owner_query(owner_user_id)
            .await
    }

    async fn load_merchant_status_counts(
        &self,
        merchant_id: Uuid,
    ) -> PetResult<Vec<MerchantStatusCount>> {
        self.load_merchant_status_counts_query(merchant_id).await
    }

    async fn list_merchant_litter_summaries(
        &self,
        merchant_id: Uuid,
        limit: i64,
    ) -> PetResult<Vec<MerchantLitterSummary>> {
        self.list_merchant_litter_summaries_query(merchant_id, limit)
            .await
    }

    async fn list_merchant_relationships(
        &self,
        merchant_id: Uuid,
        limit: i64,
    ) -> PetResult<Vec<PetRelationship>> {
        self.list_merchant_relationships_query(merchant_id, limit)
            .await
    }

    async fn load_merchant_recent_events(
        &self,
        merchant_id: Uuid,
        limit: i64,
    ) -> PetResult<Vec<PetEvent>> {
        self.load_merchant_recent_events_query(merchant_id, limit)
            .await
    }

    async fn list_merchant_pets(
        &self,
        merchant_id: Uuid,
        status: ManagedPetStatus,
        limit: i64,
    ) -> PetResult<Vec<PetProfile>> {
        self.list_merchant_pets_query(merchant_id, status, limit)
            .await
    }

    async fn create_merchant_pet(&self, input: NewMerchantPetProfile) -> PetResult<PetProfile> {
        self.create_merchant_pet_command(input).await
    }

    async fn publish_available_status(
        &self,
        input: PublishAvailableStatusInput,
    ) -> PetResult<MerchantAvailableStatusPublication> {
        self.publish_available_status_command(input).await
    }

    async fn load_merchant_litter_detail(
        &self,
        merchant_id: Uuid,
        litter_id: Uuid,
    ) -> PetResult<Option<MerchantLitterDetail>> {
        self.load_merchant_litter_detail_command(merchant_id, litter_id)
            .await
    }
}
