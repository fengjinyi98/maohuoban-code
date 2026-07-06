use chrono::{DateTime, Utc};
use uuid::Uuid;

use super::HomeAttentionHintRealtimeEventKind;

/// HomeAttentionHintRealtimeEvent 首页轻提醒实时事件
/// 核心职责：
/// - 用应用层稳定语义表达首页轻提醒变化
/// - 避免 AI HTTP 层直接依赖首页 HTTP SSE 实现
#[derive(Debug, Clone)]
pub struct HomeAttentionHintRealtimeEvent {
    pub actor_user_id: Uuid,
    pub pet_id: Uuid,
    pub hint_id: Uuid,
    pub kind: HomeAttentionHintRealtimeEventKind,
    pub source_ref_type: String,
    pub source_ref_id: Uuid,
    pub occurred_at: DateTime<Utc>,
}

/// HomeTimelineRealtimeEvent 首页时间线实时事件
/// 核心职责：
/// - 表达宠物事实账本写入后首页时间线读模型需要刷新
/// - 避免将轻提醒 hint 语义复用到普通时间线事件
#[derive(Debug, Clone)]
pub struct HomeTimelineRealtimeEvent {
    pub actor_user_id: Uuid,
    pub pet_id: Uuid,
    pub event_id: Uuid,
    pub occurred_at: DateTime<Utc>,
}
