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
pub(super) struct PetExternalIdentifierRow {
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

/// insert_microchip_identifier_in_transaction 写入芯片外部标识
/// 核心职责：
/// - 使用事务级 advisory lock 串行化同一芯片值写入
/// - 发现跨宠物冲突时将相关非移除标识收敛为 disputed
pub(super) async fn insert_microchip_identifier_in_transaction(
    transaction: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    pet_id: Uuid,
    microchip_number: &str,
    issuer: Option<&str>,
    issued_at: Option<DateTime<Utc>>,
) -> PetResult<PetExternalIdentifierRow> {
    lock_identifier_value(transaction, "microchip", microchip_number).await?;

    if let Some(row) = load_same_pet_identifier(transaction, pet_id, microchip_number).await? {
        return Ok(row);
    }

    let has_conflict = has_other_pet_identifier(transaction, pet_id, microchip_number).await?;
    let status = if has_conflict { "disputed" } else { "active" };
    if has_conflict {
        mark_conflicting_microchips_disputed(transaction, pet_id, microchip_number).await?;
    } else {
        ensure_no_active_microchip_for_pet(transaction, pet_id).await?;
    }

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
        VALUES ($1, $2, 'microchip', $3, $4, $5, 'self_reported', $6)
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
    .bind(pet_id)
    .bind(microchip_number)
    .bind(issuer)
    .bind(issued_at)
    .bind(status)
    .fetch_one(&mut **transaction)
    .await
    .map_err(to_infrastructure_error)?;

    Ok(row)
}

async fn lock_identifier_value(
    transaction: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    identifier_type: &str,
    identifier_value: &str,
) -> PetResult<()> {
    sqlx::query(
        r#"
        SELECT pg_advisory_xact_lock(hashtextextended($1, 0))
        "#,
    )
    .bind(format!(
        "pet_external_identifier:{identifier_type}:{identifier_value}"
    ))
    .execute(&mut **transaction)
    .await
    .map_err(to_infrastructure_error)?;
    Ok(())
}

async fn load_same_pet_identifier(
    transaction: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    pet_id: Uuid,
    microchip_number: &str,
) -> PetResult<Option<PetExternalIdentifierRow>> {
    sqlx::query_as::<_, PetExternalIdentifierRow>(
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
          AND identifier_type = 'microchip'
          AND identifier_value = $2
          AND status <> 'removed'
        ORDER BY created_at DESC
        LIMIT 1
        "#,
    )
    .bind(pet_id)
    .bind(microchip_number)
    .fetch_optional(&mut **transaction)
    .await
    .map_err(to_infrastructure_error)
}

async fn has_other_pet_identifier(
    transaction: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    pet_id: Uuid,
    microchip_number: &str,
) -> PetResult<bool> {
    sqlx::query_scalar::<_, bool>(
        r#"
        SELECT EXISTS (
            SELECT 1
            FROM pet_external_identifiers
            WHERE pet_id <> $1
              AND identifier_type = 'microchip'
              AND identifier_value = $2
              AND status IN ('active', 'disputed')
        )
        "#,
    )
    .bind(pet_id)
    .bind(microchip_number)
    .fetch_one(&mut **transaction)
    .await
    .map_err(to_infrastructure_error)
}

async fn mark_conflicting_microchips_disputed(
    transaction: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    pet_id: Uuid,
    microchip_number: &str,
) -> PetResult<()> {
    sqlx::query(
        r#"
        UPDATE pet_external_identifiers
        SET status = 'disputed', updated_at = now()
        WHERE pet_id <> $1
          AND identifier_type = 'microchip'
          AND identifier_value = $2
          AND status = 'active'
        "#,
    )
    .bind(pet_id)
    .bind(microchip_number)
    .execute(&mut **transaction)
    .await
    .map_err(to_infrastructure_error)?;
    Ok(())
}

async fn ensure_no_active_microchip_for_pet(
    transaction: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    pet_id: Uuid,
) -> PetResult<()> {
    let has_active = sqlx::query_scalar::<_, bool>(
        r#"
        SELECT EXISTS (
            SELECT 1
            FROM pet_external_identifiers
            WHERE pet_id = $1
              AND identifier_type = 'microchip'
              AND status = 'active'
        )
        "#,
    )
    .bind(pet_id)
    .fetch_one(&mut **transaction)
    .await
    .map_err(to_infrastructure_error)?;

    if has_active {
        return Err(PetError::InvalidInput(
            "芯片号已锁定，如需变更请通过申诉渠道处理".to_owned(),
        ));
    }

    Ok(())
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
        let mut transaction = self.pool.begin().await.map_err(to_infrastructure_error)?;
        let row = match input.identifier_type {
            IdentifierType::Microchip => {
                insert_microchip_identifier_in_transaction(
                    &mut transaction,
                    input.pet_id,
                    &input.identifier_value,
                    input.issuer.as_deref(),
                    input.issued_at,
                )
                .await?
            }
        };
        transaction
            .commit()
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

        // 将旧标识标记为 replaced，校验实际更新行数
        let update_result = sqlx::query(
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

        if update_result.rows_affected() == 0 {
            return Err(PetError::InvalidInput(
                "未找到活跃的外部标识或标识不属于该宠物".into(),
            ));
        }

        // 新增替换标识
        let row = insert_microchip_identifier_in_transaction(
            &mut transaction,
            input.pet_id,
            &input.new_identifier_value,
            input.issuer.as_deref(),
            input.issued_at,
        )
        .await?;

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
