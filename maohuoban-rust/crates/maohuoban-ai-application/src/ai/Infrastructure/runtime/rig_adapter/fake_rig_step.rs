use maohuoban_ai_domain::ai::{
    AgentTurnStatus, LlmFinishReason, LlmToolCall, LlmUsage, LoopToolResult, ModelLabel,
};
use uuid::Uuid;

/// FakeRigStep Rig POC step
/// 核心职责：
/// - 模拟 Rig sans-IO step 输出
/// - 为 RigLoopEngineAdapter 提供可测试输入
#[derive(Debug, Clone, PartialEq)]
pub enum FakeRigStep {
    CallModel {
        model_label: ModelLabel,
        tool_count: u32,
        finish_reason: LlmFinishReason,
        usage: LlmUsage,
    },
    CallTools {
        tool_calls: Vec<LlmToolCall>,
    },
    /// CallToolResults 工具执行结果 step
    /// 核心职责：
    /// - 承载工具执行后的状态和输出
    /// - 映射为 LoopStep::call_tool_results
    CallToolResults {
        tool_results: Vec<LoopToolResult>,
    },
    Done {
        message_id: Uuid,
        final_text: String,
        status: AgentTurnStatus,
    },
}
