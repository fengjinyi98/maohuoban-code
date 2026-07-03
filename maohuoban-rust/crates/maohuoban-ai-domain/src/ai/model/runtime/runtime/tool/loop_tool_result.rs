use serde::{Deserialize, Serialize};

use crate::ai::AiFactPackage;

use super::super::{AiToolConfirmationRequirement, LlmToolCall, ToolFailure};
use super::loop_tool_status::LoopToolStatus;

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
