use futures_util::stream::BoxStream;
use maohuoban_ai_domain::ai::{
    AiResult, LlmFinishReason, LlmStreamEvent, LlmToolCall, LlmUsage, LoopToolResult,
};

use super::streaming_model_purpose::StreamingModelPurpose;

/// RuntimePhase Runtime 循环阶段
/// 核心职责：
/// - 表达模型、工具、追问和终态之间的阶段迁移
/// - 让主循环实现只负责编排而不再定义所有阶段类型
pub(crate) enum RuntimePhase {
    Model,
    StreamingModel {
        stream: BoxStream<'static, AiResult<LlmStreamEvent>>,
        purpose: StreamingModelPurpose,
        accumulated_text: String,
        accumulated_reasoning_content: String,
        tool_calls: Vec<LlmToolCall>,
        usage: LlmUsage,
        finish_reason: LlmFinishReason,
        tool_count: u32,
    },
    ToolExecution {
        assistant_reasoning_content: Option<String>,
        assistant_tool_calls: Vec<LlmToolCall>,
        tool_calls: Vec<LlmToolCall>,
    },
    EvidenceToolExecution {
        assistant_tool_calls: Vec<LlmToolCall>,
        tool_calls: Vec<LlmToolCall>,
    },
    FollowupModel {
        assistant_reasoning_content: Option<String>,
        assistant_tool_calls: Vec<LlmToolCall>,
        tool_results: Vec<LoopToolResult>,
    },
    Done {
        message_id: uuid::Uuid,
        final_text: String,
        status: maohuoban_ai_domain::ai::AgentTurnStatus,
    },
}
