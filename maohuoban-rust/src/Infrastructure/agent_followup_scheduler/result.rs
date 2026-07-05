/// `AgentFollowupSchedulerRunResult` Agent 主动追踪调度结果
/// 核心职责：
/// - 返回本次投影出的站内轻提醒数量
/// - 返回本次写入的主动追问会话消息数量
/// - 为测试和运行日志提供稳定摘要
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct AgentFollowupSchedulerRunResult {
    pub projected_hints: i64,
    pub proactive_messages: i64,
}
