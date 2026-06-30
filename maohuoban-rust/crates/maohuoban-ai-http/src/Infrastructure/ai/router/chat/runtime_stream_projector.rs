use std::collections::HashMap;

use maohuoban_ai_application::ai::output::visible_text_prefix_from_model_output;
use maohuoban_ai_application::ai::verifier::{AiAnswerVerificationContext, AiAnswerVerifier};
use maohuoban_ai_domain::ai::{
    AgentEvent, AgentToolStatus, AgentTurnId, AiFactPackage, AiStreamEvent, LlmFinishReason,
    LlmUsage, PROVIDER_USER_VISIBLE_FAILURE_MESSAGE, UserVisibleTurnEvent,
};
use uuid::Uuid;

use super::runtime_stream_helpers::{
    VerifiedCompletionInput, append_verified_completion, map_activity_status,
};

pub(super) struct AgentEventSseProjector {
    package: AiFactPackage,
    pet_name: String,
    latest_usage: LlmUsage,
    finish_reason: LlmFinishReason,
    tool_names_by_call_id: HashMap<String, String>,
    pending_delta_text: String,
    streamed_delta_text: String,
    suppress_model_delta: bool,
    identity_context_tool_required: bool,
    identity_context_tool_succeeded: bool,
}

impl AgentEventSseProjector {
    #[must_use]
    pub(super) fn new(
        _message_id: Uuid,
        fact_package: Option<AiFactPackage>,
        pet_name: &str,
        identity_context_tool_required: bool,
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
            identity_context_tool_required,
            identity_context_tool_succeeded: false,
        }
    }

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
        if tool_name == "load_pet_identity_context" && status == AgentToolStatus::Succeeded {
            self.identity_context_tool_succeeded = true;
        }
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
                VerifiedCompletionInput {
                    message_id,
                    final_text,
                    usage: self.latest_usage,
                    finish_reason: self.finish_reason,
                    package: &self.package,
                    verification_context: self.verification_context(),
                    streamed_delta_text: &self.streamed_delta_text,
                },
                &mut output,
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
        if visible_text.trim().is_empty() {
            return Vec::new();
        }
        if visible_text == self.streamed_delta_text
            || !visible_text.starts_with(&self.streamed_delta_text)
        {
            return Vec::new();
        }

        let verification = AiAnswerVerifier::new().verify_with_context(
            &visible_text,
            &self.package,
            self.verification_context(),
        );
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

    fn verification_context(&self) -> AiAnswerVerificationContext {
        AiAnswerVerificationContext {
            identity_context_tool_required: self.identity_context_tool_required,
            identity_context_tool_succeeded: self.identity_context_tool_succeeded,
        }
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
