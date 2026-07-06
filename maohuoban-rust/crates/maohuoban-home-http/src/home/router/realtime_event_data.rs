use chrono::{DateTime, Utc};
use serde::Serialize;
use uuid::Uuid;

use crate::home::HomeRealtimeEvent;

/// `HomeRealtimeEventData` 首页实时事件 DTO
/// 核心职责：
/// - 将服务端内部事件转换为 SSE JSON payload
/// - 让客户端只依赖稳定字段触发读模型刷新
#[derive(Debug, Serialize)]
pub(super) struct HomeRealtimeEventData {
    pub event: &'static str,
    pub pet_id: Uuid,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub hint_id: Option<Uuid>,
    pub kind: &'static str,
    pub source_ref_type: String,
    pub source_ref_id: Uuid,
    pub occurred_at: DateTime<Utc>,
}

impl From<HomeRealtimeEvent> for HomeRealtimeEventData {
    fn from(event: HomeRealtimeEvent) -> Self {
        Self {
            event: event.kind.as_str(),
            pet_id: event.pet_id,
            hint_id: event.hint_id,
            kind: event.kind.as_str(),
            source_ref_type: event.source_ref_type,
            source_ref_id: event.source_ref_id,
            occurred_at: event.occurred_at,
        }
    }
}
