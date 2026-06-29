use std::collections::HashMap;

use maohuoban_ai_application::ai::citations::citations_for_answer;
use maohuoban_ai_application::ai::output::visible_text_prefix_from_model_output;
use maohuoban_ai_application::ai::verifier::AiAnswerVerifier;
use maohuoban_ai_domain::ai::{
    AgentEvent, AgentToolStatus, AiAgentActivityStatus, AiError, AiFactPackage, AiStreamEvent,
    AiToolCallStatus, LlmFinishReason, LlmUsage, PROVIDER_USER_VISIBLE_FAILURE_MESSAGE,
};
use uuid::Uuid;

/// AI_STREAM_TRACE_DEBUG_TAG 流式链路临时诊断标识
const AI_STREAM_TRACE_DEBUG_TAG: &str = "[DEBUG:AiStreamTrace]";

/// AgentEventSseProjector Runtime 事件到 SSE 事件的增量投影器
/// 核心职责：
/// - 保留模型 usage、finish_reason 和工具 call_id 映射
/// - 支持 Runtime 事件到达后立即转换为前端可消费 SSE 事件
pub(super) struct AgentEventSseProjector {
    message_id: Uuid,
    package: AiFactPackage,
    pet_name: String,
    latest_usage: LlmUsage,
    finish_reason: LlmFinishReason,
    tool_names_by_call_id: HashMap<String, String>,
    pending_delta_text: String,
    streamed_delta_text: String,
    suppress_model_delta: bool,
}

impl AgentEventSseProjector {
    /// new 构造 Runtime SSE 增量投影器
    #[must_use]
    pub(super) fn new(
        message_id: Uuid,
        fact_package: Option<AiFactPackage>,
        pet_name: &str,
    ) -> Self {
        Self {
            message_id,
            package: fact_package.unwrap_or_else(AiFactPackage::empty),
            pet_name: pet_name.to_owned(),
            latest_usage: LlmUsage::default(),
            finish_reason: LlmFinishReason::Stop,
            tool_names_by_call_id: HashMap::new(),
            pending_delta_text: String::new(),
            streamed_delta_text: String::new(),
            suppress_model_delta: false,
        }
    }

