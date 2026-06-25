use maohuoban_pet_domain::pet::{PetProfile, PetResult};
use uuid::Uuid;

use super::PostgresPetRepository;
use super::rows::PetProfileRow;
use super::storage::to_infrastructure_error;

impl PostgresPetRepository {
    pub(super) async fn find_pet_for_owner_query(
        &self,
        pet_id: Uuid,
        owner_user_id: Uuid,
    ) -> PetResult<Option<PetProfile>> {
        let row = sqlx::query_as::<_, PetProfileRow>(
            r#"
            SELECT
                id,
                owner_user_id,
                merchant_id,
                name,
                species,
                breed,
                sex,
                birthday,
                profile_number,
                microchip_number,
                arrival_date,
                weight_grams,
                neuter_status,
                personality_tags,
                note,
                avatar_asset_id,
                background_asset_id,
                background_media_kind,
                deleted_at,
                delete_requested_by_user_id,
                recoverable_until,
                delete_reason,
                managed_status,
                source_kind,
                life_status,
                origin_kind,
                created_at,
                updated_at
            FROM pet_profiles
            WHERE id = $1 AND owner_user_id = $2 AND deleted_at IS NULL
            "#,
        )
        .bind(pet_id)
        .bind(owner_user_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        let Some(row) = row else {
            return Ok(None);
        };
        let pet = row.try_into()?;
        Ok(Some(self.attach_name_edit_policy(pet).await?))
    }

    pub(super) async fn list_pet_profiles_for_owner_query(
        &self,
        owner_user_id: Uuid,
    ) -> PetResult<Vec<PetProfile>> {
        let rows = sqlx::query_as::<_, PetProfileRow>(
            r#"
            SELECT
                id,
                owner_user_id,
                merchant_id,
                name,
                species,
                breed,
                sex,
                birthday,
                profile_number,
                microchip_number,
                arrival_date,
                weight_grams,
                neuter_status,
                personality_tags,
                note,
                avatar_asset_id,
                background_asset_id,
                background_media_kind,
                deleted_at,
                delete_requested_by_user_id,
                recoverable_until,
                delete_reason,
                managed_status,
                source_kind,
                life_status,
                origin_kind,
                created_at,
                updated_at
            FROM pet_profiles
            WHERE owner_user_id = $1 AND deleted_at IS NULL
            ORDER BY created_at ASC
            "#,
        )
        .bind(owner_user_id)
        .fetch_all(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        let mut pets = Vec::with_capacity(rows.len());
        for row in rows {
            pets.push(self.attach_name_edit_policy(row.try_into()?).await?);
        }
        Ok(pets)
    }
}
