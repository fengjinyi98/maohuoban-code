use serde::{Deserialize, Serialize};
use uuid::Uuid;

use super::super::provider_error::ProviderErrorCategory;
use super::super::{AgentTurnStatus, LlmFinishReason, LlmToolCall, LlmUsage, ModelLabel};
use super::loop_tool_result::LoopToolResult;
use super::model_call_outcome::ModelCallOutcome;
use super::termination_reason::AgentTurnTerminationReason;

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
