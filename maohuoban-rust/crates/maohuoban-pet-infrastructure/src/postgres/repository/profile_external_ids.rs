// 外部标识仓储命令
// 核心职责：
// - 实现 PetRepository 的 add_external_identifier / replace_external_identifier / list_external_identifiers
// - 将芯片号迁移到外部标识表

use chrono::{DateTime, Utc};
use maohuoban_pet_application::pet::{AddPetExternalIdentifier, ReplacePetExternalIdentifier};
use maohuoban_pet_domain::pet::{
    IdentifierStatus, IdentifierType, PetError, PetExternalIdentifier, PetResult, VerifiedStatus,
};
use sqlx::FromRow;
use uuid::Uuid;

use super::storage::to_infrastructure_error;
use crate::postgres::PostgresPetRepository;

#[derive(Debug, FromRow)]
struct PetExternalIdentifierRow {
    id: Uuid,
    pet_id: Uuid,
    identifier_type: String,
    identifier_value: String,
    issuer: Option<String>,
    issued_at: Option<DateTime<Utc>>,
    verified_status: String,
    status: String,
    evidence_asset_id: Option<Uuid>,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
}

impl TryFrom<PetExternalIdentifierRow> for PetExternalIdentifier {
    type Error = PetError;

    fn try_from(row: PetExternalIdentifierRow) -> Result<Self, Self::Error> {
        Ok(Self {
            id: row.id,
            pet_id: row.pet_id,
            identifier_type: IdentifierType::try_from(row.identifier_type.as_str()).map_err(
                |_| PetError::Infrastructure("unknown identifier type from database".to_owned()),
            )?,
            identifier_value: row.identifier_value,
            issuer: row.issuer,
            issued_at: row.issued_at,
            verified_status: VerifiedStatus::try_from(row.verified_status.as_str()).map_err(
                |_| PetError::Infrastructure("unknown verified status from database".to_owned()),
            )?,
            status: IdentifierStatus::try_from(row.status.as_str()).map_err(|_| {
                PetError::Infrastructure("unknown identifier status from database".to_owned())
            })?,
            evidence_asset_id: row.evidence_asset_id,
            created_at: row.created_at,
            updated_at: row.updated_at,
        })
    }
}

impl PostgresPetRepository {
    /// add_external_identifier_command 新增外部标识
    /// 核心职责：
    /// - 写入一条新的外部标识记录
    /// - 默认状态 active + self_reported
    pub(super) async fn add_external_identifier_command(
        &self,
        input: AddPetExternalIdentifier,
    ) -> PetResult<PetExternalIdentifier> {
        let row = sqlx::query_as::<_, PetExternalIdentifierRow>(
            r#"
            INSERT INTO pet_external_identifiers (
                id,
                pet_id,
                identifier_type,
                identifier_value,
                issuer,
                issued_at,
                verified_status,
                status
            )
            VALUES ($1, $2, $3, $4, $5, $6, 'self_reported', 'active')
            RETURNING
                id,
                pet_id,
                identifier_type,
                identifier_value,
                issuer,
                issued_at,
                verified_status,
                status,
                evidence_asset_id,
                created_at,
                updated_at
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(input.pet_id)
        .bind(input.identifier_type.as_str())
        .bind(&input.identifier_value)
        .bind(&input.issuer)
        .bind(input.issued_at)
        .fetch_one(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        row.try_into()
    }

    /// replace_external_identifier_command 替换外部标识
    /// 核心职责：
    /// - 将旧标识标记为 replaced
    /// - 新增一条 active 标识
    pub(super) async fn replace_external_identifier_command(
        &self,
        input: ReplacePetExternalIdentifier,
    ) -> PetResult<PetExternalIdentifier> {
        let mut transaction = self.pool.begin().await.map_err(to_infrastructure_error)?;

        // 将旧标识标记为 replaced
        sqlx::query(
            r#"
            UPDATE pet_external_identifiers
            SET status = 'replaced', updated_at = now()
            WHERE id = $1 AND pet_id = $2 AND status = 'active'
            "#,
        )
        .bind(input.old_identifier_id)
        .bind(input.pet_id)
        .execute(&mut *transaction)
        .await
        .map_err(to_infrastructure_error)?;

        // 新增替换标识
        let row = sqlx::query_as::<_, PetExternalIdentifierRow>(
            r#"
            INSERT INTO pet_external_identifiers (
                id,
                pet_id,
                identifier_type,
                identifier_value,
                issuer,
                issued_at,
                verified_status,
                status
            )
            SELECT
                $1, $2, identifier_type, $3, $4, $5, 'self_reported', 'active'
            FROM pet_external_identifiers
            WHERE id = $6 AND pet_id = $7
            RETURNING
                id,
                pet_id,
                identifier_type,
                identifier_value,
                issuer,
                issued_at,
                verified_status,
                status,
                evidence_asset_id,
                created_at,
                updated_at
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(input.pet_id)
        .bind(&input.new_identifier_value)
        .bind(&input.issuer)
        .bind(input.issued_at)
        .bind(input.old_identifier_id)
        .bind(input.pet_id)
        .fetch_one(&mut *transaction)
        .await
        .map_err(to_infrastructure_error)?;

        transaction
            .commit()
            .await
            .map_err(to_infrastructure_error)?;

        row.try_into()
    }

    /// list_external_identifiers_query 查询宠物外部标识列表
    /// 核心职责：
    /// - 返回宠物所有外部标识（不作过滤）
    /// - 含历史状态记录
    pub(super) async fn list_external_identifiers_query(
        &self,
        pet_id: Uuid,
    ) -> PetResult<Vec<PetExternalIdentifier>> {
        let rows = sqlx::query_as::<_, PetExternalIdentifierRow>(
            r#"
            SELECT
                id,
                pet_id,
                identifier_type,
                identifier_value,
                issuer,
                issued_at,
                verified_status,
                status,
                evidence_asset_id,
                created_at,
                updated_at
            FROM pet_external_identifiers
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
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn external_identifier_row_try_from_valid() {
        let row = PetExternalIdentifierRow {
            id: Uuid::new_v4(),
            pet_id: Uuid::new_v4(),
            identifier_type: "microchip".into(),
            identifier_value: "900000000000001".into(),
            issuer: None,
            issued_at: None,
            verified_status: "self_reported".into(),
            status: "active".into(),
            evidence_asset_id: None,
            created_at: Utc::now(),
            updated_at: Utc::now(),
        };
        let ident = PetExternalIdentifier::try_from(row).unwrap();
        assert_eq!(ident.identifier_type, IdentifierType::Microchip);
        assert_eq!(ident.verified_status, VerifiedStatus::SelfReported);
        assert_eq!(ident.status, IdentifierStatus::Active);
    }

    #[test]
    fn external_identifier_row_try_from_invalid_type() {
        let row = PetExternalIdentifierRow {
            id: Uuid::new_v4(),
            pet_id: Uuid::new_v4(),
            identifier_type: "invalid".into(),
            identifier_value: "test".into(),
            issuer: None,
            issued_at: None,
            verified_status: "unverified".into(),
            status: "active".into(),
            evidence_asset_id: None,
            created_at: Utc::now(),
            updated_at: Utc::now(),
        };
        assert!(PetExternalIdentifier::try_from(row).is_err());
    }
}
