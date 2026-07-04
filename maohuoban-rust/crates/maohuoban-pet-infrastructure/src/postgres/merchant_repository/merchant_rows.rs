use chrono::{DateTime, NaiveDate, Utc};
use maohuoban_pet_application::pet::MerchantLitterSummary;
use maohuoban_pet_domain::pet::{
    EventKind, EventVisibility, Litter, LitterStatus, ManagedPetStatus, MerchantProfile,
    MerchantStatusCount, MerchantType, MerchantVerificationStatus, PetError, PetEvent,
    PetRelationship, PetRelationshipKind, PetRelationshipSourceKind, PetSpecies,
};
use serde_json::Value;
use sqlx::FromRow;
use uuid::Uuid;

#[derive(Debug, FromRow)]
pub(super) struct MerchantProfileRow {
    id: Uuid,
    owner_user_id: Uuid,
    merchant_type: String,
    name: String,
    city: Option<String>,
    verification_status: String,
    verified_at: Option<DateTime<Utc>>,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
}

impl TryFrom<MerchantProfileRow> for MerchantProfile {
    type Error = PetError;

    fn try_from(row: MerchantProfileRow) -> Result<Self, Self::Error> {
        Ok(Self {
            id: row.id,
            owner_user_id: row.owner_user_id,
            merchant_type: MerchantType::try_from(row.merchant_type.as_str()).map_err(|_| {
                PetError::Infrastructure("unknown merchant type from database".to_owned())
            })?,
            name: row.name,
            city: row.city,
            verification_status: MerchantVerificationStatus::try_from(
                row.verification_status.as_str(),
            )
            .map_err(|_| {
                PetError::Infrastructure(
                    "unknown merchant verification status from database".to_owned(),
                )
            })?,
            verified_at: row.verified_at,
            created_at: row.created_at,
            updated_at: row.updated_at,
        })
    }
}

#[derive(Debug, FromRow)]
pub(super) struct MerchantStatusCountRow {
    status: String,
    count: i64,
}

impl TryFrom<MerchantStatusCountRow> for MerchantStatusCount {
    type Error = PetError;

    fn try_from(row: MerchantStatusCountRow) -> Result<Self, Self::Error> {
        Ok(Self {
            status: ManagedPetStatus::try_from(row.status.as_str()).map_err(|_| {
                PetError::Infrastructure("unknown managed status from database".to_owned())
            })?,
            count: u32::try_from(row.count).map_err(|_| {
                PetError::Infrastructure("merchant status count overflow".to_owned())
            })?,
        })
    }
}

#[derive(Debug, FromRow)]
pub(super) struct MerchantLitterSummaryRow {
    id: Uuid,
    name: String,
    sire_name: Option<String>,
    dam_name: Option<String>,
    born_at: NaiveDate,
    born_count: i32,
    alive_count: i32,
    available_count: i64,
}

impl From<MerchantLitterSummaryRow> for MerchantLitterSummary {
    fn from(row: MerchantLitterSummaryRow) -> Self {
        Self {
            id: row.id,
            name: row.name,
            sire_name: row.sire_name,
            dam_name: row.dam_name,
            born_at: row.born_at,
            born_count: row.born_count,
            alive_count: row.alive_count,
            available_count: u32::try_from(row.available_count).unwrap_or(0),
        }
    }
}

#[derive(Debug, FromRow)]
pub(super) struct LitterRow {
    id: Uuid,
    merchant_id: Uuid,
    name: String,
    species: String,
    sire_pet_id: Option<Uuid>,
    dam_pet_id: Option<Uuid>,
    born_at: NaiveDate,
    born_count: i32,
    alive_count: i32,
    status: String,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
}

impl TryFrom<LitterRow> for Litter {
    type Error = PetError;

    fn try_from(row: LitterRow) -> Result<Self, Self::Error> {
        Ok(Self {
            id: row.id,
            merchant_id: row.merchant_id,
            name: row.name,
            species: PetSpecies::try_from(row.species.as_str()).map_err(|_| {
                PetError::Infrastructure("unknown litter species from database".to_owned())
            })?,
            sire_pet_id: row.sire_pet_id,
            dam_pet_id: row.dam_pet_id,
            born_at: row.born_at,
            born_count: row.born_count,
            alive_count: row.alive_count,
            status: LitterStatus::try_from(row.status.as_str()).map_err(|_| {
                PetError::Infrastructure("unknown litter status from database".to_owned())
            })?,
            created_at: row.created_at,
            updated_at: row.updated_at,
        })
    }
}

#[derive(Debug, FromRow)]
pub(super) struct PetRelationshipRow {
    id: Uuid,
    subject_pet_id: Uuid,
    related_pet_id: Option<Uuid>,
    litter_id: Option<Uuid>,
    relationship_kind: String,
    source_kind: String,
    evidence_snapshot_id: Option<Uuid>,
    created_at: DateTime<Utc>,
}

impl TryFrom<PetRelationshipRow> for PetRelationship {
    type Error = PetError;

    fn try_from(row: PetRelationshipRow) -> Result<Self, Self::Error> {
        Ok(Self {
            id: row.id,
            subject_pet_id: row.subject_pet_id,
            related_pet_id: row.related_pet_id,
            litter_id: row.litter_id,
            relationship_kind: PetRelationshipKind::try_from(row.relationship_kind.as_str())
                .map_err(|_| {
                    PetError::Infrastructure("unknown relationship kind from database".to_owned())
                })?,
            source_kind: PetRelationshipSourceKind::try_from(row.source_kind.as_str()).map_err(
                |_| {
                    PetError::Infrastructure(
                        "unknown relationship source kind from database".to_owned(),
                    )
                },
            )?,
            evidence_snapshot_id: row.evidence_snapshot_id,
            created_at: row.created_at,
        })
    }
}

#[derive(Debug, FromRow)]
pub(super) struct MerchantPetEventRow {
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

impl TryFrom<MerchantPetEventRow> for PetEvent {
    type Error = PetError;

    fn try_from(row: MerchantPetEventRow) -> Result<Self, Self::Error> {
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
            attachment_assets: Vec::new(),
        })
    }
}
