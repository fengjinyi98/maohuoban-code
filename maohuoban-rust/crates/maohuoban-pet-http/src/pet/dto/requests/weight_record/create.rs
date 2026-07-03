use chrono::{DateTime, Utc};
use maohuoban_pet_application::pet::{NewPetWeightRecord, PetWeightRecordSource};
use serde::Deserialize;
use uuid::Uuid;

/// CreatePetWeightRecordRequest 新建体重记录请求
/// 核心职责：
/// - 接收体重数值、备注和记录时间
/// - 转换为应用层新建输入
#[derive(Debug, Deserialize)]
pub(crate) struct CreatePetWeightRecordRequest {
    weight_grams: i32,
    note: Option<String>,
    occurred_at: DateTime<Utc>,
}

impl CreatePetWeightRecordRequest {
    pub(crate) fn into_input(self, pet_id: Uuid, actor_user_id: Uuid) -> NewPetWeightRecord {
        NewPetWeightRecord {
            pet_id,
            actor_user_id,
            weight_grams: self.weight_grams,
            note: self.note,
            source: PetWeightRecordSource::Manual,
            occurred_at: self.occurred_at,
        }
    }
}
