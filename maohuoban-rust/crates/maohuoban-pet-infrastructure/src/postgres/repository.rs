use async_trait::async_trait;
use chrono::{DateTime, NaiveDate, Utc};
use maohuoban_pet_application::pet::{
    NewPetEvent, NewPetProfile, PetRepository, TradePetImport, TradePetImportInput,
};
use maohuoban_pet_domain::pet::{
    EventKind, EventVisibility, ManagedPetStatus, PetError, PetEvent, PetProfile, PetResult,
    PetSex, PetSourceKind, PetSpecies, PetTimeline,
};
use serde_json::Value;
use sqlx::{FromRow, PgPool, Postgres, Transaction};
use uuid::Uuid;

/// PostgresPetRepository PostgreSQL 宠物仓储
/// 核心职责：
/// - 持久化宠物档案和宠物事件账本
/// - 通过数据库索引支撑首页和详情页时间线读取
#[derive(Debug, Clone)]
pub struct PostgresPetRepository {
    pub(crate) pool: PgPool,
}

impl PostgresPetRepository {
    #[must_use]
    pub const fn new(pool: PgPool) -> Self {
        Self { pool }
    }
}

#[async_trait]
impl PetRepository for PostgresPetRepository {
    async fn create_pet_profile(&self, input: NewPetProfile) -> PetResult<PetProfile> {
        let pet_id = Uuid::new_v4();
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
                managed_status,
                source_kind
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, 'family', $8)
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
        .bind(input.owner_user_id)
        .bind(input.name)
        .bind(input.species.as_str())
        .bind(input.breed)
        .bind(input.sex.as_str())
        .bind(input.birthday)
        .bind(input.source_kind.as_str())
        .fetch_one(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        row.try_into()
    }

    async fn find_pet_for_owner(
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
                managed_status,
                source_kind,
                created_at,
                updated_at
            FROM pet_profiles
            WHERE id = $1 AND owner_user_id = $2
            "#,
        )
        .bind(pet_id)
        .bind(owner_user_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        row.map(TryInto::try_into).transpose()
    }

    async fn list_pet_profiles_for_owner(&self, owner_user_id: Uuid) -> PetResult<Vec<PetProfile>> {
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
                managed_status,
                source_kind,
                created_at,
                updated_at
            FROM pet_profiles
            WHERE owner_user_id = $1
            ORDER BY created_at ASC
            "#,
        )
        .bind(owner_user_id)
        .fetch_all(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        rows.into_iter().map(TryInto::try_into).collect()
    }

