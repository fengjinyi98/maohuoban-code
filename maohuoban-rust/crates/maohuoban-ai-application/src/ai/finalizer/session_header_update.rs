use chrono::{DateTime, Utc};
use uuid::Uuid;

/// FinalizerSessionHeaderUpdate 会话头刷新请求
/// 核心职责：
/// - 固定 Finalizer 对 session header 的最小更新语义
/// - 让会话列表可按最近 turn 和最近消息刷新
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FinalizerSessionHeaderUpdate {
    pub session_id: Uuid,
    pub actor_user_id: Uuid,
    pub last_turn_id: Uuid,
    pub last_message_id: Option<Uuid>,
    pub last_message_at: DateTime<Utc>,
}
