use maohuoban_pet_application::pet::MerchantLitterDetail;
use maohuoban_pet_domain::pet::{Litter, ManagedPetStatus, PetResult};
use uuid::Uuid;

use super::PostgresPetRepository;
use super::merchant_helpers::{
    list_litter_children, list_litter_recent_events, list_litter_relationships,
    load_merchant_pet_by_id, to_infrastructure_error,
};
use super::merchant_rows::LitterRow;

impl PostgresPetRepository {
    pub(super) async fn load_merchant_litter_detail_command(
        &self,
        merchant_id: Uuid,
        litter_id: Uuid,
    ) -> PetResult<Option<MerchantLitterDetail>> {
        let Some(litter_row) = sqlx::query_as::<_, LitterRow>(
            r#"
            SELECT
                id,
                merchant_id,
                name,
                species,
                sire_pet_id,
                dam_pet_id,
                born_at,
                born_count,
                alive_count,
                status,
                created_at,
                updated_at
            FROM litters
            WHERE merchant_id = $1 AND id = $2
            "#,
        )
        .bind(merchant_id)
        .bind(litter_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(to_infrastructure_error)?
        else {
            return Ok(None);
        };

        let litter: Litter = litter_row.try_into()?;
        let sire_pet = match litter.sire_pet_id {
            Some(pet_id) => load_merchant_pet_by_id(&self.pool, merchant_id, pet_id).await?,
            None => None,
        };
        let dam_pet = match litter.dam_pet_id {
            Some(pet_id) => load_merchant_pet_by_id(&self.pool, merchant_id, pet_id).await?,
            None => None,
        };
        let children = list_litter_children(&self.pool, merchant_id, litter_id).await?;
        let relationships = list_litter_relationships(&self.pool, merchant_id, litter_id).await?;
        let recent_events = list_litter_recent_events(&self.pool, merchant_id, litter_id).await?;
        let available_count = children
            .iter()
            .filter(|pet| pet.managed_status == ManagedPetStatus::Available)
            .count()
            .try_into()
            .unwrap_or(0);

        Ok(Some(MerchantLitterDetail {
            litter,
            sire_pet,
            dam_pet,
            children,
            relationships,
            recent_events,
            available_count,
        }))
    }
}
