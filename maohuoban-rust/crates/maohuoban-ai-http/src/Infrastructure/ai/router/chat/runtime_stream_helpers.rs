use maohuoban_ai_application::ai::citations::citations_for_answer;
use maohuoban_ai_application::ai::verifier::{AiAnswerVerificationContext, AiAnswerVerifier};
use maohuoban_ai_domain::ai::{
    AgentToolStatus, AiAgentActivityStatus, AiError, AiFactPackage, AiStreamEvent,
    AiToolCallStatus, LlmFinishReason, LlmUsage,
};
use uuid::Uuid;

use super::content_block_projector::project_pet_profile_content_blocks;
use super::runtime_activity_text::activity_text_for_tool;

pub(super) fn safe_execution_trace_completed_for_tool(
    tool_name: &str,
    pet_name: &str,
    citation_count: u32,
) -> AiStreamEvent {
    AiStreamEvent::ExecutionTraceCompleted {
        display_text: activity_text_for_tool(tool_name, pet_name),
        status: AiAgentActivityStatus::Completed,
        citation_count,
    }
}

pub(super) fn sanitize_tool_call_event(event: AiStreamEvent, pet_name: &str) -> AiStreamEvent {
    match event {
        AiStreamEvent::ToolCall {
            tool_name,
            status,
            citation_count,
        } => AiStreamEvent::ExecutionTraceCompleted {
            display_text: activity_text_for_tool(&tool_name, pet_name),
            status: map_tool_call_status(status),
            citation_count,
        },
        event => event,
    }
}

pub(super) fn ai_error_to_sse_event(error: &AiError) -> AiStreamEvent {
    AiStreamEvent::Error {
        code: error.stable_code().to_owned(),
        message: error.user_visible_message().to_owned(),
        retryable: error.is_retryable(),
        blocked_reason: None,
        safe_fallback_text: Some("暂时无法获取回答，请稍后重试。".to_owned()),
    }
}

pub(super) fn map_activity_status(status: AgentToolStatus) -> AiAgentActivityStatus {
    match status {
        AgentToolStatus::Succeeded | AgentToolStatus::Denied => AiAgentActivityStatus::Completed,
        AgentToolStatus::Failed => AiAgentActivityStatus::Failed,
    }
}

pub(super) struct VerifiedCompletionInput<'a> {
    pub message_id: Uuid,
    pub final_text: String,
    pub usage: LlmUsage,
    pub finish_reason: LlmFinishReason,
    pub package: &'a AiFactPackage,
    pub verification_context: AiAnswerVerificationContext,
    pub streamed_delta_text: &'a str,
}

/// `append_missing_profile_blocks_error` 追加宠物资料卡契约错误事件
/// 核心职责：
/// - 阻止身份资料卡流程用空内容块完成
/// - 暴露稳定错误码供前后端联调定位协议缺口
pub(super) fn append_missing_profile_blocks_error(output: &mut Vec<AiStreamEvent>) {
    output.push(AiStreamEvent::Error {
        code: "ai.profile_content_blocks.missing".to_owned(),
        message: "宠物资料卡内容块缺失。".to_owned(),
        retryable: false,
        blocked_reason: None,
        safe_fallback_text: None,
    });
}

pub(super) fn append_verified_completion(
    input: VerifiedCompletionInput<'_>,
    output: &mut Vec<AiStreamEvent>,
) {
    let verification = AiAnswerVerifier::new().verify_with_context(
        &input.final_text,
        input.package,
        input.verification_context,
    );

    if verification.is_blocked() {
        output.push(AiStreamEvent::Error {
            code: "ai.output_guard.unrepaired".to_owned(),
            message: "最终回答未通过输出校验。".to_owned(),
            retryable: true,
            blocked_reason: verification.blocked_reason,
            safe_fallback_text: None,
        });
        return;
    }

    let citations = citations_for_answer(&input.final_text, input.package);
    let content_blocks = project_pet_profile_content_blocks(input.package);
    append_citations(output, citations.clone());
    if input.streamed_delta_text != input.final_text {
        output.push(AiStreamEvent::AnswerDelta {
            text: input.final_text.clone(),
        });
    }
    output.push(AiStreamEvent::AnswerCompleted {
        message_id: input.message_id,
        final_text: input.final_text,
        content_blocks,
        usage: input.usage,
        finish_reason: input.finish_reason,
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

fn map_tool_call_status(status: AiToolCallStatus) -> AiAgentActivityStatus {
    match status {
        AiToolCallStatus::Started => AiAgentActivityStatus::Started,
        AiToolCallStatus::Allowed | AiToolCallStatus::Denied => AiAgentActivityStatus::Completed,
        AiToolCallStatus::Failed => AiAgentActivityStatus::Failed,
    }
}
