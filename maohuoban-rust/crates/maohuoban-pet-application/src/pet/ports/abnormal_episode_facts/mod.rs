mod event_fact;

use chrono::{DateTime, Utc};
use uuid::Uuid;

pub use event_fact::PetAbnormalEpisodeEventFact;

/// PetAbnormalEpisodeFacts 宠物异常 episode 事实读模型
/// 核心职责：
/// - 汇总单个异常 episode 的状态、父事件和进展时间线
/// - 为 Agent 事实 provider 提供稳定读取合同
#[derive(Debug, Clone)]
pub struct PetAbnormalEpisodeFacts {
    pub episode_id: Uuid,
    pub pet_id: Uuid,
    pub status: String,
    pub primary_symptom_kind: Option<String>,
    pub severity: Option<String>,
    pub started_at: DateTime<Utc>,
    pub last_observed_at: Option<DateTime<Utc>>,
    pub recovered_at: Option<DateTime<Utc>>,
    pub created_event_id: Uuid,
    pub latest_event_id: Option<Uuid>,
    pub initial_event: PetAbnormalEpisodeEventFact,
    pub timeline_events: Vec<PetAbnormalEpisodeEventFact>,
}
