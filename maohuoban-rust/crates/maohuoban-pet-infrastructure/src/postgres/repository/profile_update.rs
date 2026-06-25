use maohuoban_pet_application::pet::{
    PetProfileDiagnostics, UpdatePetProfile, UpdatePetProfileResult, record_pet_profile,
};
use maohuoban_pet_domain::pet::{
    PetError, PetNeuterStatus, PetProfile, PetResult, PetSex, PetSpecies,
};

use super::PostgresPetRepository;
use super::profile_queries::load_pet_profile_for_update;
use super::rows::PetProfileRow;
use super::storage::to_infrastructure_error;

impl PostgresPetRepository {
    pub(super) async fn update_pet_profile_command(
        &self,
        input: UpdatePetProfile,
    ) -> PetResult<UpdatePetProfileResult> {
        let owner_user_id = input.owner_user_id;
        let pet_id = input.pet_id;
        let breed = input.breed.clone();
        record_pet_profile(PetProfileDiagnostics {
            stage: "repository.update_start",
            action: "update",
            user_id: owner_user_id,
            pet_id: Some(pet_id),
            breed: breed.as_deref(),
            success: true,
        });
        let current = load_pet_profile_for_update(&self.pool, input.pet_id, input.owner_user_id)
            .await?
            .ok_or(PetError::PetNotFound)?;
        let requested_microchip = input
            .microchip_number
            .as_deref()
            .map(str::trim)
            .map(str::to_owned);
        let requested_name = input.name.as_deref().map(str::trim).map(str::to_owned);
        let is_name_changed = requested_name
            .as_deref()
            .is_some_and(|name| name != current.name);
        if is_name_changed {
            let policy = self.load_name_edit_policy(input.pet_id).await?;
            if policy.remaining_count <= 0 {
                return Err(PetError::NameEditLimitExceeded);
            }
        }
        if let (Some(existing), Some(requested)) = (
            current.microchip_number.as_deref(),
            requested_microchip.as_deref(),
        ) && existing != requested
        {
            return Err(PetError::InvalidInput(
                "芯片号已锁定，如需变更请通过申诉渠道处理".to_owned(),
            ));
        }
        if !has_profile_changes(
            &current,
            &input,
            requested_name.as_deref(),
            requested_microchip.as_deref(),
        ) {
            let pet = self.attach_name_edit_policy(current).await?;
            record_pet_profile(PetProfileDiagnostics {
                stage: "repository.unchanged",
                action: "update",
                user_id: owner_user_id,
                pet_id: Some(pet.id),
                breed: pet.breed.as_deref(),
                success: true,
            });
            return Ok(UpdatePetProfileResult {
                profile: pet,
                changed: false,
            });
        }

        let row = self
            .execute_profile_update(
                input,
                requested_name.as_deref(),
                requested_microchip.as_deref(),
            )
            .await?;

        if is_name_changed && let Some(new_name) = requested_name.as_deref() {
            self.record_name_change(pet_id, owner_user_id, &current.name, new_name)
                .await?;
        }

        let pet = self.attach_name_edit_policy(row.try_into()?).await?;
        record_pet_profile(PetProfileDiagnostics {
            stage: "repository.updated",
            action: "update",
            user_id: owner_user_id,
            pet_id: Some(pet.id),
            breed: pet.breed.as_deref(),
            success: true,
        });
        Ok(UpdatePetProfileResult {
            profile: pet,
            changed: true,
        })
    }

    async fn execute_profile_update(
        &self,
        input: UpdatePetProfile,
        requested_name: Option<&str>,
        requested_microchip: Option<&str>,
    ) -> PetResult<PetProfileRow> {
        sqlx::query_as::<_, PetProfileRow>(
            r#"
            UPDATE pet_profiles
            SET
                name = COALESCE($3, name),
                species = COALESCE($4, species),
                breed = COALESCE($5, breed),
                sex = COALESCE($6, sex),
                birthday = COALESCE($7, birthday),
                microchip_number = COALESCE($8, microchip_number),
                arrival_date = COALESCE($9, arrival_date),
                weight_grams = COALESCE($10, weight_grams),
                neuter_status = COALESCE($11, neuter_status),
                personality_tags = COALESCE($12, personality_tags),
                note = COALESCE($13, note),
                updated_at = now()
            WHERE id = $1 AND owner_user_id = $2 AND deleted_at IS NULL
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
                life_status,
                origin_kind,
                created_at,
                updated_at
            "#,
        )
        .bind(input.pet_id)
        .bind(input.owner_user_id)
        .bind(requested_name)
        .bind(input.species.map(PetSpecies::as_str))
        .bind(input.breed)
        .bind(input.sex.map(PetSex::as_str))
        .bind(input.birthday)
        .bind(requested_microchip)
        .bind(input.arrival_date)
        .bind(input.weight_grams)
        .bind(input.neuter_status.map(PetNeuterStatus::as_str))
        .bind(input.personality_tags.map(|tags| serde_json::json!(tags)))
        .bind(input.note)
        .fetch_optional(&self.pool)
        .await
        .map_err(to_infrastructure_error)?
        .ok_or(PetError::PetNotFound)
    }
}

fn has_profile_changes(
    current: &PetProfile,
    input: &UpdatePetProfile,
    requested_name: Option<&str>,
    requested_microchip: Option<&str>,
) -> bool {
    requested_name.is_some_and(|name| name != current.name)
        || input
            .species
            .is_some_and(|species| species != current.species)
        || input
            .breed
            .as_deref()
            .is_some_and(|breed| Some(breed) != current.breed.as_deref())
        || input.sex.is_some_and(|sex| sex != current.sex)
        || input
            .birthday
            .is_some_and(|birthday| Some(birthday) != current.birthday)
        || requested_microchip
            .is_some_and(|microchip| Some(microchip) != current.microchip_number.as_deref())
        || input
            .arrival_date
            .is_some_and(|arrival_date| Some(arrival_date) != current.arrival_date)
        || input
            .weight_grams
            .is_some_and(|weight_grams| Some(weight_grams) != current.weight_grams)
        || input
            .neuter_status
            .is_some_and(|neuter_status| neuter_status != current.neuter_status)
        || input
            .personality_tags
            .as_ref()
            .is_some_and(|personality_tags| personality_tags != &current.personality_tags)
        || input
            .note
            .as_deref()
            .is_some_and(|note| Some(note) != current.note.as_deref())
}
