use std::collections::BTreeSet;

use maohuoban_pet_domain::pet::{PetError, PetResult};
use serde_json::Value;
use sqlx::{Postgres, Transaction};
use uuid::Uuid;

use super::PostgresPetRepository;
use super::storage::to_infrastructure_error;

impl PostgresPetRepository {
    /// bind_event_attachment_assets_in_transaction 绑定事件附件资产
    /// 核心职责：
    /// - 校验附件资产属于当前用户且用途为事件附件
    /// - 将附件资产绑定到当前宠物，避免 pending 媒体游离
    pub(super) async fn bind_event_attachment_assets_in_transaction(
        transaction: &mut Transaction<'_, Postgres>,
        pet_id: Uuid,
        actor_user_id: Uuid,
        event_payload: &Value,
    ) -> PetResult<()> {
        let asset_ids = event_attachment_asset_ids(event_payload)?;
        if asset_ids.is_empty() {
            return Ok(());
        }

        let updated_asset_ids = sqlx::query_scalar::<_, Uuid>(
            r#"
            UPDATE media_assets
            SET owner_pet_id = $2, status = 'bound', updated_at = now()
            WHERE id = ANY($1)
              AND uploaded_by_user_id = $3
              AND usage_kind = 'pet.event.attachment'
              AND status = 'uploaded'
              AND deleted_at IS NULL
            RETURNING id
            "#,
        )
        .bind(&asset_ids)
        .bind(pet_id)
        .bind(actor_user_id)
        .fetch_all(&mut **transaction)
        .await
        .map_err(to_infrastructure_error)?;

        if updated_asset_ids.len() == asset_ids.len() {
            return Ok(());
        }

        let accessible_asset_ids = sqlx::query_scalar::<_, Uuid>(
            r#"
            SELECT id
            FROM media_assets
            WHERE id = ANY($1)
              AND uploaded_by_user_id = $3
              AND owner_pet_id = $2
              AND usage_kind = 'pet.event.attachment'
              AND status = 'bound'
              AND deleted_at IS NULL
            "#,
        )
        .bind(&asset_ids)
        .bind(pet_id)
        .bind(actor_user_id)
        .fetch_all(&mut **transaction)
        .await
        .map_err(to_infrastructure_error)?;

        if accessible_asset_ids.len() == asset_ids.len() {
            return Ok(());
        }

        Err(PetError::PetNotFound)
    }
}

/// event_attachment_asset_ids 解析事件附件资产 ID
/// 核心职责：
/// - 从 event_payload.attachment_asset_ids 读取 UUID 列表
/// - 对重复 ID 去重，保持绑定命令幂等
pub(super) fn event_attachment_asset_ids(event_payload: &Value) -> PetResult<Vec<Uuid>> {
    let Some(raw_value) = event_payload.get("attachment_asset_ids") else {
        return Ok(Vec::new());
    };
    if raw_value.is_null() {
        return Ok(Vec::new());
    }
    let Some(values) = raw_value.as_array() else {
        return Err(PetError::InvalidInput(
            "事件附件资产 ID 必须是数组".to_owned(),
        ));
    };

    let mut asset_ids = BTreeSet::new();
    for value in values {
        let Some(raw_id) = value.as_str() else {
            return Err(PetError::InvalidInput(
                "事件附件资产 ID 必须是字符串".to_owned(),
            ));
        };
        let asset_id = Uuid::parse_str(raw_id)
            .map_err(|_| PetError::InvalidInput("事件附件资产 ID 无效".to_owned()))?;
        asset_ids.insert(asset_id);
    }

    Ok(asset_ids.into_iter().collect())
}
