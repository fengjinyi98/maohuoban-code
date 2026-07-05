use chrono::{DateTime, Utc};
use uuid::Uuid;

/// PetAbnormalEpisodeEventFact 异常 episode 事件事实
/// 核心职责：
/// - 表达父异常、追加观察、恢复和就诊关联事件的 Agent 可读字段
/// - 保留附件数量用于回答照片证据存在性
#[derive(Debug, Clone)]
pub struct PetAbnormalEpisodeEventFact {
    pub event_id: Uuid,
    pub event_subkind: Option<String>,
    pub title: String,
    pub summary: Option<String>,
    pub occurred_at: DateTime<Utc>,
    pub attachment_count: i64,
}
