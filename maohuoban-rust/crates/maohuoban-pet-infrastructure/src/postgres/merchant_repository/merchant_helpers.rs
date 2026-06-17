use maohuoban_pet_domain::pet::{PetError, PetEvent, PetProfile, PetRelationship, PetResult};
use uuid::Uuid;

use super::merchant_rows::{MerchantManagedPetRow, MerchantPetEventRow, PetRelationshipRow};

pub(super) fn to_infrastructure_error(error: sqlx::Error) -> PetError {
    PetError::Infrastructure(error.to_string())
}

pub(super) fn profile_number_from_uuid(id: Uuid) -> String {
    let raw = id.as_u128() % 10_000_000_000_000_000;
    format!("{raw:016}")
}

pub(super) async fn load_merchant_pet_by_id(
    pool: &sqlx::PgPool,
    merchant_id: Uuid,
    pet_id: Uuid,
) -> PetResult<Option<PetProfile>> {
    let row = sqlx::query_as::<_, MerchantManagedPetRow>(
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
            created_at,
            updated_at
        FROM pet_profiles
        WHERE merchant_id = $1 AND id = $2 AND deleted_at IS NULL
        "#,
    )
    .bind(merchant_id)
    .bind(pet_id)
    .fetch_optional(pool)
    .await
    .map_err(to_infrastructure_error)?;

    row.map(TryInto::try_into).transpose()
}

pub(super) async fn list_litter_children(
    pool: &sqlx::PgPool,
    merchant_id: Uuid,
    litter_id: Uuid,
) -> PetResult<Vec<PetProfile>> {
    let rows = sqlx::query_as::<_, MerchantManagedPetRow>(
        r#"
        SELECT DISTINCT
            p.id,
            p.owner_user_id,
            p.merchant_id,
            p.name,
            p.species,
            p.breed,
            p.sex,
            p.birthday,
            p.profile_number,
            p.microchip_number,
            p.arrival_date,
            p.weight_grams,
            p.neuter_status,
            p.personality_tags,
            p.note,
            p.avatar_asset_id,
            p.background_asset_id,
            p.background_media_kind,
            p.deleted_at,
            p.delete_requested_by_user_id,
            p.recoverable_until,
            p.delete_reason,
            p.managed_status,
            p.source_kind,
            p.created_at,
            p.updated_at
        FROM pet_relationships rel
        INNER JOIN pet_profiles p ON p.id = rel.subject_pet_id
        WHERE rel.litter_id = $1 AND p.merchant_id = $2 AND p.deleted_at IS NULL
        ORDER BY p.created_at ASC, p.name ASC
        "#,
    )
    .bind(litter_id)
    .bind(merchant_id)
    .fetch_all(pool)
    .await
    .map_err(to_infrastructure_error)?;

    rows.into_iter().map(TryInto::try_into).collect()
}

pub(super) async fn list_litter_relationships(
    pool: &sqlx::PgPool,
    merchant_id: Uuid,
    litter_id: Uuid,
) -> PetResult<Vec<PetRelationship>> {
    let rows = sqlx::query_as::<_, PetRelationshipRow>(
        r#"
        SELECT
            rel.id,
            rel.subject_pet_id,
            rel.related_pet_id,
            rel.litter_id,
            rel.relationship_kind,
            rel.source_kind,
            rel.evidence_snapshot_id,
            rel.created_at
        FROM pet_relationships rel
        INNER JOIN pet_profiles subject ON subject.id = rel.subject_pet_id
        WHERE rel.litter_id = $1 AND subject.merchant_id = $2
        ORDER BY rel.created_at ASC
        "#,
    )
    .bind(litter_id)
    .bind(merchant_id)
    .fetch_all(pool)
    .await
    .map_err(to_infrastructure_error)?;

    rows.into_iter().map(TryInto::try_into).collect()
}

pub(super) async fn list_litter_recent_events(
    pool: &sqlx::PgPool,
    merchant_id: Uuid,
    litter_id: Uuid,
) -> PetResult<Vec<PetEvent>> {
    let rows = sqlx::query_as::<_, MerchantPetEventRow>(
        r#"
        SELECT
            e.id,
            e.pet_id,
            e.litter_id,
            e.event_kind,
            e.event_subkind,
            e.title,
            e.summary,
            e.visibility,
            e.event_payload,
            e.occurred_at,
            e.actor_user_id,
            e.evidence_snapshot_id,
            e.record_revision,
            e.created_at,
            e.updated_at
        FROM pet_events e
        INNER JOIN litters l ON l.id = e.litter_id
        WHERE e.litter_id = $1 AND l.merchant_id = $2
        ORDER BY e.occurred_at DESC, e.created_at DESC
        LIMIT 20
        "#,
    )
    .bind(litter_id)
    .bind(merchant_id)
    .fetch_all(pool)
    .await
    .map_err(to_infrastructure_error)?;

    rows.into_iter().map(TryInto::try_into).collect()
}
