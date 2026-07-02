use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::ai::{AgentSessionWorkbench, AiFactPackage};

use super::ToolFailure;
use super::provider_error::ProviderErrorCategory;
use super::{
    AgentId, AgentToolStatus, AgentTurnId, AgentTurnStatus, AiConversationSurface,
    AiToolConfirmationRequirement, LlmFinishReason, LlmToolCall, LlmUsage, ModelLabel,
};

/// AgentTurnTerminationReason Runtime turn 终止原因
/// 核心职责：
/// - 区分自然停止、轮次上限、预算耗尽、澄清中断和输出守卫失败
/// - 为 diagnostics、contract tests 和上层观测提供稳定编码
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AgentTurnTerminationReason {
    ModelStop,
    MaxToolRounds,
    BudgetExhausted,
    AwaitingClarification,
    OutputGuardFailed,
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
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub current_turn_diagnostics_message_id: Option<Uuid>,
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
            current_turn_diagnostics_message_id: None,
        }
    }

    /// attach_workbench 设置本轮 Runtime 工作台上下文
    pub fn attach_workbench(&mut self, workbench: Option<AgentSessionWorkbench>) {
        self.workbench = workbench;
    }

    /// begin_turn 记录用户输入并开启新 turn
    pub fn begin_turn(&mut self, user_input: String) -> AgentTurnId {
        self.begin_turn_with_id_and_diagnostics_message_id(user_input, AgentTurnId::new(), None)
    }

    /// begin_turn_with_diagnostics_message_id 开启带诊断 message 关联键的 turn
    /// 核心职责：
    /// - 每轮开始时刷新 turn、用户输入和 message 关联键
    /// - 避免复用 Runtime session 时沿用上一轮 message_id
    pub fn begin_turn_with_diagnostics_message_id(
        &mut self,
        user_input: String,
        diagnostics_message_id: Option<Uuid>,
    ) -> AgentTurnId {
        self.begin_turn_with_id_and_diagnostics_message_id(
            user_input,
            AgentTurnId::new(),
            diagnostics_message_id,
        )
    }

    /// begin_turn_with_id 使用外部提供的 turn_id 开启新 turn
    /// 核心职责：
    /// - 让 HTTP Ingress Tx 先建 turn row，再由 Runtime 使用同一 turn_id
    /// - 保持 Runtime 事件与数据库 turn 行主键一致
    pub fn begin_turn_with_id(&mut self, user_input: String, turn_id: AgentTurnId) -> AgentTurnId {
        self.begin_turn_with_id_and_diagnostics_message_id(user_input, turn_id, None)
    }

    /// begin_turn_with_id_and_diagnostics_message_id 使用外部 turn_id 和诊断 message 关联键开启新 turn
    /// 核心职责：
    /// - 同时满足 WT01 的 turn 主链和 WT00 的 diagnostics 关联需求
    /// - 让 Runtime 事件、turn 行和 provider diagnostics 指向同一轮
    pub fn begin_turn_with_id_and_diagnostics_message_id(
        &mut self,
        user_input: String,
        turn_id: AgentTurnId,
        diagnostics_message_id: Option<Uuid>,
    ) -> AgentTurnId {
        self.turn_index = self.turn_index.saturating_add(1);
        self.user_inputs.push(user_input);
        self.current_turn_id = Some(turn_id);
        self.current_turn_diagnostics_message_id = diagnostics_message_id;
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
    ClarifyUser {
        reason: String,
        suggested_actions: Vec<String>,
    },
    CallTools {
        tool_results: Vec<LoopToolResult>,
    },
    Done {
        message_id: Uuid,
        final_text: String,
        status: AgentTurnStatus,
        termination_reason: AgentTurnTerminationReason,
        #[serde(default, skip_serializing_if = "Option::is_none")]
        error_code: Option<String>,
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

    /// clarify_user 构造用户追问 step
    pub fn clarify_user(reason: impl Into<String>, suggested_actions: Vec<String>) -> Self {
        Self::ClarifyUser {
            reason: reason.into(),
            suggested_actions,
        }
    }

    /// done 构造终止 step
    pub fn done(message_id: Uuid, final_text: String, status: AgentTurnStatus) -> Self {
        Self::Done {
            message_id,
            final_text,
            status,
            termination_reason: AgentTurnTerminationReason::ModelStop,
            error_code: None,
        }
    }

    /// step_name 返回冻结 step 名称
    pub fn step_name(&self) -> &'static str {
        match self {
            Self::CallModel { .. } => "call_model",
            Self::MessageDelta { .. } => "message_delta",
            Self::ClarifyUser { .. } => "clarify_user",
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
    pub citation_count: u32,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub output: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub fact_package: Option<Box<AiFactPackage>>,
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
            citation_count: 0,
            output: None,
            fact_package: None,
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
            citation_count: 0,
            output: Some(output.into()),
            fact_package: None,
            denied_reason: None,
            failed_reason: None,
            confirmation: None,
            failure: None,
            guardrail_message: None,
        }
    }

    /// succeeded_with_citations 构造带引用计数的成功工具结果
    pub fn succeeded_with_citations(
        tool_call: LlmToolCall,
        output: impl Into<String>,
        citation_count: u32,
    ) -> Self {
        Self {
            tool_call,
            status: LoopToolStatus::Succeeded,
            citation_count,
            output: Some(output.into()),
            fact_package: None,
            denied_reason: None,
            failed_reason: None,
            confirmation: None,
            failure: None,
            guardrail_message: None,
        }
    }

    /// succeeded_with_fact_package 构造携带完整事实包的成功工具结果
    /// 核心职责：
    /// - 保留模型可见 output
    /// - 同时携带后端 typed DTO 投影所需事实包
    pub fn succeeded_with_fact_package(
        tool_call: LlmToolCall,
        output: impl Into<String>,
        citation_count: u32,
        fact_package: AiFactPackage,
    ) -> Self {
        let mut result = Self::succeeded_with_citations(tool_call, output, citation_count);
        result.fact_package = Some(Box::new(fact_package));
        result
    }

    /// denied 构造拒绝工具结果
    pub fn denied(tool_call: LlmToolCall, reason: impl Into<String>) -> Self {
        Self {
            tool_call,
            status: LoopToolStatus::Denied,
            citation_count: 0,
            output: None,
            fact_package: None,
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
            citation_count: 0,
            output: None,
            fact_package: None,
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
            citation_count: 0,
            output: None,
            fact_package: None,
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
            citation_count: 0,
            output: None,
            fact_package: None,
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
