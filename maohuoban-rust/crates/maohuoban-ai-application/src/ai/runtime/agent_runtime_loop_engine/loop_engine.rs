use async_trait::async_trait;
use futures_util::StreamExt;
use maohuoban_ai_domain::ai::{
    AgentSessionState, AiResult, LlmFinishReason, LlmStreamEvent, LlmUsage, LoopStep,
    ModelCallOutcome, ModelLabel,
};

use crate::ai::output::visible_text_from_model_output;
use crate::ai::planning::StepKind;

use super::super::{
    LoopEngine,
    agent_runtime_diagnostics::AgentRuntimeDiagnostics,
    evidence_planner::EvidencePlanner,
    followup_grounding::FollowupGrounding,
    runtime_phase::RuntimePhase,
    runtime_request::{build_request, request_tool_count},
    streaming_model_purpose::{StreamingModelPurpose, streaming_model_purpose_code},
    tool_messages::non_empty_string,
};
use super::{
    AgentRuntimeLoopEngine,
    model_stream::{empty_assistant_content_error, model_stream},
    planning::ensure_workflow_policy_supports_plan,
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
                    if let Some(final_text) =
                        FollowupGrounding::grounded_response(state, self.fact_package.as_ref())
                    {
                        self.phase = RuntimePhase::Done {
                            message_id: uuid::Uuid::new_v4(),
                            final_text,
                            status: maohuoban_ai_domain::ai::AgentTurnStatus::Completed,
                        };
                        continue;
                    }
                    let already_prefetched =
                        self.evidence_prefetched_turn_id == state.current_turn_id;
                    let evidence_tool_calls = if already_prefetched {
                        Vec::new()
                    } else {
                        EvidencePlanner::plan(state, self.registry.as_ref())
                    };
                    let plan = self.plan_current_turn(state, evidence_tool_calls.len());
                    if let Some(plan) = plan.as_ref() {
                        self.record_planning_if_needed(state, plan);
                        if plan.policy().requires_clarification() {
                            self.record_planning_step(state, StepKind::ClarifyUser, None);
                            self.phase = RuntimePhase::Done {
                                message_id: uuid::Uuid::new_v4(),
                                final_text: String::new(),
                                status:
                                    maohuoban_ai_domain::ai::AgentTurnStatus::AwaitingClarification,
                            };
                            return Ok(Some(LoopStep::clarify_user(
                                "用户描述缺少可行动观察信息",
                                vec![
                                    "补充症状持续时间".to_owned(),
                                    "补充精神、食欲和排便变化".to_owned(),
                                ],
                            )));
                        }
                    }
                    let skill_bundle = plan
                        .as_ref()
                        .and_then(|_| self.current_skill_bundle_for_state(state));
                    if let (Some(plan), Some(skill_bundle)) = (plan.as_ref(), skill_bundle.as_ref())
                    {
                        ensure_workflow_policy_supports_plan(plan, skill_bundle)?;
                    }
                    let requires_evidence = plan
                        .as_ref()
                        .is_none_or(|plan| plan.policy().requires_evidence());
                    if requires_evidence && !evidence_tool_calls.is_empty() {
                        self.record_planning_step(
                            state,
                            StepKind::PrefetchEvidence,
                            Some((StepKind::LoadContext, StepKind::PrefetchEvidence)),
                        );
                        self.evidence_prefetched_turn_id = state.current_turn_id;
                        self.phase = RuntimePhase::EvidenceToolExecution {
                            assistant_tool_calls: evidence_tool_calls.clone(),
                            tool_calls: evidence_tool_calls,
                        };
                        continue;
                    }

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
                    let requires_confirmation = matches!(purpose, StreamingModelPurpose::Initial)
                        && self.current_plan_requires_confirmation(state);
                    if let Some(event) = stream.next().await {
                        let event = match event {
                            Ok(event) => event,
                            Err(error) => {
                                AgentRuntimeDiagnostics::record_model_stream_error(
                                    state.chat_session_id,
                                    &diagnostics_correlation,
                                    streaming_model_purpose_code(purpose),
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
                                let suppress_visible_delta = requires_confirmation
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

                    if tool_calls.is_empty() || matches!(purpose, StreamingModelPurpose::Followup) {
                        if requires_confirmation && tool_calls.is_empty() {
                            self.record_planning_step(
                                state,
                                StepKind::ToolWritePrepare,
                                Some((StepKind::ModelReason, StepKind::ToolWritePrepare)),
                            );
                            self.phase = RuntimePhase::ClarifyUser {
                                reason: "写入请求缺少确认工具调用".to_owned(),
                                suggested_actions: vec![
                                    "确认要写入的宠物和记录内容".to_owned(),
                                    "重新提交写入请求".to_owned(),
                                ],
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
                        let visible_text = visible_text_from_model_output(&accumulated_text);
                        if visible_text.trim().is_empty() {
                            return Err(empty_assistant_content_error());
                        }
                        self.record_planning_step(
                            state,
                            StepKind::FinalizeAnswer,
                            Some((StepKind::ModelReason, StepKind::FinalizeAnswer)),
                        );
                        self.phase = RuntimePhase::Done {
                            message_id: uuid::Uuid::new_v4(),
                            final_text: visible_text,
                            status: maohuoban_ai_domain::ai::AgentTurnStatus::Completed,
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

                    if requires_confirmation {
                        self.record_planning_step(
                            state,
                            StepKind::ToolWritePrepare,
                            Some((StepKind::ModelReason, StepKind::ToolWritePrepare)),
                        );
                    }
                    self.phase = RuntimePhase::ToolExecution {
                        assistant_reasoning_content: non_empty_string(
                            accumulated_reasoning_content,
                        ),
                        assistant_tool_calls: tool_calls.clone(),
                        tool_calls: tool_calls.clone(),
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
                } => {
                    return self
                        .advance_tool_execution_phase(
                            state,
                            assistant_reasoning_content,
                            assistant_tool_calls,
                            tool_calls,
                        )
                        .await;
                }
                RuntimePhase::EvidenceToolExecution {
                    assistant_tool_calls,
                    tool_calls,
                } => {
                    return self
                        .advance_evidence_tool_execution_phase(
                            state,
                            assistant_tool_calls,
                            tool_calls,
                        )
                        .await;
                }
                RuntimePhase::FollowupModel {
                    assistant_reasoning_content,
                    assistant_tool_calls,
                    tool_results,
                } => {
                    let skill_bundle = self.current_skill_bundle_for_state(state);
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
                RuntimePhase::ClarifyUser {
                    reason,
                    suggested_actions,
                } => {
                    self.phase = RuntimePhase::Done {
                        message_id: uuid::Uuid::new_v4(),
                        final_text: String::new(),
                        status: maohuoban_ai_domain::ai::AgentTurnStatus::AwaitingClarification,
                    };
                    return Ok(Some(LoopStep::clarify_user(reason, suggested_actions)));
                }
                RuntimePhase::Done {
                    message_id,
                    final_text,
                    status,
                } => {
                    return Ok(Some(LoopStep::Done {
                        message_id,
                        final_text,
                        status,
                    }));
                }
            }
        }
    }
}
