use maohuoban_pet_application::pet::TradePetImportInput;
use maohuoban_pet_domain::pet::PetResult;
use sqlx::{Postgres, Transaction};
use uuid::Uuid;

use super::event_rows::PetEventRow;
use super::rows::PetProfileRow;
use super::storage::{profile_number_from_uuid, to_infrastructure_error};

/// insert_trade_import_pet 写入交易导入宠物档案
/// 核心职责：
/// - 在同一事务中创建家庭管理宠物档案
/// - 固定交易导入来源类型
pub(super) async fn insert_trade_import_pet(
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
            profile_number,
            managed_status,
            source_kind
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'family', 'trade_imported')
        RETURNING
            id,
            owner_user_id,
            merchant_id,
            name,
            species,
            breed,
            sex,
            birthday,
            profile_number,
            microchip_number,
            arrival_date,
            weight_grams,
            neuter_status,
            personality_tags,
            note,
            avatar_asset_id,
            background_asset_id,
            background_media_kind,
            deleted_at,
            delete_requested_by_user_id,
            recoverable_until,
            delete_reason,
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
    .bind(profile_number_from_uuid(pet_id))
    .fetch_one(&mut **transaction)
    .await
    .map_err(to_infrastructure_error)
}

/// insert_trade_import_event 写入交易导入事件
/// 核心职责：
/// - 在同一事务中追加私有交易事件
/// - 将来源方和交易编号作为事件载荷保留
pub(super) async fn insert_trade_import_event(
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
