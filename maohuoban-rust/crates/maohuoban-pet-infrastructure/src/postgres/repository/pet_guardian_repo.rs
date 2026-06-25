// 宠物归属关系仓储实现
// 核心职责：
// - 实现 PetRepository 的 add_guardian / list_guardians / authorize_pet_access
// - 迁移 owner-only 查询到关系访问模型

use chrono::{DateTime, Utc};
use maohuoban_pet_application::pet::AddPetGuardian;
use maohuoban_pet_domain::pet::{
    GuardianRole, GuardianStatus, GuardianType, PetError, PetGuardian, PetProfile, PetResult,
};
use sqlx::FromRow;
use uuid::Uuid;

use super::rows::PetProfileRow;
use super::storage::to_infrastructure_error;
use crate::postgres::PostgresPetRepository;

#[derive(Debug, FromRow)]
struct PetGuardianRow {
    id: Uuid,
    pet_id: Uuid,
    guardian_type: String,
    guardian_user_id: Option<Uuid>,
    guardian_merchant_id: Option<Uuid>,
    role: String,
    status: String,
    started_at: DateTime<Utc>,
    ended_at: Option<DateTime<Utc>>,
    granted_by_user_id: Option<Uuid>,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
}

impl TryFrom<PetGuardianRow> for PetGuardian {
    type Error = PetError;

    fn try_from(row: PetGuardianRow) -> Result<Self, Self::Error> {
        Ok(Self {
            id: row.id,
            pet_id: row.pet_id,
            guardian_type: GuardianType::try_from(row.guardian_type.as_str()).map_err(|_| {
                PetError::Infrastructure("unknown guardian type from database".to_owned())
            })?,
            guardian_user_id: row.guardian_user_id,
            guardian_merchant_id: row.guardian_merchant_id,
            role: GuardianRole::try_from(row.role.as_str()).map_err(|_| {
                PetError::Infrastructure("unknown guardian role from database".to_owned())
            })?,
            status: GuardianStatus::try_from(row.status.as_str()).map_err(|_| {
                PetError::Infrastructure("unknown guardian status from database".to_owned())
            })?,
            started_at: row.started_at,
            ended_at: row.ended_at,
            granted_by_user_id: row.granted_by_user_id,
            created_at: row.created_at,
            updated_at: row.updated_at,
        })
    }
}

impl PostgresPetRepository {
    /// add_guardian_command 新增归属关系
    /// 核心职责：
    /// - 写入一条新的归属关系
    pub(super) async fn add_guardian_command(
        &self,
        input: AddPetGuardian,
    ) -> PetResult<PetGuardian> {
        let row = sqlx::query_as::<_, PetGuardianRow>(
            r#"
            INSERT INTO pet_guardians (
                id,
                pet_id,
                guardian_type,
                guardian_user_id,
                guardian_merchant_id,
                role,
                status,
                started_at,
                granted_by_user_id
            )
            VALUES ($1, $2, $3, $4, $5, $6, 'active', now(), $7)
            RETURNING
                id,
                pet_id,
                guardian_type,
                guardian_user_id,
                guardian_merchant_id,
                role,
                status,
                started_at,
                ended_at,
                granted_by_user_id,
                created_at,
                updated_at
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(input.pet_id)
        .bind(input.guardian_type.as_str())
        .bind(input.guardian_user_id)
        .bind(input.guardian_merchant_id)
        .bind(input.role.as_str())
        .bind(input.granted_by_user_id)
        .fetch_one(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        row.try_into()
    }

    /// list_guardians_query 查询宠物归属关系列表
    /// 核心职责：
    /// - 返回宠物所有归属关系
    pub(super) async fn list_guardians_query(&self, pet_id: Uuid) -> PetResult<Vec<PetGuardian>> {
        let rows = sqlx::query_as::<_, PetGuardianRow>(
            r#"
            SELECT
                id,
                pet_id,
                guardian_type,
                guardian_user_id,
                guardian_merchant_id,
                role,
                status,
                started_at,
                ended_at,
                granted_by_user_id,
                created_at,
                updated_at
            FROM pet_guardians
            WHERE pet_id = $1
            ORDER BY created_at DESC
            "#,
        )
        .bind(pet_id)
        .fetch_all(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        rows.into_iter().map(TryInto::try_into).collect()
    }

    /// authorize_pet_access_query 基于关系判断用户是否有权访问宠物
    /// 核心职责：
    /// - 替代 find_pet_for_owner 的 owner-only 查询
    /// - 通过 pet_guardians 表判断访问权限
    /// - 兼容读取 pet_profiles.owner_user_id 作为兜底
    pub(super) async fn authorize_pet_access_query(
        &self,
        pet_id: Uuid,
        user_id: Uuid,
    ) -> PetResult<Option<PetProfile>> {
        let row = sqlx::query_as::<_, PetProfileRow>(
            r#"
            SELECT
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
                p.life_status,
                p.origin_kind,
                p.created_at,
                p.updated_at
            FROM pet_profiles p
            WHERE p.id = $1
              AND p.deleted_at IS NULL
              AND (
                  -- 通过 pet_guardians 关系访问
                  EXISTS (
                      SELECT 1 FROM pet_guardians g
                      WHERE g.pet_id = p.id
                        AND g.guardian_user_id = $2
                        AND g.status = 'active'
                  )
                  -- 兼容旧 owner 字段
                  OR p.owner_user_id = $2
              )
            "#,
        )
        .bind(pet_id)
        .bind(user_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        row.map(TryInto::try_into).transpose()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn guardian_row_try_from_valid_owner() {
        let row = PetGuardianRow {
            id: Uuid::new_v4(),
            pet_id: Uuid::new_v4(),
            guardian_type: "user".into(),
            guardian_user_id: Some(Uuid::new_v4()),
            guardian_merchant_id: None,
            role: "owner".into(),
            status: "active".into(),
            started_at: Utc::now(),
            ended_at: None,
            granted_by_user_id: None,
            created_at: Utc::now(),
            updated_at: Utc::now(),
        };
        let g = PetGuardian::try_from(row).unwrap();
        assert_eq!(g.guardian_type, GuardianType::User);
        assert_eq!(g.role, GuardianRole::Owner);
        assert_eq!(g.status, GuardianStatus::Active);
    }

    #[test]
    fn guardian_row_try_from_invalid_role() {
        let row = PetGuardianRow {
            id: Uuid::new_v4(),
            pet_id: Uuid::new_v4(),
            guardian_type: "user".into(),
            guardian_user_id: Some(Uuid::new_v4()),
            guardian_merchant_id: None,
            role: "invalid".into(),
            status: "active".into(),
            started_at: Utc::now(),
            ended_at: None,
            granted_by_user_id: None,
            created_at: Utc::now(),
            updated_at: Utc::now(),
        };
        assert!(PetGuardian::try_from(row).is_err());
    }
}
