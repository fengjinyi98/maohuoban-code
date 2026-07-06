use chrono::{DateTime, Utc};
use uuid::Uuid;

/// CommittedAbnormalSymptomCreation 已提交异常创建结果
/// 核心职责：
/// - 返回异常父事件与 episode 的稳定 ID
/// - 为授权后 Agent 续跑提供主动追踪计划上下文
#[derive(Debug, Clone)]
pub struct CommittedAbnormalSymptomCreation {
    pub confirmation_task_id: Uuid,
    pub event_id: Uuid,
    pub episode_id: Uuid,
    pub agent_followup_id: Uuid,
    pub next_followup_due_at: DateTime<Utc>,
}
