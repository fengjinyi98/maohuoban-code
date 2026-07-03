use serde::{Deserialize, Serialize};
use uuid::Uuid;

use super::super::{AgentToolStatus, AgentTurnId, AgentTurnStatus};

/// UserVisibleTurnEvent Agent turn 用户可见事件
/// 核心职责：
/// - 只承载可以进入客户端协议的进度、正文、确认和错误事件
/// - 隔离 Provider chunk、工具参数、内部上下文和 JSON 草稿
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "event", rename_all = "snake_case")]
pub enum UserVisibleTurnEvent {
    ExecutionTraceStarted {
        turn_id: AgentTurnId,
        display_text: String,
    },
    ExecutionTraceCompleted {
        turn_id: AgentTurnId,
        display_text: String,
        status: AgentToolStatus,
        citation_count: u32,
    },
    AnswerDelta {
        turn_id: AgentTurnId,
        text: String,
    },
    AnswerCompleted {
        turn_id: AgentTurnId,
        message_id: Uuid,
        final_text: String,
        status: AgentTurnStatus,
    },
    ConfirmationTask {
        turn_id: AgentTurnId,
        confirmation_task_id: Uuid,
        question_text: String,
    },
    Error {
        turn_id: AgentTurnId,
        code: String,
        message: String,
        retryable: bool,
    },
}

impl UserVisibleTurnEvent {
    /// event_name 返回用户可见事件冻结名称
    #[must_use]
    pub fn event_name(&self) -> &'static str {
        match self {
            Self::ExecutionTraceStarted { .. } => "execution_trace_started",
            Self::ExecutionTraceCompleted { .. } => "execution_trace_completed",
            Self::AnswerDelta { .. } => "answer_delta",
            Self::AnswerCompleted { .. } => "answer_completed",
            Self::ConfirmationTask { .. } => "confirmation_task",
            Self::Error { .. } => "error",
        }
    }
}
