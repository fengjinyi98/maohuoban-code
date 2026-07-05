/// `AgentFollowupPlannerRunResult` 异常主动追踪规划执行结果
/// 核心职责：
/// - 汇报本次后台规划处理数量
/// - 为 scheduler/测试提供可验证执行摘要
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct AgentFollowupPlannerRunResult {
    pub planned_count: u32,
}
