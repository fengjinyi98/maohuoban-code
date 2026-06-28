use maohuoban_ai_domain::ai::{
    AgentTurnStatus, LlmFinishReason, LlmToolCall, LlmUsage, ModelLabel,
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
    Done {
        message_id: Uuid,
        final_text: String,
        status: AgentTurnStatus,
    },
}
