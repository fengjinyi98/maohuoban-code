use serde::{Deserialize, Serialize};
use uuid::Uuid;

use super::{AiConversationSurface, LlmFinishReason, LlmToolCall, LlmUsage};
use super::provider_error::ProviderErrorCategory;

/// MAIN_PET_CARE_AGENT_ID 首期主 Agent 标识
/// 核心职责：
/// - 固定 WT01 冻结的主 Agent 名称
/// - 供 Runtime 事件、Session 和后续 Adapter 共享
pub const MAIN_PET_CARE_AGENT_ID: &str = "main_pet_care_agent";

/// AgentTurnId Runtime turn 标识
/// 核心职责：
/// - 包装单轮对话 ID，避免与 chat session / message ID 混用
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(transparent)]
pub struct AgentTurnId(Uuid);

impl AgentTurnId {
    /// new 创建新的 turn id
    pub fn new() -> Self {
        Self(Uuid::new_v4())
    }

    /// from_uuid 从既有 UUID 构造 turn id
    pub fn from_uuid(id: Uuid) -> Self {
        Self(id)
    }

    /// as_uuid 返回内部 UUID
    pub fn as_uuid(self) -> Uuid {
        self.0
    }
}

impl Default for AgentTurnId {
    fn default() -> Self {
        Self::new()
    }
}

/// AgentId Runtime agent 标识
/// 核心职责：
/// - 表达当前 session 由哪个 Agent 定义驱动
/// - 首期只提供 main_pet_care_agent，预留多 Agent 扩展
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(transparent)]
pub struct AgentId(String);

impl AgentId {
    /// main_pet_care_agent 返回首期主 Agent 标识
    pub fn main_pet_care_agent() -> Self {
        Self(MAIN_PET_CARE_AGENT_ID.to_owned())
    }

    /// as_str 返回稳定字符串
    pub fn as_str(&self) -> &str {
        &self.0
    }
}

/// ModelLabel Runtime 模型标签
/// 核心职责：
/// - 使用毛伙伴稳定 label 屏蔽 Provider 真实模型名
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ModelLabel {
    Lite,
    Primary,
    Pro,
    Memory,
}

/// AgentTurnStatus Runtime turn 结束状态
/// 核心职责：
/// - 表达单轮对话完成、等待或失败状态
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AgentTurnStatus {
    Completed,
    Failed,
    AwaitingConfirmation,
    AwaitingClarification,
}

/// AgentToolStatus Runtime 工具执行状态
/// 核心职责：
/// - 表达工具调用在 Runtime 内部的完成结果
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AgentToolStatus {
    Succeeded,
    Failed,
    Denied,
}

/// AgentSessionState Runtime session 内存状态
/// 核心职责：
/// - 保存 LoopEngine 推进时需要的最小 session 上下文
/// - 首期只服务 fake loop 和事件契约验证，不负责持久化
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AgentSessionState {
    pub chat_session_id: Uuid,
    pub agent_id: AgentId,
    pub surface: AiConversationSurface,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub user_inputs: Vec<String>,
    pub turn_index: u32,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub current_turn_id: Option<AgentTurnId>,
}

impl AgentSessionState {
    /// new 创建最小 in-memory session 状态
    pub fn new(chat_session_id: Uuid, agent_id: AgentId, surface: AiConversationSurface) -> Self {
        Self {
            chat_session_id,
            agent_id,
            surface,
            user_inputs: Vec::new(),
            turn_index: 0,
            current_turn_id: None,
        }
    }

    /// begin_turn 记录用户输入并开启新 turn
    pub fn begin_turn(&mut self, user_input: String) -> AgentTurnId {
        self.turn_index = self.turn_index.saturating_add(1);
        self.user_inputs.push(user_input);
        let turn_id = AgentTurnId::new();
        self.current_turn_id = Some(turn_id);
        turn_id
    }
}

/// LoopStep LoopEngine 输出 step
/// 核心职责：
/// - 固定 CallModel、CallTools、Done 三类 Runtime step
/// - 让不同 LoopEngine adapter 可替换
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "step", rename_all = "snake_case")]
pub enum LoopStep {
    CallModel {
        model_label: ModelLabel,
        tool_count: u32,
        outcome: ModelCallOutcome,
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

impl LoopStep {
    /// model_finished 构造完成型 CallModel step
    pub fn model_finished(
        model_label: ModelLabel,
        tool_count: u32,
        finish_reason: LlmFinishReason,
        usage: LlmUsage,
    ) -> Self {
        Self::CallModel {
            model_label,
            tool_count,
            outcome: ModelCallOutcome::Finished {
                finish_reason,
                usage,
            },
        }
    }

    /// provider_error 构造 Provider 错误型 CallModel step
    pub fn provider_error(
        model_label: ModelLabel,
        tool_count: u32,
        category: ProviderErrorCategory,
        retryable: bool,
        error_code: String,
    ) -> Self {
        Self::CallModel {
            model_label,
            tool_count,
            outcome: ModelCallOutcome::ProviderError {
                category,
                retryable,
                error_code,
            },
        }
    }

    /// call_tools 构造工具调用 step
    pub fn call_tools(tool_calls: Vec<LlmToolCall>) -> Self {
        Self::CallTools { tool_calls }
    }

    /// done 构造终止 step
    pub fn done(message_id: Uuid, final_text: String, status: AgentTurnStatus) -> Self {
        Self::Done {
            message_id,
            final_text,
            status,
        }
    }

    /// step_name 返回冻结 step 名称
    pub fn step_name(&self) -> &'static str {
        match self {
            Self::CallModel { .. } => "call_model",
            Self::CallTools { .. } => "call_tools",
            Self::Done { .. } => "done",
        }
    }
}

/// ModelCallOutcome 模型调用结果
/// 核心职责：
/// - 在 CallModel step 内表达成功完成或 Provider 失败
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "status", rename_all = "snake_case")]
pub enum ModelCallOutcome {
    Finished {
        finish_reason: LlmFinishReason,
        usage: LlmUsage,
    },
    ProviderError {
        category: ProviderErrorCategory,
        retryable: bool,
        error_code: String,
    },
}

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
    },
    ModelCallFinished {
        turn_id: AgentTurnId,
        finish_reason: LlmFinishReason,
        usage: LlmUsage,
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
    },
    TurnFinished {
        turn_id: AgentTurnId,
        message_id: Uuid,
        final_text: String,
        status: AgentTurnStatus,
    },
    TurnFailed {
        turn_id: AgentTurnId,
        error_code: String,
        retryable: bool,
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
