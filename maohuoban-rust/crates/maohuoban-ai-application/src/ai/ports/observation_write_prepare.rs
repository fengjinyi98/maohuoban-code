use maohuoban_ai_domain::ai::AiToolConfirmationRequirement;

/// PreparedObservationWrite 观察记录写提案结果
/// 核心职责：
/// - 返回已持久化的 confirmation task
/// - 固定 commit 阶段需要的确认任务 ID 和回显参数
#[derive(Debug, Clone)]
pub struct PreparedObservationWrite {
    pub confirmation: AiToolConfirmationRequirement,
}
