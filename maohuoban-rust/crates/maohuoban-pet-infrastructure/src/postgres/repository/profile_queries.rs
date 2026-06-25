use maohuoban_pet_domain::pet::{PetProfile, PetResult};
use sqlx::PgPool;
use uuid::Uuid;

use super::rows::PetProfileRow;
use super::storage::to_infrastructure_error;

pub(super) async fn load_pet_profile_for_update(
    pool: &PgPool,
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
    .fetch_optional(pool)
    .await
    .map_err(to_infrastructure_error)?;

    row.map(TryInto::try_into).transpose()
}
