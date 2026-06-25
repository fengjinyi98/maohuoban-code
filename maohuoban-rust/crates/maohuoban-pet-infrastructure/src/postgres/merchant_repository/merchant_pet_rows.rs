use chrono::{DateTime, NaiveDate, Utc};
use maohuoban_pet_domain::pet::{
    LifeStatus, ManagedPetStatus, OriginKind, PetBackgroundMediaKind, PetError, PetNeuterStatus,
    PetProfile, PetSex, PetSourceKind, PetSpecies,
};
use serde_json::Value;
use sqlx::FromRow;
use uuid::Uuid;

#[derive(Debug, FromRow)]
pub(super) struct MerchantManagedPetRow {
    id: Uuid,
    owner_user_id: Option<Uuid>,
    merchant_id: Option<Uuid>,
    name: String,
    species: String,
    breed: Option<String>,
    sex: String,
    birthday: Option<NaiveDate>,
    profile_number: String,
    microchip_number: Option<String>,
    arrival_date: Option<NaiveDate>,
    weight_grams: Option<i32>,
    neuter_status: String,
    personality_tags: Value,
    note: Option<String>,
    avatar_asset_id: Option<Uuid>,
    background_asset_id: Option<Uuid>,
    background_media_kind: Option<String>,
    deleted_at: Option<DateTime<Utc>>,
    delete_requested_by_user_id: Option<Uuid>,
    recoverable_until: Option<DateTime<Utc>>,
    delete_reason: Option<String>,
    managed_status: String,
    source_kind: String,
    life_status: String,
    origin_kind: String,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
}

impl TryFrom<MerchantManagedPetRow> for PetProfile {
    type Error = PetError;

    fn try_from(row: MerchantManagedPetRow) -> Result<Self, Self::Error> {
        Ok(Self {
            id: row.id,
            owner_user_id: row.owner_user_id,
            merchant_id: row.merchant_id,
            name: row.name,
            species: PetSpecies::try_from(row.species.as_str()).map_err(|_| {
                PetError::Infrastructure("unknown species from database".to_owned())
            })?,
            breed: row.breed,
            sex: PetSex::try_from(row.sex.as_str())
                .map_err(|_| PetError::Infrastructure("unknown sex from database".to_owned()))?,
            birthday: row.birthday,
            profile_number: row.profile_number,
            microchip_number: row.microchip_number,
            external_identifiers: vec![],
            arrival_date: row.arrival_date,
            weight_grams: row.weight_grams,
            neuter_status: PetNeuterStatus::try_from(row.neuter_status.as_str()).map_err(|_| {
                PetError::Infrastructure("unknown neuter status from database".to_owned())
            })?,
            personality_tags: serde_json::from_value(row.personality_tags).map_err(|error| {
                PetError::Infrastructure(format!("invalid personality tags from database: {error}"))
            })?,
            note: row.note,
            avatar_asset_id: row.avatar_asset_id,
            background_asset_id: row.background_asset_id,
            background_media_kind: row
                .background_media_kind
                .as_deref()
                .map(PetBackgroundMediaKind::try_from)
                .transpose()
                .map_err(|_| {
                    PetError::Infrastructure(
                        "unknown background media kind from database".to_owned(),
                    )
                })?,
            deleted_at: row.deleted_at,
            delete_requested_by_user_id: row.delete_requested_by_user_id,
            recoverable_until: row.recoverable_until,
            delete_reason: row.delete_reason,
            name_edit_policy: None,
            managed_status: ManagedPetStatus::try_from(row.managed_status.as_str()).map_err(
                |_| PetError::Infrastructure("unknown managed status from database".to_owned()),
            )?,
            source_kind: PetSourceKind::try_from(row.source_kind.as_str()).map_err(|_| {
                PetError::Infrastructure("unknown source kind from database".to_owned())
            })?,
            life_status: LifeStatus::try_from(row.life_status.as_str()).map_err(|_| {
                PetError::Infrastructure("unknown life status from database".to_owned())
            })?,
            origin_kind: OriginKind::try_from(row.origin_kind.as_str()).map_err(|_| {
                PetError::Infrastructure("unknown origin kind from database".to_owned())
            })?,
            created_at: row.created_at,
            updated_at: row.updated_at,
        })
    }
}
