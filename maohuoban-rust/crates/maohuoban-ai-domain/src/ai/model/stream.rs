use serde::{Deserialize, Serialize};
use uuid::Uuid;

use super::{
    AiAnswerVerification, AiBlockedReason, AiCitation, AiPetDisplaySnapshot, AiPetResolution,
    AiProposedAction, LlmFinishReason, LlmUsage,
};

/// AiStreamEvent 毛伙伴对 iOS 输出的稳定 SSE 事件
/// 核心职责：
/// - 屏蔽后端 Provider 差异，定义固定事件顺序
/// - iOS 只消费自家事件协议
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "event", rename_all = "snake_case")]
pub enum AiStreamEvent {
    MessageStarted {
        chat_session_id: Uuid,
        message_id: Uuid,
        #[serde(default, skip_serializing_if = "Option::is_none")]
        target_pet: Option<AiPetDisplaySnapshot>,
        title: String,
    },
    PetResolution {
        resolution: AiPetResolution,
    },
    ToolCall {
        tool_name: String,
        status: AiToolCallStatus,
        citation_count: u32,
    },
    AgentActivity {
        display_text: String,
        status: AiAgentActivityStatus,
    },
    Delta {
        text: String,
    },
    Citation {
        citation: AiCitation,
    },
    ProposedAction {
        action: AiProposedAction,
    },
    ConfirmationTask {
        confirmation_task_id: Uuid,
        question_text: String,
    },
    MessageCompleted {
        message_id: Uuid,
        final_text: String,
        usage: LlmUsage,
        finish_reason: LlmFinishReason,
        citations: Vec<AiCitation>,
        verification: AiAnswerVerification,
    },
    Error {
        code: String,
        message: String,
        retryable: bool,
        #[serde(default, skip_serializing_if = "Option::is_none")]
        blocked_reason: Option<AiBlockedReason>,
        #[serde(default, skip_serializing_if = "Option::is_none")]
        safe_fallback_text: Option<String>,
    },
}

/// AiToolCallStatus 工具调用状态
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AiToolCallStatus {
    Started,
    Allowed,
    Denied,
    Failed,
}

/// AiAgentActivityStatus Agent UI 安全进度状态
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AiAgentActivityStatus {
    Started,
    Completed,
    Failed,
}

impl AiStreamEvent {
    /// event_name 返回 SSE 事件名
    pub fn event_name(&self) -> &'static str {
        match self {
            Self::MessageStarted { .. } => "message_started",
            Self::PetResolution { .. } => "pet_resolution",
            Self::ToolCall { .. } => "tool_call",
            Self::AgentActivity { .. } => "agent_activity",
            Self::Delta { .. } => "delta",
            Self::Citation { .. } => "citation",
            Self::ProposedAction { .. } => "proposed_action",
            Self::ConfirmationTask { .. } => "confirmation_task",
            Self::MessageCompleted { .. } => "message_completed",
            Self::Error { .. } => "error",
        }
    }
}
