use chrono::{DateTime, Utc};
use maohuoban_pet_application::pet::UpdatePetWeightRecord;
use serde::Deserialize;
use uuid::Uuid;

/// UpdatePetWeightRecordRequest 更新体重记录请求
/// 核心职责：
/// - 接收编辑态提交的完整体重记录
/// - 保持 HTTP DTO 和应用层输入解耦
#[derive(Debug, Deserialize)]
pub(crate) struct UpdatePetWeightRecordRequest {
    weight_grams: i32,
    note: Option<String>,
    occurred_at: DateTime<Utc>,
}

impl UpdatePetWeightRecordRequest {
    pub(crate) fn into_input(self, record_id: Uuid, actor_user_id: Uuid) -> UpdatePetWeightRecord {
        UpdatePetWeightRecord {
            record_id,
            actor_user_id,
            weight_grams: self.weight_grams,
            note: self.note,
            occurred_at: self.occurred_at,
        }
    }
}
