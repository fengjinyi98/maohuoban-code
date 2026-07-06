use chrono::{DateTime, Utc};
use uuid::Uuid;

use super::HomeRealtimeEventKind;

/// `HomeRealtimeEvent` 首页实时事件
/// 核心职责：
/// - 承载当前登录用户可见的首页变化信号
/// - 保持事件 payload 小而稳定，具体数据仍由 dashboard 读模型提供
#[derive(Debug, Clone)]
pub struct HomeRealtimeEvent {
    pub actor_user_id: Uuid,
    pub pet_id: Uuid,
    pub hint_id: Uuid,
    pub kind: HomeRealtimeEventKind,
    pub source_ref_type: String,
    pub source_ref_id: Uuid,
    pub occurred_at: DateTime<Utc>,
}
