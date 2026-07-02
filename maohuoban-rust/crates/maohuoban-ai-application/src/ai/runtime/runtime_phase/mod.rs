use futures_util::stream::BoxStream;
use maohuoban_ai_domain::ai::{
    AgentTurnTerminationReason, AiResult, LlmChatRequest, LlmDiagnosticsCorrelation,
    LlmFinishReason, LlmStreamEvent, LlmToolCall, LlmUsage, LoopToolResult,
};

use super::streaming_model_purpose::StreamingModelPurpose;

/// RuntimePhase Runtime 循环阶段
/// 核心职责：
/// - 表达模型、工具、追问和终态之间的阶段迁移
/// - 让主循环实现只负责编排而不再定义所有阶段类型
pub(crate) enum RuntimePhase {
    Model,
    StreamingModel {
        request: Box<LlmChatRequest>,
        stream: BoxStream<'static, AiResult<LlmStreamEvent>>,
        purpose: StreamingModelPurpose,
        accumulated_text: String,
        accumulated_reasoning_content: String,
        tool_calls: Vec<LlmToolCall>,
        usage: LlmUsage,
        finish_reason: LlmFinishReason,
        tool_count: u32,
        diagnostics_correlation: LlmDiagnosticsCorrelation,
        retry_count: u8,
    },
    ToolExecution {
        assistant_reasoning_content: Option<String>,
        assistant_tool_calls: Vec<LlmToolCall>,
        tool_calls: Vec<LlmToolCall>,
        completed_tool_rounds: u8,
    },
    FollowupModel {
        assistant_reasoning_content: Option<String>,
        assistant_tool_calls: Vec<LlmToolCall>,
        tool_results: Vec<LoopToolResult>,
        completed_tool_rounds: u8,
    },
    OutputRepairModel {
        request: Box<LlmChatRequest>,
        attempt: u8,
    },
    ClarifyUser {
        reason: String,
        suggested_actions: Vec<String>,
    },
    Done {
        message_id: uuid::Uuid,
        final_text: String,
        status: maohuoban_ai_domain::ai::AgentTurnStatus,
        termination_reason: AgentTurnTerminationReason,
        error_code: Option<String>,
    },
}
