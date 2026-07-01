use maohuoban_ai_domain::ai::{LoopToolResult, ToolExecutionAudit};

/// ToolGatewayResult Tool Gateway 收口结果
/// 核心职责：
/// - 暴露 Runtime 继续推进所需的 LoopToolResult
/// - 附带正式工具审计记录供 diagnostics/回放消费
#[derive(Debug, Clone)]
pub struct ToolGatewayResult {
    pub loop_result: LoopToolResult,
    pub audit: ToolExecutionAudit,
}
