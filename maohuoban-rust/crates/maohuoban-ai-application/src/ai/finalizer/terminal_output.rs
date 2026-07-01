use maohuoban_ai_domain::ai::{
    AiAnswerVerification, AiCitation, AiContentBlock, AiProposedAction, AiSessionTurnStatus,
    LlmFinishReason, LlmUsage,
};
use uuid::Uuid;

use super::FinalizerAsyncJob;

/// TurnTerminalOutput Turn 终态输出
/// 核心职责：
/// - 承载 Runtime 进入终态后的所有可持久化产物
/// - 作为 stream / non-stream 共同调用 Finalizer 的稳定输入
#[derive(Debug, Clone, PartialEq)]
pub struct TurnTerminalOutput {
    pub turn_id: Uuid,
    pub session_id: Uuid,
    pub actor_user_id: Uuid,
    pub assistant_message_id: Uuid,
    pub status: AiSessionTurnStatus,
    pub final_text: Option<String>,
    pub content_blocks: Vec<AiContentBlock>,
    pub safe_failure_text: Option<String>,
    pub failure_code: Option<String>,
    pub retryable: Option<bool>,
    pub provider: Option<String>,
    pub model: Option<String>,
    pub finish_reason: Option<LlmFinishReason>,
    pub usage: LlmUsage,
    pub verification: Option<AiAnswerVerification>,
    pub citations: Vec<AiCitation>,
    pub proposed_actions: Vec<AiProposedAction>,
    pub async_jobs: Vec<FinalizerAsyncJob>,
}