    /// project 转换单个 Runtime 事件
    /// 核心职责：
    /// - 对状态事件更新内部上下文
    /// - 对可见事件返回 0 到多个 SSE 事件
    pub(super) fn project(&mut self, event: AgentEvent) -> Vec<AiStreamEvent> {
        let mut output = Vec::new();
        match event {
            AgentEvent::ModelCallFinished {
                finish_reason: reason,
                usage,
                ..
            } => {
                self.latest_usage = usage;
                self.finish_reason = reason;
            }
            AgentEvent::ToolStarted {
                tool_call_id,
                tool_name,
                ..
            } => {
                push_tool_started_sse_events(
                    &mut output,
                    &mut self.tool_names_by_call_id,
                    tool_call_id,
                    tool_name,
                    &self.pet_name,
                );
            }
            AgentEvent::ToolFinished {
                tool_call_id,
                status,
                citation_count,
                ..
            } => {
                push_tool_finished_sse_events(
                    &mut output,
                    &mut self.tool_names_by_call_id,
                    &tool_call_id,
                    status,
                    citation_count,
                    &self.pet_name,
                );
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
                self.project_message_delta(&mut output, &text);
            }
            AgentEvent::TurnFinished { final_text, .. } => {
                append_verified_completion(
                    &mut output,
                    self.message_id,
                    final_text,
                    self.latest_usage,
                    self.finish_reason,
                    &self.package,
                    &self.streamed_delta_text,
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

        output
    }

    /// project_message_delta 安全投影模型增量
    /// 核心职责：
    /// - 累积模型原始输出，避免 JSON 和违规内容提前透出
    /// - 仅在当前可见文本通过本地校验时输出用户可见 delta
    fn project_message_delta(&mut self, output: &mut Vec<AiStreamEvent>, text: &str) {
        self.pending_delta_text.push_str(text);
        eprintln!(
            "{AI_STREAM_TRACE_DEBUG_TAG} projector_delta_received message_id_prefix={} raw_delta_chars={} pending_chars={} streamed_chars={}",
            uuid_prefix(&self.message_id),
            text.chars().count(),
            self.pending_delta_text.chars().count(),
            self.streamed_delta_text.chars().count()
        );
        if self.suppress_model_delta {
            eprintln!(
                "{AI_STREAM_TRACE_DEBUG_TAG} projector_delta_suppressed message_id_prefix={} reason=already_suppressed pending_chars={} streamed_chars={}",
                uuid_prefix(&self.message_id),
                self.pending_delta_text.chars().count(),
                self.streamed_delta_text.chars().count()
            );
            return;
        }

        let Some(visible_text) = visible_text_prefix_from_model_output(&self.pending_delta_text)
        else {
            eprintln!(
                "{AI_STREAM_TRACE_DEBUG_TAG} projector_delta_buffered message_id_prefix={} reason=visible_text_pending pending_chars={} streamed_chars={}",
                uuid_prefix(&self.message_id),
                self.pending_delta_text.chars().count(),
                self.streamed_delta_text.chars().count()
            );
            return;
        };
        if visible_text == self.streamed_delta_text
            || !visible_text.starts_with(&self.streamed_delta_text)
        {
            eprintln!(
                "{AI_STREAM_TRACE_DEBUG_TAG} projector_delta_buffered message_id_prefix={} reason=no_new_visible_text pending_chars={} visible_chars={} streamed_chars={}",
                uuid_prefix(&self.message_id),
                self.pending_delta_text.chars().count(),
                visible_text.chars().count(),
                self.streamed_delta_text.chars().count()
            );
            return;
        }

        let verification = AiAnswerVerifier::new().verify(&visible_text, &self.package);
        if verification.is_blocked() {
            self.suppress_model_delta = true;
            eprintln!(
                "{AI_STREAM_TRACE_DEBUG_TAG} projector_delta_suppressed message_id_prefix={} reason=verification_blocked pending_chars={} visible_chars={}",
                uuid_prefix(&self.message_id),
                self.pending_delta_text.chars().count(),
                visible_text.chars().count()
            );
            return;
        }

        let delta_text = visible_text[self.streamed_delta_text.len()..].to_owned();
        self.streamed_delta_text.push_str(&delta_text);
        eprintln!(
            "{AI_STREAM_TRACE_DEBUG_TAG} projector_delta_emitted message_id_prefix={} emitted_chars={} streamed_chars={} pending_chars={}",
            uuid_prefix(&self.message_id),
            delta_text.chars().count(),
            self.streamed_delta_text.chars().count(),
            self.pending_delta_text.chars().count()
        );
        output.push(AiStreamEvent::Delta { text: delta_text });
    }
}

/// push_tool_started_sse_events 投影 Runtime 工具开始事件
/// 核心职责：
/// - 记录 tool_call_id 与工具名映射
/// - 输出 UI 安全活动文案和兼容工具状态
fn push_tool_started_sse_events(
    output: &mut Vec<AiStreamEvent>,
    tool_names_by_call_id: &mut HashMap<String, String>,
    tool_call_id: String,
    tool_name: String,
    pet_name: &str,
) {
    tool_names_by_call_id.insert(tool_call_id, tool_name.clone());
    output.push(AiStreamEvent::AgentActivity {
        display_text: activity_text_for_tool(&tool_name, pet_name),
        status: AiAgentActivityStatus::Started,
    });
    output.push(AiStreamEvent::ToolCall {
        tool_name,
        status: AiToolCallStatus::Started,
        citation_count: 0,
    });
}

/// push_tool_finished_sse_events 投影 Runtime 工具结束事件
/// 核心职责：
/// - 恢复工具名并输出兼容工具状态
/// - 输出活动完成或失败状态供 UI 清理过程态
fn push_tool_finished_sse_events(
    output: &mut Vec<AiStreamEvent>,
    tool_names_by_call_id: &mut HashMap<String, String>,
    tool_call_id: &str,
    status: AgentToolStatus,
    citation_count: u32,
    pet_name: &str,
) {
    let tool_name = tool_names_by_call_id
        .remove(tool_call_id)
        .unwrap_or_else(|| "runtime_tool".to_owned());
    output.push(AiStreamEvent::ToolCall {
        tool_name: tool_name.clone(),
        status: map_tool_status(status),
        citation_count,
    });
    output.push(AiStreamEvent::AgentActivity {
        display_text: activity_text_for_tool(&tool_name, pet_name),
        status: map_activity_status(status),
    });
}

fn activity_text_for_tool(tool_name: &str, pet_name: &str) -> String {
    match tool_name {
        "load_pet_identity_context" => format!("正在查看{pet_name}档案"),
        "load_pet_current_diet_context" => format!("正在查看{pet_name}近期饮食"),
        "load_food_inventory_change_hints" => format!("正在检查{pet_name}近期喂食线索"),
        "load_pet_diet_confirmation_candidates" => {
            format!("正在查看{pet_name}待确认喂食记录")
        }
        _ => format!("正在处理{pet_name}相关信息"),
    }
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

fn map_activity_status(status: AgentToolStatus) -> AiAgentActivityStatus {
    match status {
        AgentToolStatus::Succeeded | AgentToolStatus::Denied => AiAgentActivityStatus::Completed,
        AgentToolStatus::Failed => AiAgentActivityStatus::Failed,
    }
}

fn append_verified_completion(
    output: &mut Vec<AiStreamEvent>,
    message_id: Uuid,
    final_text: String,
    usage: LlmUsage,
    finish_reason: LlmFinishReason,
    package: &AiFactPackage,
    streamed_delta_text: &str,
) {
    let verification = AiAnswerVerifier::new().verify(&final_text, package);
    eprintln!(
        "{AI_STREAM_TRACE_DEBUG_TAG} projector_completion_checked message_id_prefix={} final_chars={} streamed_chars={} verification_blocked={}",
        uuid_prefix(&message_id),
        final_text.chars().count(),
        streamed_delta_text.chars().count(),
        verification.is_blocked()
    );

    if verification.is_blocked() {
        let safe_text = verification
            .safe_fallback_text
            .clone()
            .unwrap_or_else(|| "这次回答没有通过安全校验，请基于已确认事实重新提问。".to_owned());
        let citations = citations_for_answer(&safe_text, package);
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

    let citations = citations_for_answer(&final_text, package);
    append_citations(output, citations.clone());
    if streamed_delta_text != final_text {
        eprintln!(
            "{AI_STREAM_TRACE_DEBUG_TAG} projector_completion_delta_emitted message_id_prefix={} reason=streamed_text_mismatch final_chars={} streamed_chars={}",
            uuid_prefix(&message_id),
            final_text.chars().count(),
            streamed_delta_text.chars().count()
        );
        output.push(AiStreamEvent::Delta {
            text: final_text.clone(),
        });
    }
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

/// uuid_prefix 生成临时诊断用短 ID
/// 核心职责：
/// - 缩短日志中的 message 标识
/// - 避免输出完整业务 ID
fn uuid_prefix(id: &Uuid) -> String {
    id.to_string().chars().take(8).collect()
}

#[cfg(test)]
mod tests {
    use maohuoban_ai_domain::ai::{AgentEvent, AgentTurnId, AgentTurnStatus, AiStreamEvent};

    use super::*;

    #[test]
    fn projector_streams_json_answer_text_incrementally_without_json_fields() {
        let message_id = Uuid::new_v4();
        let turn_id = AgentTurnId::new();
        let mut projector = AgentEventSseProjector::new(message_id, None, "豆包");

        let first_events = projector.project(AgentEvent::MessageDelta {
            turn_id,
            text: "{\"answer_text\":\"豆包精神".to_owned(),
        });
        let first_deltas: Vec<&str> = first_events
            .iter()
            .filter_map(|event| match event {
                AiStreamEvent::Delta { text } => Some(text.as_str()),
                _ => None,
            })
            .collect();

        assert_eq!(first_deltas, vec!["豆包精神"]);

        let second_events = projector.project(AgentEvent::MessageDelta {
            turn_id,
            text: "正常。\",\"display_blocks\":[]}".to_owned(),
        });
        let second_deltas: Vec<&str> = second_events
            .iter()
            .filter_map(|event| match event {
                AiStreamEvent::Delta { text } => Some(text.as_str()),
                _ => None,
            })
            .collect();

        assert_eq!(second_deltas, vec!["正常。"]);

        let completed_events = projector.project(AgentEvent::TurnFinished {
            turn_id,
            message_id,
            final_text: "豆包精神正常。".to_owned(),
            status: AgentTurnStatus::Completed,
        });
        let deltas: Vec<&str> = completed_events
            .iter()
            .filter_map(|event| match event {
                AiStreamEvent::Delta { text } => Some(text.as_str()),
                _ => None,
            })
            .collect();

        assert!(
            deltas.is_empty(),
            "completed event must not duplicate streamed answer_text"
        );
    }
}
