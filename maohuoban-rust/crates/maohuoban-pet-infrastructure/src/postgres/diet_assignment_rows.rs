use chrono::{DateTime, Utc};
use maohuoban_pet_domain::pet::{
    DietAssignmentRole, DietAssignmentStatus, PetDietAssignment, PetError,
};
use sqlx::FromRow;
use uuid::Uuid;

/// DietAssignmentRow 饮食配置数据库行
/// 核心职责：
/// - 映射 pet_diet_assignments 表
/// - 转换数据库文本字段到领域枚举
#[derive(Debug, FromRow)]
pub(super) struct DietAssignmentRow {
    id: Uuid,
    pet_id: Uuid,
    food_item_id: Uuid,
    role: String,
    status: String,
    started_at: DateTime<Utc>,
    ended_at: Option<DateTime<Utc>>,
    reason: Option<String>,
    created_by_user_id: Uuid,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
}

impl TryFrom<DietAssignmentRow> for PetDietAssignment {
    type Error = PetError;

    fn try_from(row: DietAssignmentRow) -> Result<Self, Self::Error> {
        Ok(Self {
            id: row.id,
            pet_id: row.pet_id,
            food_item_id: row.food_item_id,
            role: DietAssignmentRole::try_from(row.role.as_str()).map_err(|_| {
                PetError::Infrastructure("unknown diet assignment role from database".to_owned())
            })?,
            status: DietAssignmentStatus::try_from(row.status.as_str()).map_err(|_| {
                PetError::Infrastructure("unknown diet assignment status from database".to_owned())
            })?,
            started_at: row.started_at,
            ended_at: row.ended_at,
            reason: row.reason,
            created_by_user_id: row.created_by_user_id,
            created_at: row.created_at,
            updated_at: row.updated_at,
        })
    }
}
