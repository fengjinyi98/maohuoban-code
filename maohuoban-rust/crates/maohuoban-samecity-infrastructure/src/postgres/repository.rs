use async_trait::async_trait;
use chrono::{DateTime, Utc};
use maohuoban_samecity_application::samecity::{
    BookHospitalAppointmentInput, SameCityRepository,
};
use maohuoban_samecity_domain::samecity::{
    Hospital, HospitalAppointment, HospitalAppointmentStatus, SameCityError, SameCityResult,
    VerificationStatus,
};
use sqlx::{FromRow, PgPool};
use uuid::Uuid;

/// PostgresSameCityRepository PostgreSQL 同城仓储
/// 核心职责：
/// - 查询已认证同城医院实体
/// - 写入用户医院预约并校验宠物归属
#[derive(Debug, Clone)]
pub struct PostgresSameCityRepository {
    pool: PgPool,
}

impl PostgresSameCityRepository {
    #[must_use]
    pub const fn new(pool: PgPool) -> Self {
        Self { pool }
    }
}

#[async_trait]
impl SameCityRepository for PostgresSameCityRepository {
    async fn list_verified_hospitals(&self, city: &str) -> SameCityResult<Vec<Hospital>> {
        let rows = sqlx::query_as::<_, HospitalRow>(
            r#"
            SELECT
                id,
                name,
                city,
                district,
                address,
                phone,
                service_tags,
                verification_status,
                created_at,
                updated_at
            FROM samecity_hospitals
            WHERE city = $1 AND verification_status = 'verified'
            ORDER BY name ASC
            "#,
        )
        .bind(city)
        .fetch_all(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        rows.into_iter().map(TryInto::try_into).collect()
    }

    async fn create_hospital_appointment(
        &self,
        input: BookHospitalAppointmentInput,
    ) -> SameCityResult<HospitalAppointment> {
        ensure_verified_hospital(&self.pool, input.hospital_id).await?;
        if let Some(pet_id) = input.pet_id {
            ensure_pet_belongs_to_owner(&self.pool, pet_id, input.owner_user_id).await?;
        }

        let row = sqlx::query_as::<_, HospitalAppointmentRow>(
            r#"
            INSERT INTO samecity_hospital_appointments (
                id,
                owner_user_id,
                pet_id,
                hospital_id,
                scheduled_at,
                reason,
                note,
                status
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, 'pending')
            RETURNING
                id,
                owner_user_id,
                pet_id,
                hospital_id,
                scheduled_at,
                reason,
                note,
                status,
                created_at,
                updated_at
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(input.owner_user_id)
        .bind(input.pet_id)
        .bind(input.hospital_id)
        .bind(input.scheduled_at)
        .bind(input.reason.trim())
        .bind(input.note.as_deref().map(str::trim).filter(|value| !value.is_empty()))
        .fetch_one(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        row.try_into()
    }
}

/// ensure_verified_hospital 校验医院可预约
/// 核心职责：
/// - 确认医院实体存在
/// - 限定首页预约只进入已认证医院
async fn ensure_verified_hospital(pool: &PgPool, hospital_id: Uuid) -> SameCityResult<()> {
    let exists = sqlx::query_scalar::<_, bool>(
        r#"
        SELECT EXISTS (
            SELECT 1
            FROM samecity_hospitals
            WHERE id = $1 AND verification_status = 'verified'
        )
        "#,
    )
    .bind(hospital_id)
    .fetch_one(pool)
    .await
    .map_err(to_infrastructure_error)?;

    if exists {
        Ok(())
    } else {
        Err(SameCityError::HospitalNotFound)
    }
}

/// ensure_pet_belongs_to_owner 校验宠物归属
/// 核心职责：
/// - 确认首页传入的宠物属于当前用户
/// - 防止跨用户创建医疗预约
async fn ensure_pet_belongs_to_owner(
    pool: &PgPool,
    pet_id: Uuid,
    owner_user_id: Uuid,
) -> SameCityResult<()> {
    let exists = sqlx::query_scalar::<_, bool>(
        r#"
        SELECT EXISTS (
            SELECT 1
            FROM pet_profiles
            WHERE id = $1 AND owner_user_id = $2
        )
        "#,
    )
    .bind(pet_id)
    .bind(owner_user_id)
    .fetch_one(pool)
    .await
    .map_err(to_infrastructure_error)?;

    if exists {
        Ok(())
    } else {
        Err(SameCityError::PetForbidden)
    }
}

#[derive(Debug, FromRow)]
struct HospitalRow {
    id: Uuid,
    name: String,
    city: String,
    district: Option<String>,
    address: String,
    phone: Option<String>,
    service_tags: Vec<String>,
    verification_status: String,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
}

impl TryFrom<HospitalRow> for Hospital {
    type Error = SameCityError;

    fn try_from(row: HospitalRow) -> Result<Self, Self::Error> {
        Ok(Self {
            id: row.id,
            name: row.name,
            city: row.city,
            district: row.district,
            address: row.address,
            phone: row.phone,
            service_tags: row.service_tags,
            verification_status: VerificationStatus::try_from(row.verification_status.as_str())?,
            created_at: row.created_at,
            updated_at: row.updated_at,
        })
    }
}

#[derive(Debug, FromRow)]
struct HospitalAppointmentRow {
    id: Uuid,
    owner_user_id: Uuid,
    pet_id: Option<Uuid>,
    hospital_id: Uuid,
    scheduled_at: DateTime<Utc>,
    reason: String,
    note: Option<String>,
    status: String,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
}

impl TryFrom<HospitalAppointmentRow> for HospitalAppointment {
    type Error = SameCityError;

    fn try_from(row: HospitalAppointmentRow) -> Result<Self, Self::Error> {
        Ok(Self {
            id: row.id,
            owner_user_id: row.owner_user_id,
            pet_id: row.pet_id,
            hospital_id: row.hospital_id,
            scheduled_at: row.scheduled_at,
            reason: row.reason,
            note: row.note,
            status: HospitalAppointmentStatus::try_from(row.status.as_str())?,
            created_at: row.created_at,
            updated_at: row.updated_at,
        })
    }
}

fn to_infrastructure_error(error: sqlx::Error) -> SameCityError {
    SameCityError::Infrastructure(error.to_string())
}
