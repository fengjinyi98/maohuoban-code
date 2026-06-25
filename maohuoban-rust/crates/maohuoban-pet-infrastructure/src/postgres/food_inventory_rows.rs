use chrono::{DateTime, NaiveDate, Utc};
use maohuoban_pet_domain::pet::{
    FoodInventoryCategory, FoodInventoryItem, FoodInventoryStatus, FoodScopeType, FoodSourceKind,
    PetError,
};
use sqlx::FromRow;
use uuid::Uuid;

/// FoodInventoryItemRow 食品资产数据库行
/// 核心职责：
/// - 映射 food_inventory_items 表
/// - 转换数据库文本字段到领域枚举
#[derive(Debug, FromRow)]
pub(super) struct FoodInventoryItemRow {
    id: Uuid,
    scope_type: String,
    scope_id: Uuid,
    created_by_user_id: Uuid,
    name: String,
    brand: Option<String>,
    category: String,
    inventory_status: String,
    quantity: i32,
    unit: Option<String>,
    spec: Option<String>,
    expiry_date: Option<NaiveDate>,
    cover_asset_id: Option<Uuid>,
    barcode: Option<String>,
    source_kind: String,
    note: Option<String>,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
    archived_at: Option<DateTime<Utc>>,
}

impl TryFrom<FoodInventoryItemRow> for FoodInventoryItem {
    type Error = PetError;

    fn try_from(row: FoodInventoryItemRow) -> Result<Self, Self::Error> {
        Ok(Self {
            id: row.id,
            scope_type: FoodScopeType::try_from(row.scope_type.as_str()).map_err(|_| {
                PetError::Infrastructure("unknown scope_type from database".to_owned())
            })?,
            scope_id: row.scope_id,
            created_by_user_id: row.created_by_user_id,
            name: row.name,
            brand: row.brand,
            category: FoodInventoryCategory::try_from(row.category.as_str()).map_err(|_| {
                PetError::Infrastructure("unknown category from database".to_owned())
            })?,
            inventory_status: FoodInventoryStatus::try_from(row.inventory_status.as_str())
                .map_err(|_| {
                    PetError::Infrastructure("unknown inventory_status from database".to_owned())
                })?,
            quantity: row.quantity,
            unit: row.unit,
            spec: row.spec,
            expiry_date: row.expiry_date,
            cover_asset_id: row.cover_asset_id,
            barcode: row.barcode,
            source_kind: FoodSourceKind::try_from(row.source_kind.as_str()).map_err(|_| {
                PetError::Infrastructure("unknown source_kind from database".to_owned())
            })?,
            note: row.note,
            created_at: row.created_at,
            updated_at: row.updated_at,
            archived_at: row.archived_at,
        })
    }
}
