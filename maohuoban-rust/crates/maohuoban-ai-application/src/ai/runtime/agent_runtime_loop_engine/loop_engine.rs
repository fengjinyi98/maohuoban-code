use async_trait::async_trait;
use futures_util::StreamExt;
use maohuoban_ai_domain::ai::{
    AgentSessionState, AgentTurnTerminationReason, AiResult, LlmFinishReason, LlmStreamEvent,
    LlmUsage, LoopStep, ModelCallOutcome, ModelLabel,
};

use crate::ai::output::visible_text_from_model_output;
use crate::ai::planning::StepKind;

use super::super::{
    LoopEngine,
    agent_runtime_diagnostics::AgentRuntimeDiagnostics,
    runtime_phase::RuntimePhase,
    runtime_request::{build_request, request_tool_count},
    streaming_model_purpose::{StreamingModelPurpose, streaming_model_purpose_code},
    tool_messages::non_empty_string,
};
use super::{
    AgentRuntimeLoopEngine,
    model_stream::{empty_assistant_content_error, model_stream},
    output_guard::{OutputGuardDecision, evaluate_output_guard},
    replan::StreamingRetryRequest,
};

// LoopEngine::next 保持 Runtime 阶段迁移集中，便于审查模型流、工具执行和终态顺序。
#[allow(clippy::too_many_lines)]
#[async_trait]
impl LoopEngine for AgentRuntimeLoopEngine {
    fn engine_mode(&self) -> &'static str {
        "self_hosted"
    }

    async fn next(&mut self, state: &mut AgentSessionState) -> AiResult<Option<LoopStep>> {
        loop {
            match std::mem::replace(&mut self.phase, RuntimePhase::Model) {
                RuntimePhase::Model => {
                    self.current_round = 1;
                    self.accumulated_total_tokens = 0;
                    self.current_turn_successful_write_tools.clear();
                    let plan = self.plan_current_turn(state);
                    if let Some(plan) = plan.as_ref() {
                        self.record_planning_if_needed(state, plan);
                    }
                    let skill_bundle = plan
                        .as_ref()
                        .and_then(|_| self.current_skill_bundle_for_state(state));
                    self.record_planning_step(state, StepKind::ModelReason, None);
                    let mut request = build_request(
                        state,
                        self.fact_package.as_ref(),
                        self.registry.as_ref(),
                        skill_bundle.as_ref(),
                        None,
                        &[],
                        &[],
                    );
                    request.stream = true;
                    let tool_count = request_tool_count(&request);
                    AgentRuntimeDiagnostics::record_model_request_prepared(
                        state.chat_session_id,
                        "initial",
                        self.current_round,
                        &request,
                    );
                    let diagnostics_correlation = request.diagnostics_correlation.clone();
                    self.phase = RuntimePhase::StreamingModel {
                        stream: model_stream(self.provider.clone(), request.clone()),
                        request: Box::new(request),
                        purpose: StreamingModelPurpose::Initial,
                        accumulated_text: String::new(),
                        accumulated_reasoning_content: String::new(),
                        tool_calls: Vec::new(),
                        usage: LlmUsage::default(),
                        finish_reason: LlmFinishReason::Stop,
                        tool_count,
                        diagnostics_correlation,
                        retry_count: 0,
                    };
                }
                RuntimePhase::StreamingModel {
                    request,
                    mut stream,
                    purpose,
                    mut accumulated_text,
                    mut accumulated_reasoning_content,
                    mut tool_calls,
                    mut usage,
                    mut finish_reason,
                    tool_count,
                    diagnostics_correlation,
                    retry_count,
                } => {
                    if let Some(event) = stream.next().await {
                        let event = match event {
                            Ok(event) => event,
                            Err(error) => {
                                AgentRuntimeDiagnostics::record_model_stream_error(
                                    state.chat_session_id,
                                    &diagnostics_correlation,
                                    streaming_model_purpose_code(purpose),
                                    self.current_round,
                                    tool_count,
                                    &error,
                                );
                                if let Some(retry_phase) = self.replan_streaming_model_error(
                                    state,
                                    &error,
                                    StreamingRetryRequest {
                                        request: request.as_ref(),
                                        purpose,
                                        tool_count,
                                        diagnostics_correlation: &diagnostics_correlation,
                                        retry_count,
                                        retry_boundary_clear: accumulated_text.is_empty()
                                            && tool_calls.is_empty(),
                                    },
                                ) {
                                    self.phase = retry_phase;
                                    continue;
                                }
                                return Err(error);
                            }
                        };
                        match event {
                            LlmStreamEvent::Delta { content } => {
                                accumulated_text.push_str(&content);
                                let suppress_visible_delta = self.fact_package.is_some()
                                    || (accumulated_text.trim().is_empty()
                                        && content.trim().is_empty());
                                self.phase = RuntimePhase::StreamingModel {
                                    request,
                                    stream,
                                    purpose,
                                    accumulated_text,
                                    accumulated_reasoning_content,
                                    tool_calls,
                                    usage,
                                    finish_reason,
                                    tool_count,
                                    diagnostics_correlation,
                                    retry_count,
                                };
                                if suppress_visible_delta {
                                    continue;
                                }
                                return Ok(Some(LoopStep::MessageDelta { text: content }));
                            }
                            LlmStreamEvent::ReasoningDelta { content } => {
                                accumulated_reasoning_content.push_str(&content);
                                self.phase = RuntimePhase::StreamingModel {
                                    request,
                                    stream,
                                    purpose,
                                    accumulated_text,
                                    accumulated_reasoning_content,
                                    tool_calls,
                                    usage,
                                    finish_reason,
                                    tool_count,
                                    diagnostics_correlation,
                                    retry_count,
                                };
                                continue;
                            }
                            LlmStreamEvent::ToolCall { tool_call } => {
                                tool_calls.push(tool_call);
                                self.phase = RuntimePhase::StreamingModel {
                                    request,
                                    stream,
                                    purpose,
                                    accumulated_text,
                                    accumulated_reasoning_content,
                                    tool_calls,
                                    usage,
                                    finish_reason,
                                    tool_count,
                                    diagnostics_correlation,
                                    retry_count,
                                };
                                continue;
                            }
                            LlmStreamEvent::Finish {
                                finish_reason: fr,
                                usage: u,
                            } => {
                                finish_reason = fr;
                                usage = u;
                                self.phase = RuntimePhase::StreamingModel {
                                    request,
                                    stream,
                                    purpose,
                                    accumulated_text,
                                    accumulated_reasoning_content,
                                    tool_calls,
                                    usage,
                                    finish_reason,
                                    tool_count,
                                    diagnostics_correlation,
                                    retry_count,
                                };
                                continue;
                            }
                            LlmStreamEvent::Error { message } => {
                                return Err(maohuoban_ai_domain::ai::AiError::Infrastructure(
                                    message,
                                ));
                            }
                        }
                    }

                    self.accumulated_total_tokens = self
                        .accumulated_total_tokens
                        .saturating_add(usage.total_tokens);
                    AgentRuntimeDiagnostics::record_loop_round_completed(
                        state.chat_session_id,
                        &diagnostics_correlation,
                        streaming_model_purpose_code(purpose),
                        self.current_round,
                        tool_calls.len(),
                        match finish_reason {
                            LlmFinishReason::Stop => "stop",
                            LlmFinishReason::Length => "length",
                            LlmFinishReason::ToolCalls => "tool_calls",
                            LlmFinishReason::ContentFilter => "content_filter",
                            LlmFinishReason::Error => "error",
                        },
                        &usage,
                        self.accumulated_total_tokens,
                    );

                    if tool_calls.is_empty() {
                        let visible_text = visible_text_from_model_output(&accumulated_text);
                        if visible_text.trim().is_empty() {
                            return Err(empty_assistant_content_error());
                        }
                        self.record_planning_step(
                            state,
                            StepKind::FinalizeAnswer,
                            Some((StepKind::ModelReason, StepKind::FinalizeAnswer)),
                        );
                        self.phase = match evaluate_output_guard(
                            state,
                            self.fact_package.as_ref(),
                            &visible_text,
                            0,
                            &self.current_turn_successful_write_tools,
                        ) {
                            OutputGuardDecision::Accept => RuntimePhase::Done {
                                message_id: uuid::Uuid::new_v4(),
                                final_text: visible_text,
                                status: maohuoban_ai_domain::ai::AgentTurnStatus::Completed,
                                termination_reason: AgentTurnTerminationReason::ModelStop,
                                error_code: None,
                            },
                            OutputGuardDecision::Repair { request, attempt } => {
                                RuntimePhase::OutputRepairModel { request, attempt }
                            }
                            OutputGuardDecision::Fail => RuntimePhase::Done {
                                message_id: uuid::Uuid::new_v4(),
                                final_text: String::new(),
                                status: maohuoban_ai_domain::ai::AgentTurnStatus::Failed,
                                termination_reason: AgentTurnTerminationReason::OutputGuardFailed,
                                error_code: Some("ai.output_guard.unrepaired".to_owned()),
                            },
                        };
                        return Ok(Some(LoopStep::CallModel {
                            model_label: ModelLabel::Primary,
                            tool_count,
                            outcome: ModelCallOutcome::Finished {
                                finish_reason,
                                usage,
                                provider: "runtime_stream".to_owned(),
                                model: ModelLabel::Primary.as_str().to_owned(),
                            },
                        }));
                    }

                    self.phase = RuntimePhase::ToolExecution {
                        assistant_reasoning_content: non_empty_string(
                            accumulated_reasoning_content,
                        ),
                        assistant_tool_calls: tool_calls.clone(),
                        tool_calls: tool_calls.clone(),
                        completed_tool_rounds: self.current_round.saturating_sub(1),
                    };
                    return Ok(Some(LoopStep::CallModel {
                        model_label: ModelLabel::Primary,
                        tool_count,
                        outcome: ModelCallOutcome::Finished {
                            finish_reason,
                            usage,
                            provider: "runtime_stream".to_owned(),
                            model: ModelLabel::Primary.as_str().to_owned(),
                        },
                    }));
                }
                RuntimePhase::ToolExecution {
                    assistant_reasoning_content,
                    assistant_tool_calls,
                    tool_calls,
                    completed_tool_rounds,
                } => {
                    return self
                        .advance_tool_execution_phase(
                            state,
                            assistant_reasoning_content,
                            assistant_tool_calls,
                            tool_calls,
                            completed_tool_rounds,
                        )
                        .await;
                }
                RuntimePhase::FollowupModel {
                    assistant_reasoning_content,
                    assistant_tool_calls,
                    tool_results,
                    completed_tool_rounds,
                } => {
                    if completed_tool_rounds > self.max_tool_rounds {
                        self.phase = RuntimePhase::Done {
                            message_id: uuid::Uuid::new_v4(),
                            final_text: String::new(),
                            status: maohuoban_ai_domain::ai::AgentTurnStatus::Completed,
                            termination_reason: AgentTurnTerminationReason::MaxToolRounds,
                            error_code: None,
                        };
                        continue;
                    }
                    let skill_bundle = self.current_skill_bundle_for_state(state);
                    self.current_round = completed_tool_rounds.saturating_add(1);
                    let mut request = build_request(
                        state,
                        self.fact_package.as_ref(),
                        self.registry.as_ref(),
                        skill_bundle.as_ref(),
                        assistant_reasoning_content.as_deref(),
                        &assistant_tool_calls,
                        &tool_results,
                    );
                    request.stream = true;
                    let tool_count = request_tool_count(&request);
                    AgentRuntimeDiagnostics::record_model_request_prepared(
                        state.chat_session_id,
                        "followup",
                        self.current_round,
                        &request,
                    );
                    let diagnostics_correlation = request.diagnostics_correlation.clone();
                    self.phase = RuntimePhase::StreamingModel {
                        stream: model_stream(self.provider.clone(), request.clone()),
                        request: Box::new(request),
                        purpose: StreamingModelPurpose::Followup,
                        accumulated_text: String::new(),
                        accumulated_reasoning_content: String::new(),
                        tool_calls: Vec::new(),
                        usage: LlmUsage::default(),
                        finish_reason: LlmFinishReason::Stop,
                        tool_count,
                        diagnostics_correlation,
                        retry_count: 0,
                    };
                }
                RuntimePhase::OutputRepairModel { request, attempt } => {
                    let response = self.provider.complete(&request).await?;
                    let visible_text = visible_text_from_model_output(&response.message.content);
                    if visible_text.trim().is_empty() {
                        return Err(empty_assistant_content_error());
                    }
                    self.phase = match evaluate_output_guard(
                        state,
                        self.fact_package.as_ref(),
                        &visible_text,
                        attempt,
                        &self.current_turn_successful_write_tools,
                    ) {
                        OutputGuardDecision::Accept => RuntimePhase::Done {
                            message_id: uuid::Uuid::new_v4(),
                            final_text: visible_text,
                            status: maohuoban_ai_domain::ai::AgentTurnStatus::Completed,
                            termination_reason: AgentTurnTerminationReason::ModelStop,
                            error_code: None,
                        },
                        OutputGuardDecision::Repair { request, attempt } => {
                            RuntimePhase::OutputRepairModel { request, attempt }
                        }
                        OutputGuardDecision::Fail => RuntimePhase::Done {
                            message_id: uuid::Uuid::new_v4(),
                            final_text: String::new(),
                            status: maohuoban_ai_domain::ai::AgentTurnStatus::Failed,
                            termination_reason: AgentTurnTerminationReason::OutputGuardFailed,
                            error_code: Some("ai.output_guard.unrepaired".to_owned()),
                        },
                    };
                    return Ok(Some(LoopStep::CallModel {
                        model_label: ModelLabel::Primary,
                        tool_count: 0,
                        outcome: ModelCallOutcome::Finished {
                            finish_reason: response.finish_reason,
                            usage: response.usage,
                            provider: response.provider,
                            model: response.model,
                        },
                    }));
                }
                RuntimePhase::ClarifyUser {
                    reason,
                    suggested_actions,
                } => {
                    self.phase = RuntimePhase::Done {
                        message_id: uuid::Uuid::new_v4(),
                        final_text: String::new(),
                        status: maohuoban_ai_domain::ai::AgentTurnStatus::AwaitingClarification,
                        termination_reason: AgentTurnTerminationReason::AwaitingClarification,
                        error_code: None,
                    };
                    return Ok(Some(LoopStep::clarify_user(reason, suggested_actions)));
                }
                RuntimePhase::Done {
                    message_id,
                    final_text,
                    status,
                    termination_reason,
                    error_code,
                } => {
                    AgentRuntimeDiagnostics::record_turn_terminated(
                        state.chat_session_id,
                        match termination_reason {
                            AgentTurnTerminationReason::ModelStop => "model_stop",
                            AgentTurnTerminationReason::MaxToolRounds => "max_tool_rounds",
                            AgentTurnTerminationReason::AwaitingClarification => {
                                "awaiting_clarification"
                            }
                            AgentTurnTerminationReason::OutputGuardFailed => "output_guard_failed",
                        },
                        self.current_round,
                        match status {
                            maohuoban_ai_domain::ai::AgentTurnStatus::Running => "running",
                            maohuoban_ai_domain::ai::AgentTurnStatus::Completed => "completed",
                            maohuoban_ai_domain::ai::AgentTurnStatus::Failed => "failed",
                            maohuoban_ai_domain::ai::AgentTurnStatus::Interrupted => "interrupted",
                            maohuoban_ai_domain::ai::AgentTurnStatus::AwaitingConfirmation => {
                                "awaiting_confirmation"
                            }
                            maohuoban_ai_domain::ai::AgentTurnStatus::AwaitingClarification => {
                                "awaiting_clarification"
                            }
                        },
                        self.accumulated_total_tokens,
                    );
                    return Ok(Some(LoopStep::Done {
                        message_id,
                        final_text,
                        status,
                        termination_reason,
                        error_code,
                    }));
                }
            }
        }
    }
}
