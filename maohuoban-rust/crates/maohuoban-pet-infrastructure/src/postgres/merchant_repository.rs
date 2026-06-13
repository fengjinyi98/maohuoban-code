use async_trait::async_trait;
use chrono::{DateTime, NaiveDate, Utc};
use maohuoban_pet_application::pet::{
    MerchantLitterDetail, MerchantLitterSummary, MerchantRepository, NewMerchantPetProfile,
};
use maohuoban_pet_domain::pet::{
    EventKind, EventVisibility, Litter, LitterStatus, ManagedPetStatus, MerchantProfile,
    MerchantStatusCount, MerchantType, MerchantVerificationStatus, PetError, PetEvent, PetProfile,
    PetRelationship, PetRelationshipKind, PetRelationshipSourceKind, PetResult, PetSex,
    PetSourceKind, PetSpecies,
};
use serde_json::Value;
use sqlx::FromRow;
use uuid::Uuid;

use super::PostgresPetRepository;

#[async_trait]
impl MerchantRepository for PostgresPetRepository {
    async fn find_verified_merchant_for_owner(
        &self,
        owner_user_id: Uuid,
    ) -> PetResult<Option<MerchantProfile>> {
        let row = sqlx::query_as::<_, MerchantProfileRow>(
            r#"
            SELECT
                id,
                owner_user_id,
                merchant_type,
                name,
                city,
                verification_status,
                verified_at,
                created_at,
                updated_at
            FROM merchant_profiles
            WHERE owner_user_id = $1 AND verification_status = 'verified'
            ORDER BY verified_at DESC NULLS LAST, created_at ASC
            LIMIT 1
            "#,
        )
        .bind(owner_user_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        row.map(TryInto::try_into).transpose()
    }

    async fn load_merchant_status_counts(
        &self,
        merchant_id: Uuid,
    ) -> PetResult<Vec<MerchantStatusCount>> {
        let rows = sqlx::query_as::<_, MerchantStatusCountRow>(
            r#"
            SELECT
                managed_status AS status,
                COUNT(*)::bigint AS count
            FROM pet_profiles
            WHERE merchant_id = $1
                AND managed_status IN (
                    'available',
                    'reserved',
                    'sold',
                    'needs_exam',
                    'needs_record'
                )
            GROUP BY managed_status
            ORDER BY CASE managed_status
                WHEN 'available' THEN 1
                WHEN 'reserved' THEN 2
                WHEN 'sold' THEN 3
                WHEN 'needs_exam' THEN 4
                WHEN 'needs_record' THEN 5
                ELSE 99
            END
            "#,
        )
        .bind(merchant_id)
        .fetch_all(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        rows.into_iter().map(TryInto::try_into).collect()
    }

    async fn list_merchant_litter_summaries(
        &self,
        merchant_id: Uuid,
        limit: i64,
    ) -> PetResult<Vec<MerchantLitterSummary>> {
        let rows = sqlx::query_as::<_, MerchantLitterSummaryRow>(
            r#"
            SELECT
                l.id,
                l.name,
                sire.name AS sire_name,
                dam.name AS dam_name,
                l.born_at,
                l.born_count,
                l.alive_count,
                COUNT(DISTINCT child.id)
                    FILTER (WHERE child.managed_status = 'available') AS available_count
            FROM litters l
            LEFT JOIN pet_profiles sire ON sire.id = l.sire_pet_id
            LEFT JOIN pet_profiles dam ON dam.id = l.dam_pet_id
            LEFT JOIN pet_relationships rel
                ON rel.litter_id = l.id
                AND rel.relationship_kind = 'same_litter'
            LEFT JOIN pet_profiles child
                ON child.id = rel.subject_pet_id
                AND child.merchant_id = l.merchant_id
            WHERE l.merchant_id = $1
            GROUP BY
                l.id,
                l.name,
                sire.name,
                dam.name,
                l.born_at,
                l.born_count,
                l.alive_count
            ORDER BY l.born_at DESC, l.created_at DESC
            LIMIT $2
            "#,
        )
        .bind(merchant_id)
        .bind(limit)
        .fetch_all(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        Ok(rows.into_iter().map(Into::into).collect())
    }

    async fn list_merchant_relationships(
        &self,
        merchant_id: Uuid,
        limit: i64,
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
            LEFT JOIN litters l ON l.id = rel.litter_id
            WHERE subject.merchant_id = $1 OR l.merchant_id = $1
            ORDER BY rel.created_at DESC
            LIMIT $2
            "#,
        )
        .bind(merchant_id)
        .bind(limit)
        .fetch_all(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        rows.into_iter().map(TryInto::try_into).collect()
    }

    async fn load_merchant_recent_events(
        &self,
        merchant_id: Uuid,
        limit: i64,
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
            LEFT JOIN pet_profiles p ON p.id = e.pet_id
            LEFT JOIN litters l ON l.id = e.litter_id
            WHERE p.merchant_id = $1 OR l.merchant_id = $1
            ORDER BY e.occurred_at DESC, e.created_at DESC
            LIMIT $2
            "#,
        )
        .bind(merchant_id)
        .bind(limit)
        .fetch_all(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        rows.into_iter().map(TryInto::try_into).collect()
    }

    async fn list_merchant_pets(
        &self,
        merchant_id: Uuid,
        status: ManagedPetStatus,
        limit: i64,
    ) -> PetResult<Vec<PetProfile>> {
        let rows = sqlx::query_as::<_, MerchantManagedPetRow>(
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
                managed_status,
                source_kind,
                created_at,
                updated_at
            FROM pet_profiles
            WHERE merchant_id = $1 AND managed_status = $2
            ORDER BY created_at ASC, name ASC
            LIMIT $3
            "#,
        )
        .bind(merchant_id)
        .bind(status.as_str())
        .bind(limit)
        .fetch_all(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        rows.into_iter().map(TryInto::try_into).collect()
    }

    async fn create_merchant_pet(&self, input: NewMerchantPetProfile) -> PetResult<PetProfile> {
        let pet_id = Uuid::new_v4();
        let row = sqlx::query_as::<_, MerchantManagedPetRow>(
            r#"
            INSERT INTO pet_profiles (
                id,
                merchant_id,
                name,
                species,
                breed,
                sex,
                birthday,
                managed_status,
                source_kind
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
            RETURNING
                id,
                owner_user_id,
                merchant_id,
                name,
                species,
                breed,
                sex,
                birthday,
                managed_status,
                source_kind,
                created_at,
                updated_at
            "#,
        )
        .bind(pet_id)
        .bind(input.merchant_id)
        .bind(input.name)
        .bind(input.species.as_str())
        .bind(input.breed)
        .bind(input.sex.as_str())
        .bind(input.birthday)
        .bind(input.managed_status.as_str())
        .bind(input.source_kind.as_str())
        .fetch_one(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        row.try_into()
    }

    async fn load_merchant_litter_detail(
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

#[derive(Debug, FromRow)]
struct MerchantProfileRow {
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
struct MerchantStatusCountRow {
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
struct MerchantLitterSummaryRow {
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
struct LitterRow {
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
struct PetRelationshipRow {
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
struct MerchantPetEventRow {
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
        })
    }
}

#[derive(Debug, FromRow)]
struct MerchantManagedPetRow {
    id: Uuid,
    owner_user_id: Option<Uuid>,
    merchant_id: Option<Uuid>,
    name: String,
    species: String,
    breed: Option<String>,
    sex: String,
    birthday: Option<NaiveDate>,
    managed_status: String,
    source_kind: String,
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

fn to_infrastructure_error(error: sqlx::Error) -> PetError {
    PetError::Infrastructure(error.to_string())
}

async fn load_merchant_pet_by_id(
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
            managed_status,
            source_kind,
            created_at,
            updated_at
        FROM pet_profiles
        WHERE merchant_id = $1 AND id = $2
        "#,
    )
    .bind(merchant_id)
    .bind(pet_id)
    .fetch_optional(pool)
    .await
    .map_err(to_infrastructure_error)?;

    row.map(TryInto::try_into).transpose()
}

async fn list_litter_children(
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
            p.managed_status,
            p.source_kind,
            p.created_at,
            p.updated_at
        FROM pet_relationships rel
        INNER JOIN pet_profiles p ON p.id = rel.subject_pet_id
        WHERE rel.litter_id = $1 AND p.merchant_id = $2
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

async fn list_litter_relationships(
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

async fn list_litter_recent_events(
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
