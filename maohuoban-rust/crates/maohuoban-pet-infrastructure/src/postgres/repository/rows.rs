use chrono::{DateTime, NaiveDate, Utc};
use maohuoban_pet_domain::pet::{
    EventKind, EventVisibility, ManagedPetStatus, MediaAsset, MediaAssetStatus, MediaBinding,
    MediaBindingStatus, MediaDerivative, MediaDerivativeKind, MediaUsageKind,
    PetBackgroundMediaKind, PetError, PetEvent, PetNeuterStatus, PetProfile, PetSex, PetSourceKind,
    PetSpecies,
};
use serde_json::Value;
use sqlx::FromRow;
use uuid::Uuid;

#[derive(Debug, FromRow)]
pub(super) struct PetProfileRow {
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
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
}

impl TryFrom<PetProfileRow> for PetProfile {
    type Error = PetError;

    fn try_from(row: PetProfileRow) -> Result<Self, Self::Error> {
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
            managed_status: ManagedPetStatus::try_from(row.managed_status.as_str()).map_err(
                |_| PetError::Infrastructure("unknown managed status from database".to_owned()),
            )?,
            source_kind: PetSourceKind::try_from(row.source_kind.as_str()).map_err(|_| {
                PetError::Infrastructure("unknown source kind from database".to_owned())
            })?,
            created_at: row.created_at,
            updated_at: row.updated_at,
        })
    }
}

#[derive(Debug, FromRow)]
pub(super) struct MediaAssetRow {
    id: Uuid,
    uploaded_by_user_id: Option<Uuid>,
    owner_pet_id: Option<Uuid>,
    usage_kind: String,
    source_client: Option<String>,
    original_file_name: Option<String>,
    mime_type: String,
    byte_size: i64,
    sha256_hex: String,
    bucket: String,
    object_key: String,
    status: String,
    delete_after: Option<DateTime<Utc>>,
    deleted_at: Option<DateTime<Utc>>,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
}

impl TryFrom<MediaAssetRow> for MediaAsset {
    type Error = PetError;

    fn try_from(row: MediaAssetRow) -> Result<Self, Self::Error> {
        Ok(Self {
            id: row.id,
            uploaded_by_user_id: row.uploaded_by_user_id,
            owner_pet_id: row.owner_pet_id,
            usage_kind: MediaUsageKind::try_from(row.usage_kind.as_str()).map_err(|_| {
                PetError::Infrastructure("unknown media usage kind from database".to_owned())
            })?,
            source_client: row.source_client,
            original_file_name: row.original_file_name,
            mime_type: row.mime_type,
            byte_size: row.byte_size,
            sha256_hex: row.sha256_hex,
            bucket: row.bucket,
            object_key: row.object_key,
            status: MediaAssetStatus::try_from(row.status.as_str()).map_err(|_| {
                PetError::Infrastructure("unknown media asset status from database".to_owned())
            })?,
            delete_after: row.delete_after,
            deleted_at: row.deleted_at,
            created_at: row.created_at,
            updated_at: row.updated_at,
        })
    }
}

#[derive(Debug, FromRow)]
pub(super) struct MediaBindingRow {
    id: Uuid,
    asset_id: Uuid,
    pet_id: Uuid,
    usage_kind: String,
    status: String,
    bound_by_user_id: Option<Uuid>,
    bound_at: DateTime<Utc>,
    replaced_at: Option<DateTime<Utc>>,
    created_at: DateTime<Utc>,
}

impl TryFrom<MediaBindingRow> for MediaBinding {
    type Error = PetError;

    fn try_from(row: MediaBindingRow) -> Result<Self, Self::Error> {
        Ok(Self {
            id: row.id,
            asset_id: row.asset_id,
            pet_id: row.pet_id,
            usage_kind: MediaUsageKind::try_from(row.usage_kind.as_str()).map_err(|_| {
                PetError::Infrastructure("unknown media usage kind from database".to_owned())
            })?,
            status: MediaBindingStatus::try_from(row.status.as_str()).map_err(|_| {
                PetError::Infrastructure("unknown media binding status from database".to_owned())
            })?,
            bound_by_user_id: row.bound_by_user_id,
            bound_at: row.bound_at,
            replaced_at: row.replaced_at,
            created_at: row.created_at,
        })
    }
}

#[derive(Debug, FromRow)]
pub(super) struct MediaDerivativeRow {
    id: Uuid,
    parent_asset_id: Uuid,
    derivative_kind: String,
    bucket: String,
    object_key: String,
    mime_type: String,
    byte_size: i64,
    sha256_hex: String,
    metadata: Value,
    created_at: DateTime<Utc>,
}

impl TryFrom<MediaDerivativeRow> for MediaDerivative {
    type Error = PetError;

    fn try_from(row: MediaDerivativeRow) -> Result<Self, Self::Error> {
        Ok(Self {
            id: row.id,
            parent_asset_id: row.parent_asset_id,
            derivative_kind: MediaDerivativeKind::try_from(row.derivative_kind.as_str()).map_err(
                |_| {
                    PetError::Infrastructure(
                        "unknown media derivative kind from database".to_owned(),
                    )
                },
            )?,
            bucket: row.bucket,
            object_key: row.object_key,
            mime_type: row.mime_type,
            byte_size: row.byte_size,
            sha256_hex: row.sha256_hex,
            metadata: row.metadata,
            created_at: row.created_at,
        })
    }
}

#[derive(Debug, FromRow)]
pub(super) struct PetEventRow {
    id: Uuid,
    pet_id: Option<Uuid>,
    litter_id: Option<Uuid>,
    event_kind: String,
    event_subkind: Option<String>,
    title: String,
    summary: Option<String>,
    visibility: String,
    event_payload: Value,
    occurred_at: DateTime<Utc>,
    actor_user_id: Option<Uuid>,
    evidence_snapshot_id: Option<Uuid>,
    record_revision: i32,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
}

impl TryFrom<PetEventRow> for PetEvent {
    type Error = PetError;

    fn try_from(row: PetEventRow) -> Result<Self, Self::Error> {
        Ok(Self {
            id: row.id,
            pet_id: row.pet_id,
            litter_id: row.litter_id,
            event_kind: EventKind::try_from(row.event_kind.as_str()).map_err(|_| {
                PetError::Infrastructure("unknown event kind from database".to_owned())
            })?,
            event_subkind: row.event_subkind,
            title: row.title,
            summary: row.summary,
            visibility: EventVisibility::try_from(row.visibility.as_str()).map_err(|_| {
                PetError::Infrastructure("unknown visibility from database".to_owned())
            })?,
            event_payload: row.event_payload,
            occurred_at: row.occurred_at,
            actor_user_id: row.actor_user_id,
            evidence_snapshot_id: row.evidence_snapshot_id,
            record_revision: row.record_revision,
            created_at: row.created_at,
            updated_at: row.updated_at,
        })
    }
}
