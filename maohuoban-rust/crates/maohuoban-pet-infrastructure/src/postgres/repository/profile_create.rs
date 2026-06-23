use maohuoban_pet_application::pet::{NewPetProfile, PetProfileDiagnostics, record_pet_profile};
use maohuoban_pet_domain::pet::{PetError, PetProfile, PetResult};
use uuid::Uuid;

use super::PostgresPetRepository;
use super::rows::PetProfileRow;
use super::storage::{profile_number_from_uuid, to_infrastructure_error};

impl PostgresPetRepository {
    #[allow(clippy::too_many_lines)]
    pub(super) async fn create_pet_profile_command(
        &self,
        input: NewPetProfile,
    ) -> PetResult<PetProfile> {
        let pet_id = Uuid::new_v4();
        let owner_user_id = input.owner_user_id;
        let breed = input.breed.clone();
        record_pet_profile(PetProfileDiagnostics {
            stage: "repository.insert_start",
            action: "create",
            user_id: owner_user_id,
            pet_id: Some(pet_id),
            breed: breed.as_deref(),
            success: true,
        });
        let mut transaction = self.pool.begin().await.map_err(to_infrastructure_error)?;
        let row = sqlx::query_as::<_, PetProfileRow>(
            r#"
            INSERT INTO pet_profiles (
                id,
                owner_user_id,
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
                managed_status,
                source_kind
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, 'family', $15)
            RETURNING
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
                created_at,
                updated_at
            "#,
        )
        .bind(pet_id)
        .bind(owner_user_id)
        .bind(input.name)
        .bind(input.species.as_str())
        .bind(input.breed)
        .bind(input.sex.as_str())
        .bind(input.birthday)
        .bind(profile_number_from_uuid(pet_id))
        .bind(input.microchip_number)
        .bind(input.arrival_date)
        .bind(input.weight_grams)
        .bind(input.neuter_status.as_str())
        .bind(serde_json::json!(input.personality_tags))
        .bind(input.note)
        .bind(input.source_kind.as_str())
        .fetch_one(&mut *transaction)
        .await
        .map_err(to_infrastructure_error)?;

        let has_media_assets =
            input.avatar_asset_id.is_some() || input.background_asset_id.is_some();
        if let Some(asset_id) = input.avatar_asset_id {
            Self::bind_uploaded_media_in_transaction(
                &mut transaction,
                pet_id,
                owner_user_id,
                asset_id,
            )
            .await?;
        }
        if let Some(asset_id) = input.background_asset_id {
            Self::bind_uploaded_media_in_transaction(
                &mut transaction,
                pet_id,
                owner_user_id,
                asset_id,
            )
            .await?;
        }

        let pet = row.try_into()?;
        transaction
            .commit()
            .await
            .map_err(to_infrastructure_error)?;

        let pet = if has_media_assets {
            self.find_pet_for_owner_query(pet_id, owner_user_id)
                .await?
                .ok_or(PetError::PetNotFound)?
        } else {
            pet
        };

        let pet = self.attach_name_edit_policy(pet).await?;
        record_pet_profile(PetProfileDiagnostics {
            stage: "repository.inserted",
            action: "create",
            user_id: owner_user_id,
            pet_id: Some(pet.id),
            breed: pet.breed.as_deref(),
            success: true,
        });
        Ok(pet)
    }
}
