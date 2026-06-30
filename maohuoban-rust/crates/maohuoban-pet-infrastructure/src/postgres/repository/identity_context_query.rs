// Agent 身份上下文读模型查询
// 核心职责：
// - 聚合同一 pet_id 的身份、关系、外部标识、生命周期摘要
// - 只输出可解释字段，不暴露底层兼容字段

use chrono::{NaiveDate, Utc};
use maohuoban_pet_domain::pet::{
    ExternalIdentifierSummary, GuardianSummary, IdentitySummary, LifecycleSummary, OriginSummary,
    PetError, PetIdentityContext, PetResult, days_since_date,
};
use sqlx::FromRow;
use uuid::Uuid;

use super::storage::to_infrastructure_error;
use crate::postgres::PostgresPetRepository;

#[derive(Debug, FromRow)]
struct IdentityRow {
    id: Uuid,
    profile_number: String,
    name: String,
    species: String,
    breed: Option<String>,
    sex: String,
    birthday: Option<NaiveDate>,
    arrival_date: Option<NaiveDate>,
    life_status: String,
    origin_kind: String,
    created_at: chrono::DateTime<chrono::Utc>,
}

impl PostgresPetRepository {
    /// load_identity_context_query 加载 Agent 身份事实包
    /// 核心职责：
    /// - 聚合 pet_profiles + pet_guardians + pet_external_identifiers + pet_lifecycle_events
    /// - 通过 authorize_pet_access 校验用户有权访问该宠物
    /// - 只输出可解释字段
    pub(super) async fn load_identity_context_query(
        &self,
        pet_id: Uuid,
        user_id: Uuid,
    ) -> PetResult<PetIdentityContext> {
        // 0. 授权校验
        let _authorized = self
            .authorize_pet_access_query(pet_id, user_id)
            .await?
            .ok_or(PetError::Forbidden)?;

        // 1. 身份 + 来源
        let identity_row = sqlx::query_as::<_, IdentityRow>(
            r#"
            SELECT
                id,
                profile_number,
                name,
                species,
                breed,
                sex,
                birthday,
                arrival_date,
                life_status,
                origin_kind,
                created_at
            FROM pet_profiles
            WHERE id = $1 AND deleted_at IS NULL
            "#,
        )
        .bind(pet_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(to_infrastructure_error)?
        .ok_or(PetError::PetNotFound)?;

        let today = Utc::now().date_naive();
        let birthday = identity_row.birthday;
        let arrival_date = identity_row.arrival_date;
        let identity = IdentitySummary {
            pet_id: identity_row.id,
            profile_number: identity_row.profile_number,
            name: identity_row.name,
            species: identity_row.species,
            breed: identity_row.breed,
            sex: identity_row.sex,
            birthday: birthday.map(|date| date.to_string()),
            arrival_date: arrival_date.map(|date| date.to_string()),
            world_days: birthday.map(|date| days_since_date(date, today)),
            companionship_days: arrival_date.map(|date| days_since_date(date, today)),
            life_status: identity_row.life_status,
        };

        let origin = OriginSummary {
            origin_kind: identity_row.origin_kind,
            created_at: identity_row.created_at,
        };

        // 2. 当前 active 归属关系
        let guardians = self.load_identity_guardians(pet_id).await?;

        // 3. 外部标识
        let external_ids = self.load_identity_external_ids(pet_id).await?;

        // 4. 生命周期事件
        let lifecycle = self.load_identity_lifecycle(pet_id).await?;

        Ok(PetIdentityContext {
            identity,
            origin,
            current_guardians: guardians,
            external_identifiers: external_ids,
            lifecycle,
        })
    }

    async fn load_identity_guardians(&self, pet_id: Uuid) -> PetResult<Vec<GuardianSummary>> {
        #[derive(Debug, FromRow)]
        struct Row {
            id: Uuid,
            guardian_type: String,
            guardian_user_id: Option<Uuid>,
            guardian_merchant_id: Option<Uuid>,
            role: String,
            status: String,
        }

        let rows = sqlx::query_as::<_, Row>(
            r#"
            SELECT id, guardian_type, guardian_user_id, guardian_merchant_id, role, status
            FROM pet_guardians
            WHERE pet_id = $1 AND status = 'active'
            "#,
        )
        .bind(pet_id)
        .fetch_all(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        Ok(rows
            .into_iter()
            .map(|r| GuardianSummary {
                guardian_id: r.id,
                guardian_type: r.guardian_type,
                guardian_user_id: r.guardian_user_id,
                guardian_merchant_id: r.guardian_merchant_id,
                role: r.role,
                status: r.status,
            })
            .collect())
    }

    async fn load_identity_external_ids(
        &self,
        pet_id: Uuid,
    ) -> PetResult<Vec<ExternalIdentifierSummary>> {
        #[derive(Debug, FromRow)]
        struct Row {
            identifier_type: String,
            identifier_value: String,
            verified_status: String,
            status: String,
        }

        let rows = sqlx::query_as::<_, Row>(
            r#"
            SELECT identifier_type, identifier_value, verified_status, status
            FROM pet_external_identifiers
            WHERE pet_id = $1 AND status IN ('active', 'disputed')
            ORDER BY
                CASE status WHEN 'active' THEN 0 WHEN 'disputed' THEN 1 ELSE 2 END,
                created_at DESC
            "#,
        )
        .bind(pet_id)
        .fetch_all(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        Ok(rows
            .into_iter()
            .map(|r| ExternalIdentifierSummary {
                identifier_type: r.identifier_type,
                identifier_value: r.identifier_value,
                verified_status: r.verified_status,
                status: r.status,
            })
            .collect())
    }

    async fn load_identity_lifecycle(&self, pet_id: Uuid) -> PetResult<Vec<LifecycleSummary>> {
        #[derive(Debug, FromRow)]
        struct Row {
            id: Uuid,
            event_kind: String,
            occurred_at: chrono::DateTime<chrono::Utc>,
            note: Option<String>,
        }

        let rows = sqlx::query_as::<_, Row>(
            r#"
            SELECT id, event_kind, occurred_at, note
            FROM pet_lifecycle_events
            WHERE pet_id = $1
            ORDER BY occurred_at DESC
            LIMIT 20
            "#,
        )
        .bind(pet_id)
        .fetch_all(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        Ok(rows
            .into_iter()
            .map(|r| LifecycleSummary {
                id: r.id,
                event_kind: r.event_kind,
                occurred_at: r.occurred_at,
                note: r.note,
            })
            .collect())
    }
}
