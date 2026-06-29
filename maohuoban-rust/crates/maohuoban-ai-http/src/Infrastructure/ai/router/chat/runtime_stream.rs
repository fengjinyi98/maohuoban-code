use std::collections::HashMap;

use maohuoban_ai_application::ai::citations::citations_for_answer;
use maohuoban_ai_application::ai::output::visible_text_prefix_from_model_output;
use maohuoban_ai_application::ai::verifier::AiAnswerVerifier;
use maohuoban_ai_domain::ai::{
    AgentEvent, AgentToolStatus, AgentTurnId, AiAgentActivityStatus, AiError, AiFactPackage,
    AiStreamEvent, AiToolCallStatus, LlmFinishReason, LlmUsage,
    PROVIDER_USER_VISIBLE_FAILURE_MESSAGE, UserVisibleTurnEvent,
};
use uuid::Uuid;

/// AgentEventSseProjector Runtime 事件到 SSE 事件的增量投影器
/// 核心职责：
/// - 保留模型 usage、finish_reason 和工具 call_id 映射
/// - 支持 Runtime 事件到达后立即转换为前端可消费 SSE 事件
pub(super) struct AgentEventSseProjector {
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
        _message_id: Uuid,
        fact_package: Option<AiFactPackage>,
        pet_name: &str,
    ) -> Self {
        Self {
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
        let visible_events = self.project_user_visible(event);
        visible_events
            .into_iter()
            .flat_map(|event| self.project_sse(event))
            .collect()
    }

    fn project_user_visible(&mut self, event: AgentEvent) -> Vec<UserVisibleTurnEvent> {
        match event {
            AgentEvent::ModelCallFinished {
                finish_reason: reason,
                usage,
                ..
            } => {
                self.latest_usage = usage;
                self.finish_reason = reason;
                Vec::new()
            }
            AgentEvent::ToolStarted {
                turn_id,
                tool_call_id,
                tool_name,
                ..
            } => self.project_tool_started(turn_id, &tool_call_id, &tool_name),
            AgentEvent::ToolFinished {
                turn_id,
                tool_call_id,
                status,
                citation_count,
                ..
            } => self.project_tool_finished(turn_id, &tool_call_id, status, citation_count),
            AgentEvent::NeedsConfirmation {
                turn_id,
                confirmation_task_id,
                question_text,
                ..
            } => {
                vec![UserVisibleTurnEvent::ConfirmationTask {
                    turn_id,
                    confirmation_task_id,
                    question_text,
                }]
            }
            AgentEvent::MessageDelta { turn_id, text } => {
                self.project_message_delta(turn_id, &text)
            }
            AgentEvent::TurnFinished {
                turn_id,
                message_id,
                final_text,
                status,
            } => {
                vec![UserVisibleTurnEvent::AnswerCompleted {
                    turn_id,
                    message_id,
                    final_text,
                    status,
                }]
            }
            AgentEvent::ProviderError {
                turn_id,
                retryable,
                category,
                ..
            } => Self::project_error(turn_id, format!("ai.provider.{category:?}"), retryable),
            AgentEvent::TurnFailed {
                turn_id,
                error_code,
                retryable,
                ..
            } => Self::project_error(turn_id, error_code, retryable),
            AgentEvent::TurnStarted { .. }
            | AgentEvent::PolicyChecked { .. }
            | AgentEvent::ModelCallStarted { .. }
            | AgentEvent::NeedsClarification { .. } => Vec::new(),
        }
    }

    fn project_tool_started(
        &mut self,
        turn_id: AgentTurnId,
        tool_call_id: &str,
        tool_name: &str,
    ) -> Vec<UserVisibleTurnEvent> {
        let display_text = activity_text_for_tool(tool_name, &self.pet_name);
        self.tool_names_by_call_id
            .insert(tool_call_id.to_owned(), tool_name.to_owned());
        vec![UserVisibleTurnEvent::ExecutionTraceStarted {
            turn_id,
            display_text,
        }]
    }

    fn project_tool_finished(
        &mut self,
        turn_id: AgentTurnId,
        tool_call_id: &str,
        status: AgentToolStatus,
        citation_count: u32,
    ) -> Vec<UserVisibleTurnEvent> {
        let tool_name = self
            .tool_names_by_call_id
            .remove(tool_call_id)
            .unwrap_or_else(|| "runtime_tool".to_owned());
        let display_text = activity_text_for_tool(&tool_name, &self.pet_name);
        vec![UserVisibleTurnEvent::ExecutionTraceCompleted {
            turn_id,
            display_text,
            status,
            citation_count,
        }]
    }

    fn project_error(
        turn_id: AgentTurnId,
        code: String,
        retryable: bool,
    ) -> Vec<UserVisibleTurnEvent> {
        vec![UserVisibleTurnEvent::Error {
            turn_id,
            code,
            message: PROVIDER_USER_VISIBLE_FAILURE_MESSAGE.to_owned(),
            retryable,
        }]
    }

    fn project_sse(&mut self, event: UserVisibleTurnEvent) -> Vec<AiStreamEvent> {
        let mut output = Vec::new();
        match event {
            UserVisibleTurnEvent::ExecutionTraceStarted { display_text, .. } => {
                output.push(AiStreamEvent::ExecutionTraceStarted { display_text });
            }
            UserVisibleTurnEvent::ExecutionTraceCompleted {
                display_text,
                status,
                citation_count,
                ..
            } => output.push(AiStreamEvent::ExecutionTraceCompleted {
                display_text,
                status: map_activity_status(status),
                citation_count,
            }),
            UserVisibleTurnEvent::AnswerDelta { text, .. } => {
                output.push(AiStreamEvent::AnswerDelta { text });
            }
            UserVisibleTurnEvent::AnswerCompleted {
                message_id,
                final_text,
                ..
            } => append_verified_completion(
                &mut output,
                message_id,
                final_text,
                self.latest_usage,
                self.finish_reason,
                &self.package,
                &self.streamed_delta_text,
            ),
            UserVisibleTurnEvent::ConfirmationTask {
                confirmation_task_id,
                question_text,
                ..
            } => output.push(AiStreamEvent::ConfirmationTask {
                confirmation_task_id,
                question_text,
            }),
            UserVisibleTurnEvent::Error {
                code,
                message,
                retryable,
                ..
            } => output.push(AiStreamEvent::Error {
                code,
                message,
                retryable,
                blocked_reason: None,
                safe_fallback_text: Some("暂时无法获取回答，请稍后重试。".to_owned()),
            }),
        }
        output
    }

    /// project_message_delta 安全投影模型增量
    /// 核心职责：
    /// - 累积模型原始输出，避免 JSON 和违规内容提前透出
    /// - 仅在当前可见文本通过本地校验时输出用户可见 delta
    fn project_message_delta(
        &mut self,
        turn_id: AgentTurnId,
        text: &str,
    ) -> Vec<UserVisibleTurnEvent> {
        self.pending_delta_text.push_str(text);
        if self.suppress_model_delta {
            return Vec::new();
        }

        let Some(visible_text) = visible_text_prefix_from_model_output(&self.pending_delta_text)
        else {
            return Vec::new();
        };
        if visible_text == self.streamed_delta_text
            || !visible_text.starts_with(&self.streamed_delta_text)
        {
            return Vec::new();
        }

        let verification = AiAnswerVerifier::new().verify(&visible_text, &self.package);
        if verification.is_blocked() {
            self.suppress_model_delta = true;
            return Vec::new();
        }

        let delta_text = visible_text[self.streamed_delta_text.len()..].to_owned();
        self.streamed_delta_text.push_str(&delta_text);
        vec![UserVisibleTurnEvent::AnswerDelta {
            turn_id,
            text: delta_text,
        }]
    }
}

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

