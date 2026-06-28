use std::collections::HashMap;

use maohuoban_ai_application::ai::verifier::AiAnswerVerifier;
use maohuoban_ai_domain::ai::{
    AgentEvent, AgentToolStatus, AiError, AiFactPackage, AiStreamEvent, AiToolCallStatus,
    LlmFinishReason, LlmUsage, PROVIDER_USER_VISIBLE_FAILURE_MESSAGE,
};
use uuid::Uuid;

/// agent_events_to_sse_events 将 Runtime 事件转换为 iOS SSE 事件
/// 核心职责：
/// - 保持现有 AiStreamEvent 协议不变
/// - 对最终回答执行事实校验并输出引用
pub(super) fn agent_events_to_sse_events(
    events: Vec<AgentEvent>,
    message_id: Uuid,
    fact_package: Option<AiFactPackage>,
) -> Vec<AiStreamEvent> {
    let package = fact_package.unwrap_or_else(AiFactPackage::empty);
    let mut output = Vec::new();
    let mut latest_usage = LlmUsage::default();
    let mut finish_reason = LlmFinishReason::Stop;
    let mut tool_names_by_call_id = HashMap::new();

    for event in events {
        match event {
            AgentEvent::ModelCallFinished {
                finish_reason: reason,
                usage,
                ..
            } => {
                latest_usage = usage;
                finish_reason = reason;
            }
            AgentEvent::ToolStarted {
                tool_call_id,
                tool_name,
                ..
            } => {
                tool_names_by_call_id.insert(tool_call_id, tool_name.clone());
                output.push(AiStreamEvent::ToolCall {
                    tool_name,
                    status: AiToolCallStatus::Started,
                    citation_count: 0,
                });
            }
            AgentEvent::ToolFinished {
                tool_call_id,
                status,
                citation_count,
                ..
            } => {
                let tool_name = tool_names_by_call_id
                    .remove(&tool_call_id)
                    .unwrap_or_else(|| "runtime_tool".to_owned());
                output.push(AiStreamEvent::ToolCall {
                    tool_name,
                    status: map_tool_status(status),
                    citation_count,
                });
            }
            AgentEvent::NeedsConfirmation {
                confirmation_task_id,
                question_text,
                ..
            } => {
                output.push(AiStreamEvent::ConfirmationTask {
                    confirmation_task_id,
                    question_text,
                });
            }
            AgentEvent::MessageDelta { text, .. } => {
                output.push(AiStreamEvent::Delta { text });
            }
            AgentEvent::TurnFinished { final_text, .. } => {
                append_verified_completion(
                    &mut output,
                    message_id,
                    final_text,
                    latest_usage,
                    finish_reason,
                    &package,
                );
            }
            AgentEvent::ProviderError {
                retryable,
                category,
                ..
            } => {
                output.push(AiStreamEvent::Error {
                    code: format!("ai.provider.{category:?}"),
                    message: PROVIDER_USER_VISIBLE_FAILURE_MESSAGE.to_owned(),
                    retryable,
                    blocked_reason: None,
                    safe_fallback_text: Some("暂时无法获取回答，请稍后重试。".to_owned()),
                });
            }
            AgentEvent::TurnFailed {
                error_code,
                retryable,
                ..
            } => {
                output.push(AiStreamEvent::Error {
                    code: error_code,
                    message: PROVIDER_USER_VISIBLE_FAILURE_MESSAGE.to_owned(),
                    retryable,
                    blocked_reason: None,
                    safe_fallback_text: Some("暂时无法获取回答，请稍后重试。".to_owned()),
                });
            }
            AgentEvent::TurnStarted { .. }
            | AgentEvent::PolicyChecked { .. }
            | AgentEvent::ModelCallStarted { .. }
            | AgentEvent::NeedsClarification { .. } => {}
        }
    }

    output
}

/// ai_error_to_sse_event 将应用错误转换为稳定 SSE 错误
/// 核心职责：
/// - 复用 AiError 的稳定错误码和用户可见文案
pub(super) fn ai_error_to_sse_event(error: &AiError) -> AiStreamEvent {
    AiStreamEvent::Error {
        code: error.stable_code().to_owned(),
        message: error.user_visible_message().to_owned(),
        retryable: error.is_retryable(),
        blocked_reason: None,
        safe_fallback_text: Some("暂时无法获取回答，请稍后重试。".to_owned()),
    }
}

fn map_tool_status(status: AgentToolStatus) -> AiToolCallStatus {
    match status {
        AgentToolStatus::Succeeded => AiToolCallStatus::Allowed,
        AgentToolStatus::Denied => AiToolCallStatus::Denied,
        AgentToolStatus::Failed => AiToolCallStatus::Failed,
    }
}

fn append_verified_completion(
    output: &mut Vec<AiStreamEvent>,
    message_id: Uuid,
    final_text: String,
    usage: LlmUsage,
    finish_reason: LlmFinishReason,
    package: &AiFactPackage,
) {
    let citations = package.citations.clone();
    let verification = AiAnswerVerifier::new().verify(&final_text, package);

    if verification.is_blocked() {
        let safe_text = verification
            .safe_fallback_text
            .clone()
            .unwrap_or_else(|| "这次回答没有通过安全校验，请基于已确认事实重新提问。".to_owned());
        append_citations(output, citations.clone());
        output.push(AiStreamEvent::Delta {
            text: safe_text.clone(),
        });
        output.push(AiStreamEvent::MessageCompleted {
            message_id,
            final_text: safe_text,
            usage,
            finish_reason: LlmFinishReason::ContentFilter,
            citations,
            verification,
        });
        return;
    }

    append_citations(output, citations.clone());
    output.push(AiStreamEvent::Delta {
        text: final_text.clone(),
    });
    output.push(AiStreamEvent::MessageCompleted {
        message_id,
        final_text,
        usage,
        finish_reason,
        citations,
        verification,
    });
}

fn append_citations(
    output: &mut Vec<AiStreamEvent>,
    citations: Vec<maohuoban_ai_domain::ai::AiCitation>,
) {
    for citation in citations {
        output.push(AiStreamEvent::Citation { citation });
    }
}
