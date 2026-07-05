use chrono::{DateTime, Utc};
use uuid::Uuid;

/// SavedAbnormalFollowupPlan 已保存异常追踪计划
/// 核心职责：
/// - 返回 application service 校验后的计划 ID 和到期时间
/// - 供 Runtime tool 形成可审计工具事实
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SavedAbnormalFollowupPlan {
    pub followup_id: Uuid,
    pub due_at: DateTime<Utc>,
}
