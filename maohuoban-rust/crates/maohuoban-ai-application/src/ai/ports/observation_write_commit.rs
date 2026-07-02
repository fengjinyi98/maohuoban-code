use uuid::Uuid;

/// CommittedObservationWrite 观察记录写提交结果
/// 核心职责：
/// - 返回真实落库后的宠物事件 ID
/// - 为 Tool Gateway 和后续 fact package 投影提供结构化结果
#[derive(Debug, Clone)]
pub struct CommittedObservationWrite {
    pub confirmation_task_id: Uuid,
    pub event_id: Uuid,
}