    async fn create_pet_event(&self, input: NewPetEvent) -> PetResult<PetEvent> {
        let event_id = Uuid::new_v4();
        let row = sqlx::query_as::<_, PetEventRow>(
            r#"
            INSERT INTO pet_events (
                id,
                pet_id,
                event_kind,
                event_subkind,
                title,
                summary,
                visibility,
                event_payload,
                occurred_at,
                actor_user_id,
                record_revision
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 1)
            RETURNING
                id,
                pet_id,
                litter_id,
                event_kind,
                event_subkind,
                title,
                summary,
                visibility,
                event_payload,
                occurred_at,
                actor_user_id,
                evidence_snapshot_id,
                record_revision,
                created_at,
                updated_at
            "#,
        )
        .bind(event_id)
        .bind(input.pet_id)
        .bind(input.event_kind.as_str())
        .bind(input.event_subkind)
        .bind(input.title)
        .bind(input.summary)
        .bind(input.visibility.as_str())
        .bind(input.event_payload)
        .bind(input.occurred_at)
        .bind(input.actor_user_id)
        .fetch_one(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        row.try_into()
    }

    async fn import_trade_pet(&self, input: TradePetImportInput) -> PetResult<TradePetImport> {
        let mut transaction = self.pool.begin().await.map_err(to_infrastructure_error)?;
        let pet_id = Uuid::new_v4();
        let pet_row = insert_trade_import_pet(&mut transaction, pet_id, &input).await?;
        let event_row = insert_trade_import_event(&mut transaction, pet_id, &input).await?;

        transaction
            .commit()
            .await
            .map_err(to_infrastructure_error)?;

        Ok(TradePetImport {
            pet: pet_row.try_into()?,
            event: event_row.try_into()?,
        })
    }

    async fn load_pet_timeline(
        &self,
        owner_user_id: Uuid,
        pet_id: Uuid,
        limit: i64,
    ) -> PetResult<PetTimeline> {
        let rows = sqlx::query_as::<_, PetEventRow>(
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
            INNER JOIN pet_profiles p ON p.id = e.pet_id
            WHERE e.pet_id = $1 AND p.owner_user_id = $2
            ORDER BY e.occurred_at DESC, e.created_at DESC
            LIMIT $3
            "#,
        )
        .bind(pet_id)
        .bind(owner_user_id)
        .bind(limit)
        .fetch_all(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        let events = rows
            .into_iter()
            .map(TryInto::try_into)
            .collect::<PetResult<Vec<_>>>()?;
        Ok(PetTimeline { pet_id, events })
    }

    async fn load_pet_event_detail(
        &self,
        owner_user_id: Uuid,
        event_id: Uuid,
    ) -> PetResult<Option<PetEvent>> {
        let row = sqlx::query_as::<_, PetEventRow>(
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
            LEFT JOIN merchant_profiles merchant
                ON merchant.id = COALESCE(p.merchant_id, l.merchant_id)
            WHERE e.id = $1
                AND (
                    p.owner_user_id = $2
                    OR e.actor_user_id = $2
                    OR (
                        merchant.owner_user_id = $2
                        AND merchant.verification_status = 'verified'
                    )
                )
            "#,
        )
        .bind(event_id)
        .bind(owner_user_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        row.map(TryInto::try_into).transpose()
    }
}

/// insert_trade_import_pet 写入交易导入宠物档案
/// 核心职责：
/// - 在同一事务中创建家庭管理宠物档案
/// - 固定交易导入来源类型
async fn insert_trade_import_pet(
    transaction: &mut Transaction<'_, Postgres>,
    pet_id: Uuid,
    input: &TradePetImportInput,
) -> PetResult<PetProfileRow> {
    sqlx::query_as::<_, PetProfileRow>(
        r#"
        INSERT INTO pet_profiles (
            id,
            owner_user_id,
            name,
            species,
            breed,
            sex,
            birthday,
            managed_status,
            source_kind
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, 'family', 'trade_imported')
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
    .bind(input.owner_user_id)
    .bind(&input.name)
    .bind(input.species.as_str())
    .bind(input.breed.as_deref())
    .bind(input.sex.as_str())
    .bind(input.birthday)
    .fetch_one(&mut **transaction)
    .await
    .map_err(to_infrastructure_error)
}

/// insert_trade_import_event 写入交易导入事件
/// 核心职责：
/// - 在同一事务中追加私有交易事件
/// - 将来源方和交易编号作为事件载荷保留
async fn insert_trade_import_event(
    transaction: &mut Transaction<'_, Postgres>,
    pet_id: Uuid,
    input: &TradePetImportInput,
) -> PetResult<PetEventRow> {
    sqlx::query_as::<_, PetEventRow>(
        r#"
        INSERT INTO pet_events (
            id,
            pet_id,
            event_kind,
            event_subkind,
            title,
            summary,
            visibility,
            event_payload,
            occurred_at,
            actor_user_id,
            record_revision
        )
        VALUES (
            $1,
            $2,
            'trade',
            'trade_imported',
            '交易宠物导入',
            $3,
            'private',
            $4,
            $5,
            $6,
            1
        )
        RETURNING
            id,
            pet_id,
            litter_id,
            event_kind,
            event_subkind,
            title,
            summary,
            visibility,
            event_payload,
            occurred_at,
            actor_user_id,
            evidence_snapshot_id,
            record_revision,
            created_at,
            updated_at
        "#,
    )
    .bind(Uuid::new_v4())
    .bind(pet_id)
    .bind(input.summary.as_deref())
    .bind(serde_json::json!({
        "seller_name": input.seller_name,
        "trade_reference": input.trade_reference
    }))
    .bind(input.occurred_at)
    .bind(input.owner_user_id)
    .fetch_one(&mut **transaction)
    .await
    .map_err(to_infrastructure_error)
}

#[derive(Debug, FromRow)]
struct PetProfileRow {
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
struct PetEventRow {
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

fn to_infrastructure_error(error: sqlx::Error) -> PetError {
    PetError::Infrastructure(error.to_string())
}
