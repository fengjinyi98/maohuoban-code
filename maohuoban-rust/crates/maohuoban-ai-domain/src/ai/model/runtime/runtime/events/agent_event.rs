use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::ai::AiFactPackage;

use super::super::provider_error::ProviderErrorCategory;
use super::super::{
    AgentId, AgentToolStatus, AgentTurnId, AgentTurnStatus, AiConversationSurface, LlmFinishReason,
    LlmUsage, ModelLabel,
};
use super::termination_reason::AgentTurnTerminationReason;

/// AgentEvent Runtime 内部事件
/// 核心职责：
/// - 固定 Agent Runtime 对外暴露的内部事件流
/// - 为后续 SSE adapter、SessionEventStore 和 Eval 提供稳定输入
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "event", rename_all = "snake_case")]
pub enum AgentEvent {
    TurnStarted {
        turn_id: AgentTurnId,
        chat_session_id: Uuid,
        agent_id: AgentId,
        surface: AiConversationSurface,
        engine_mode: String,
    },
    PolicyChecked {
        turn_id: AgentTurnId,
        decision: String,
        risk_level: String,
    },
    ModelCallStarted {
        turn_id: AgentTurnId,
        model_label: ModelLabel,
        tool_count: u32,
        engine_mode: String,
    },
    ModelCallFinished {
        turn_id: AgentTurnId,
        finish_reason: LlmFinishReason,
        usage: LlmUsage,
        provider: String,
        model: String,
        engine_mode: String,
    },
    ToolStarted {
        turn_id: AgentTurnId,
        tool_call_id: String,
        tool_name: String,
    },
    ToolFinished {
        turn_id: AgentTurnId,
        tool_call_id: String,
        status: AgentToolStatus,
        citation_count: u32,
        #[serde(default, skip_serializing_if = "Option::is_none")]
        fact_package: Option<Box<AiFactPackage>>,
    },
    NeedsConfirmation {
        turn_id: AgentTurnId,
        confirmation_task_id: Uuid,
        question_text: String,
    },
    NeedsClarification {
        turn_id: AgentTurnId,
        reason: String,
        suggested_actions: Vec<String>,
    },
    MessageDelta {
        turn_id: AgentTurnId,
        text: String,
    },
    ProviderError {
        turn_id: AgentTurnId,
        category: ProviderErrorCategory,
        retryable: bool,
        engine_mode: String,
    },
    TurnFinished {
        turn_id: AgentTurnId,
        message_id: Uuid,
        final_text: String,
        status: AgentTurnStatus,
        #[serde(default, skip_serializing_if = "Option::is_none")]
        termination_reason: Option<AgentTurnTerminationReason>,
    },
    TurnFailed {
        turn_id: AgentTurnId,
        error_code: String,
        retryable: bool,
        engine_mode: String,
        #[serde(default, skip_serializing_if = "Option::is_none")]
        termination_reason: Option<AgentTurnTerminationReason>,
    },
}

impl AgentEvent {
    /// event_name 返回冻结事件名
    pub fn event_name(&self) -> &'static str {
        match self {
            Self::TurnStarted { .. } => "turn_started",
            Self::PolicyChecked { .. } => "policy_checked",
            Self::ModelCallStarted { .. } => "model_call_started",
            Self::ModelCallFinished { .. } => "model_call_finished",
            Self::ToolStarted { .. } => "tool_started",
            Self::ToolFinished { .. } => "tool_finished",
            Self::NeedsConfirmation { .. } => "needs_confirmation",
            Self::NeedsClarification { .. } => "needs_clarification",
            Self::MessageDelta { .. } => "message_delta",
            Self::ProviderError { .. } => "provider_error",
            Self::TurnFinished { .. } => "turn_finished",
            Self::TurnFailed { .. } => "turn_failed",
        }
    }
}
