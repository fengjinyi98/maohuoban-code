use serde::{Deserialize, Serialize};
use uuid::Uuid;

use super::ToolFailure;
use super::provider_error::ProviderErrorCategory;
use super::{AgentSessionWorkbench, AiConversationSurface, LlmFinishReason, LlmToolCall, LlmUsage};

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

impl ModelLabel {
    /// as_str 返回稳定模型标签
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Lite => "lite",
            Self::Primary => "primary",
            Self::Pro => "pro",
            Self::Memory => "memory",
        }
    }
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

/// AiToolConfirmationRequirement 工具确认需求
/// 核心职责：
/// - 表达确认前不得执行的工具调用
/// - 保留确认任务、工具名、问题文案和原始参数
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AiToolConfirmationRequirement {
    pub confirmation_task_id: String,
    pub tool_name: String,
    pub question_text: String,
    pub args: serde_json::Value,
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

/// InternalTurnEvent Agent turn 内部事件
/// 核心职责：
/// - 承载模型原始增量、工具规划和 Provider 草稿等内部信号
/// - 作为运行时审计与调试输入，禁止直接投影到 iOS SSE 协议
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "event", rename_all = "snake_case")]
pub enum InternalTurnEvent {
    ModelDelta {
        turn_id: AgentTurnId,
        text: String,
    },
    ToolPlanning {
        turn_id: AgentTurnId,
        tool_call_id: String,
        tool_name: String,
        arguments: String,
    },
    ProviderJsonDraft {
        turn_id: AgentTurnId,
        text: String,
    },
}

impl InternalTurnEvent {
    /// event_name 返回内部事件冻结名称
    #[must_use]
    pub fn event_name(&self) -> &'static str {
        match self {
            Self::ModelDelta { .. } => "model_delta",
            Self::ToolPlanning { .. } => "tool_planning",
            Self::ProviderJsonDraft { .. } => "provider_json_draft",
        }
    }
}

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

/// AgentSessionState Runtime session 内存状态
/// 核心职责：
/// - 保存 LoopEngine 推进时需要的最小 session 上下文
/// - 首期只服务 fake loop 和事件契约验证，不负责持久化
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AgentSessionState {
    pub chat_session_id: Uuid,
    pub agent_id: AgentId,
    pub surface: AiConversationSurface,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub workbench: Option<AgentSessionWorkbench>,
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
            workbench: None,
            user_inputs: Vec::new(),
            turn_index: 0,
            current_turn_id: None,
        }
    }

    /// attach_workbench 设置本轮 Runtime 工作台上下文
    pub fn attach_workbench(&mut self, workbench: Option<AgentSessionWorkbench>) {
        self.workbench = workbench;
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
/// - 固定模型调用、工具调用、消息增量和终态 Runtime step
/// - 让不同 LoopEngine adapter 可替换
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "step", rename_all = "snake_case")]
pub enum LoopStep {
    CallModel {
        model_label: ModelLabel,
        tool_count: u32,
        outcome: ModelCallOutcome,
    },
    MessageDelta {
        text: String,
    },
    CallTools {
        tool_results: Vec<LoopToolResult>,
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
                provider: "runtime".to_owned(),
                model: model_label.as_str().to_owned(),
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
        Self::CallTools {
            tool_results: tool_calls
                .into_iter()
                .map(LoopToolResult::requested)
                .collect(),
        }
    }

    /// call_tool_results 构造工具结果 step
    pub fn call_tool_results(tool_results: Vec<LoopToolResult>) -> Self {
        Self::CallTools { tool_results }
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
            Self::MessageDelta { .. } => "message_delta",
            Self::CallTools { .. } => "call_tools",
            Self::Done { .. } => "done",
        }
    }
}

/// LoopToolResult 工具调用结果
/// 核心职责：
/// - 承载模型申请的工具调用、执行结果和确认需求
/// - 让 LoopEngine 能将工具执行回灌到下一轮模型调用
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct LoopToolResult {
    pub tool_call: LlmToolCall,
    pub status: LoopToolStatus,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub output: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub denied_reason: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub failed_reason: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub confirmation: Option<AiToolConfirmationRequirement>,
    /// 结构化工具失败信息
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub failure: Option<ToolFailure>,
    /// guardrail 软提醒消息，不破坏 output JSON 结构
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub guardrail_message: Option<String>,
}

impl LoopToolResult {
    /// requested 构造待执行工具请求
    pub fn requested(tool_call: LlmToolCall) -> Self {
        Self {
            tool_call,
            status: LoopToolStatus::Requested,
            output: None,
            denied_reason: None,
            failed_reason: None,
            confirmation: None,
            failure: None,
            guardrail_message: None,
        }
    }

    /// succeeded 构造成功工具结果
    pub fn succeeded(tool_call: LlmToolCall, output: impl Into<String>) -> Self {
        Self {
            tool_call,
            status: LoopToolStatus::Succeeded,
            output: Some(output.into()),
            denied_reason: None,
            failed_reason: None,
            confirmation: None,
            failure: None,
            guardrail_message: None,
        }
    }

    /// denied 构造拒绝工具结果
    pub fn denied(tool_call: LlmToolCall, reason: impl Into<String>) -> Self {
        Self {
            tool_call,
            status: LoopToolStatus::Denied,
            output: None,
            denied_reason: Some(reason.into()),
            failed_reason: None,
            confirmation: None,
            failure: None,
            guardrail_message: None,
        }
    }

    /// failed 构造失败工具结果
    pub fn failed(tool_call: LlmToolCall, reason: impl Into<String>) -> Self {
        Self {
            tool_call,
            status: LoopToolStatus::Failed,
            output: None,
            denied_reason: None,
            failed_reason: Some(reason.into()),
            confirmation: None,
            failure: None,
            guardrail_message: None,
        }
    }

    /// failed_with_failure 构造带结构化信息的失败工具结果
    pub fn failed_with_failure(tool_call: LlmToolCall, failure: ToolFailure) -> Self {
        let reason = failure.safe_user_message.clone();
        Self {
            tool_call,
            status: LoopToolStatus::Failed,
            output: None,
            denied_reason: None,
            failed_reason: Some(reason),
            confirmation: None,
            failure: Some(failure),
            guardrail_message: None,
        }
    }

    /// requires_confirmation 构造确认需求工具结果
    pub fn requires_confirmation(
        tool_call: LlmToolCall,
        confirmation: AiToolConfirmationRequirement,
    ) -> Self {
        Self {
            tool_call,
            status: LoopToolStatus::RequiresConfirmation,
            output: None,
            denied_reason: None,
            failed_reason: None,
            confirmation: Some(confirmation),
            failure: None,
            guardrail_message: None,
        }
    }
}

/// LoopToolStatus 工具调用状态
/// 核心职责：
/// - 表达工具在 Runtime 内的请求、结果和确认态
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum LoopToolStatus {
    Requested,
    Succeeded,
    Denied,
    Failed,
    RequiresConfirmation,
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
        provider: String,
        model: String,
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
        provider: String,
        model: String,
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