pub(super) fn sanitize_legacy_tool_call_event(
    event: AiStreamEvent,
    pet_name: &str,
) -> AiStreamEvent {
    match event {
        AiStreamEvent::ToolCall {
            tool_name,
            status,
            citation_count,
        } => AiStreamEvent::ExecutionTraceCompleted {
            display_text: activity_text_for_tool(&tool_name, pet_name),
            status: map_legacy_tool_call_status(status),
            citation_count,
        },
        event => event,
    }
}

fn activity_text_for_tool(tool_name: &str, pet_name: &str) -> String {
    match tool_name {
        "list_authorized_pet_candidates" => "正在确认宠物档案权限".to_owned(),
        "load_pet_identity_context" => format!("正在查看{pet_name}档案"),
        "load_pet_current_diet_context" => format!("正在查看{pet_name}近期饮食"),
        "load_food_inventory_change_hints" => format!("正在检查{pet_name}近期喂食线索"),
        "load_pet_diet_confirmation_candidates" => {
            format!("正在查看{pet_name}待确认喂食记录")
        }
        _ => format!("正在处理{pet_name}相关信息"),
    }
}

fn map_legacy_tool_call_status(status: AiToolCallStatus) -> AiAgentActivityStatus {
    match status {
        AiToolCallStatus::Started => AiAgentActivityStatus::Started,
        AiToolCallStatus::Allowed | AiToolCallStatus::Denied => AiAgentActivityStatus::Completed,
        AiToolCallStatus::Failed => AiAgentActivityStatus::Failed,
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

    if verification.is_blocked() {
        let safe_text = verification
            .safe_fallback_text
            .clone()
            .unwrap_or_else(|| "这次回答没有通过安全校验，请基于已确认事实重新提问。".to_owned());
        let citations = citations_for_answer(&safe_text, package);
        append_citations(output, citations.clone());
        output.push(AiStreamEvent::AnswerDelta {
            text: safe_text.clone(),
        });
        output.push(AiStreamEvent::AnswerCompleted {
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
        output.push(AiStreamEvent::AnswerDelta {
            text: final_text.clone(),
        });
    }
    output.push(AiStreamEvent::AnswerCompleted {
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

#[cfg(test)]
mod tests {
    use maohuoban_ai_domain::ai::{
        AgentEvent, AgentToolStatus, AgentTurnId, AgentTurnStatus, AiStreamEvent,
    };

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
                AiStreamEvent::AnswerDelta { text } => Some(text.as_str()),
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
                AiStreamEvent::AnswerDelta { text } => Some(text.as_str()),
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
                AiStreamEvent::AnswerDelta { text } => Some(text.as_str()),
                _ => None,
            })
            .collect();

        assert!(
            deltas.is_empty(),
            "completed event must not duplicate streamed answer_text"
        );
    }

    #[test]
    fn projector_scrubs_cross_chunk_thinking_and_internal_context_before_sse_delta() {
        let message_id = Uuid::new_v4();
        let turn_id = AgentTurnId::new();
        let mut projector = AgentEventSseProjector::new(message_id, None, "豆包");

        let chunks = [
            "<think>先看内部推理",
            "</think>{\"memory_context\":{\"pet_id\":\"hidden\"},\"answer_text\":\"",
            "豆包今天精神稳定",
            "。\",\"provider_raw\":{\"choices\":[]}}",
        ];

        let deltas: Vec<String> = chunks
            .into_iter()
            .flat_map(|text| {
                projector.project(AgentEvent::MessageDelta {
                    turn_id,
                    text: text.to_owned(),
                })
            })
            .filter_map(|event| match event {
                AiStreamEvent::AnswerDelta { text } => Some(text),
                _ => None,
            })
            .collect();

        assert_eq!(deltas.concat(), "豆包今天精神稳定。");
    }

    #[test]
    fn projector_emits_execution_trace_completed_before_answer_delta() {
        let message_id = Uuid::new_v4();
        let turn_id = AgentTurnId::new();
        let mut projector = AgentEventSseProjector::new(message_id, None, "豆包");

        let mut events = Vec::new();
        events.extend(projector.project(AgentEvent::ToolStarted {
            turn_id,
            tool_call_id: "call_1".to_owned(),
            tool_name: "load_pet_identity_context".to_owned(),
        }));
        events.extend(projector.project(AgentEvent::ToolFinished {
            turn_id,
            tool_call_id: "call_1".to_owned(),
            status: AgentToolStatus::Succeeded,
            citation_count: 1,
        }));
        events.extend(projector.project(AgentEvent::MessageDelta {
            turn_id,
            text: "豆包档案显示状态稳定。".to_owned(),
        }));
        events.extend(projector.project(AgentEvent::TurnFinished {
            turn_id,
            message_id,
            final_text: "豆包档案显示状态稳定。".to_owned(),
            status: AgentTurnStatus::Completed,
        }));

        let event_names: Vec<&str> = events.iter().map(AiStreamEvent::event_name).collect();
        assert_eq!(
            event_names,
            vec![
                "execution_trace_started",
                "execution_trace_completed",
                "answer_delta",
                "answer_completed"
            ]
        );

        let execution_trace_payloads: Vec<String> = events
            .iter()
            .filter(|event| {
                matches!(
                    event,
                    AiStreamEvent::ExecutionTraceStarted { .. }
                        | AiStreamEvent::ExecutionTraceCompleted { .. }
                )
            })
            .map(|event| serde_json::to_string(event).expect("serialize execution trace event"))
            .collect();

        assert!(!execution_trace_payloads.is_empty());
        for payload in execution_trace_payloads {
            assert!(
                !payload.contains("tool_name"),
                "user visible SSE must not expose tool_name: {payload}"
            );
            assert!(
                !payload.contains("tool_call_id"),
                "user visible SSE must not expose tool_call_id: {payload}"
            );
            assert!(
                !payload.contains("load_pet_identity_context"),
                "user visible SSE must not expose internal tool identifier: {payload}"
            );
        }
    }

    #[test]
    fn safe_execution_trace_event_for_tool_does_not_expose_internal_tool_name() {
        let event = safe_execution_trace_completed_for_tool("load_pet_identity_context", "豆包", 2);

        assert_eq!(event.event_name(), "execution_trace_completed");
        let payload = serde_json::to_string(&event).expect("serialize safe execution trace");
        assert!(payload.contains("正在查看豆包档案"));
        assert!(
            !payload.contains("tool_name"),
            "safe execution trace must not expose tool_name: {payload}"
        );
        assert!(
            !payload.contains("tool_call"),
            "safe execution trace must not expose legacy tool_call event: {payload}"
        );
        assert!(
            !payload.contains("load_pet_identity_context"),
            "safe execution trace must not expose internal tool identifier: {payload}"
        );
    }
}
