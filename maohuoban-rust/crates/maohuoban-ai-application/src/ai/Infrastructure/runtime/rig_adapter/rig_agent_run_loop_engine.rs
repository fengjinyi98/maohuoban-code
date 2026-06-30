use std::collections::BTreeSet;
use std::sync::Arc;

use async_trait::async_trait;
use futures_util::{StreamExt, stream::BoxStream};
use maohuoban_ai_domain::ai::{
    AgentSessionState, AgentTurnId, AgentTurnStatus, AiFactPackage, AiResult, LlmChatRequest,
    LlmFinishReason, LlmMessage, LlmRole, LlmStreamEvent, LlmToolCall, LlmUsage, LoopStep,
    LoopToolResult, LoopToolStatus, ModelCallOutcome, ModelLabel,
};
use rig_core::OneOrMany;
use rig_core::agent::run::{AgentRun, AgentRunStep, ModelTurn, ModelTurnOutcome, PendingToolCall};
use rig_core::completion::Usage as RigUsage;
use rig_core::message::{AssistantContent, ToolResultContent, UserContent};

use crate::ai::guardrail::{GuardrailDecision, ToolCallGuardrail};
use crate::ai::output::visible_text_from_model_output;
use crate::ai::ports::LlmProvider;
use crate::ai::prompt::AiPromptBuilder;
use crate::ai::runtime::LoopEngine;

use super::super::agent_runtime_loop_engine::{
    execute_tool_calls, model_stream, non_empty_string, prefetched_tool_context_message,
    request_tool_count, tool_result_to_message,
};
use super::super::agent_runtime_request_policy::AgentRuntimeRequestPolicy;
use super::super::evidence_planner::EvidencePlanner;
use super::super::workbench_prompt_projection::workbench_context_prompt;
use crate::ai::tools::{AiToolContext, ToolRegistry};

/// RigAgentRunLoopEngine Rig AgentRun 驱动的 LoopEngine
/// 核心职责：
/// - 使用 Rig sans-IO AgentRun 管理模型与工具步骤
/// - 通过自有 LlmProvider、ToolRegistry 和 Policy Guard 执行真实 IO
/// - 将 Rig 状态统一转换为自有 LoopStep
pub struct RigAgentRunLoopEngine {
    provider: Arc<dyn LlmProvider>,
    registry: Arc<ToolRegistry>,
    tool_context: AiToolContext,
    fact_package: Option<AiFactPackage>,
    guardrail: ToolCallGuardrail,
    phase: RigAgentRunPhase,
    evidence_prefetched_turn_id: Option<AgentTurnId>,
}

enum RigAgentRunPhase {
    Preparing {
        run: Option<AgentRun>,
        assistant_reasoning_content: Option<String>,
        assistant_tool_calls: Vec<LlmToolCall>,
        tool_results: Vec<LoopToolResult>,
    },
    StreamingModel {
        run: AgentRun,
        stream: BoxStream<'static, AiResult<LlmStreamEvent>>,
        accumulated_text: String,
        accumulated_reasoning_content: String,
        tool_calls: Vec<LlmToolCall>,
        usage: LlmUsage,
        finish_reason: LlmFinishReason,
        tool_count: u32,
        tool_names: BTreeSet<String>,
    },
    ToolRequest {
        run: AgentRun,
        assistant_reasoning_content: Option<String>,
        calls: Vec<PendingToolCall>,
    },
    ToolExecution {
        run: AgentRun,
        assistant_reasoning_content: Option<String>,
        assistant_tool_calls: Vec<LlmToolCall>,
        tool_calls: Vec<LlmToolCall>,
    },
    EvidenceToolExecution {
        run: AgentRun,
        assistant_tool_calls: Vec<LlmToolCall>,
        tool_calls: Vec<LlmToolCall>,
    },
    Done {
        message_id: uuid::Uuid,
        final_text: String,
        status: AgentTurnStatus,
    },
}

impl RigAgentRunLoopEngine {
    /// new 构造 Rig AgentRun LoopEngine
    #[must_use]
    pub fn new(
        provider: Arc<dyn LlmProvider>,
        registry: Arc<ToolRegistry>,
        tool_context: AiToolContext,
        fact_package: Option<AiFactPackage>,
    ) -> Self {
        Self {
            provider,
            registry,
            tool_context,
            fact_package,
            guardrail: ToolCallGuardrail::new(),
            phase: RigAgentRunPhase::Preparing {
                run: None,
                assistant_reasoning_content: None,
                assistant_tool_calls: Vec::new(),
                tool_results: Vec::new(),
            },
            evidence_prefetched_turn_id: None,
        }
    }

    fn build_messages(
        &self,
        state: &AgentSessionState,
        assistant_reasoning_content: Option<&str>,
        assistant_tool_calls: &[LlmToolCall],
        tool_results: &[LoopToolResult],
        visible_tools: &[maohuoban_ai_domain::ai::LlmToolSchema],
    ) -> Vec<LlmMessage> {
        let user_message = state.user_inputs.last().cloned().unwrap_or_default();
        let mut messages =
            AiPromptBuilder::new().build_messages(&user_message, &[], self.fact_package.as_ref());

        if let Some(workbench) = state.workbench.as_ref() {
            let user_msg_index = messages.len().saturating_sub(1);
            let mut pre_user_messages = vec![LlmMessage {
                role: LlmRole::System,
                content: workbench_context_prompt(workbench, visible_tools),
                reasoning_content: None,
                tool_call_id: None,
                tool_calls: Vec::new(),
            }];

            if let Some(pack) = workbench.recent_conversation_pack.as_ref() {
                pre_user_messages.extend(pack.to_messages());
            }

            for (offset, msg) in pre_user_messages.into_iter().enumerate() {
                messages.insert(user_msg_index + offset, msg);
            }
        }

        if !assistant_tool_calls.is_empty() {
            messages.push(LlmMessage {
                role: LlmRole::Assistant,
                content: String::new(),
                reasoning_content: assistant_reasoning_content.map(str::to_owned),
                tool_call_id: None,
                tool_calls: assistant_tool_calls.to_vec(),
            });
        } else if !tool_results.is_empty() {
            messages.push(prefetched_tool_context_message(tool_results));
        }

        if !assistant_tool_calls.is_empty() {
            for tool_result in tool_results {
                messages.push(tool_result_to_message(tool_result));
            }
        }

        messages
    }

    fn build_request(
        &self,
        state: &AgentSessionState,
        assistant_reasoning_content: Option<&str>,
        assistant_tool_calls: &[LlmToolCall],
        tool_results: &[LoopToolResult],
    ) -> LlmChatRequest {
        let is_followup_answer = !assistant_tool_calls.is_empty() || !tool_results.is_empty();
        let tools = if is_followup_answer {
            Vec::new()
        } else {
            AgentRuntimeRequestPolicy::visible_tool_schemas(self.registry.as_ref(), state)
        };
        let response_format = AgentRuntimeRequestPolicy::response_format_for_model_phase(
            is_followup_answer,
            tools.is_empty(),
        );
        let messages = self.build_messages(
            state,
            assistant_reasoning_content,
            assistant_tool_calls,
            tool_results,
            &tools,
        );

        LlmChatRequest {
            model: "primary".to_owned(),
            messages,
            tools,
            tool_choice: None,
            temperature: 0.2,
            stream: true,
            max_output_tokens: None,
            response_format,
        }
    }
}

#[async_trait]
impl LoopEngine for RigAgentRunLoopEngine {
    fn engine_mode(&self) -> &'static str {
        "rig_poc"
    }

    #[allow(clippy::too_many_lines)]
    async fn next(&mut self, state: &mut AgentSessionState) -> AiResult<Option<LoopStep>> {
        loop {
            match std::mem::replace(
                &mut self.phase,
                RigAgentRunPhase::Preparing {
                    run: None,
                    assistant_reasoning_content: None,
                    assistant_tool_calls: Vec::new(),
                    tool_results: Vec::new(),
                },
            ) {
                RigAgentRunPhase::Preparing {
                    run,
                    assistant_reasoning_content,
                    assistant_tool_calls,
                    tool_results,
                } => {
                    let mut run = run.unwrap_or_else(|| {
                        let prompt = state.user_inputs.last().cloned().unwrap_or_default();
                        AgentRun::new(prompt).max_turns(4)
                    });

                    if assistant_tool_calls.is_empty()
                        && tool_results.is_empty()
                        && self.evidence_prefetched_turn_id != state.current_turn_id
                    {
                        let evidence_tool_calls =
                            EvidencePlanner::plan(state, self.registry.as_ref());
                        if !evidence_tool_calls.is_empty() {
                            self.evidence_prefetched_turn_id = state.current_turn_id;
                            self.phase = RigAgentRunPhase::EvidenceToolExecution {
                                run,
                                assistant_tool_calls: evidence_tool_calls.clone(),
                                tool_calls: evidence_tool_calls,
                            };
                            continue;
                        }
                    }

                    match run.next_step().map_err(rig_error)? {
                        AgentRunStep::CallModel { .. } => {
                            let request = self.build_request(
                                state,
                                assistant_reasoning_content.as_deref(),
                                &assistant_tool_calls,
                                &tool_results,
                            );
                            let tool_count = request_tool_count(&request);
                            let tool_names =
                                request.tools.iter().map(|tool| tool.name.clone()).collect();
                            mhb_temp_backend_log(format!(
                                "tag=AgentFallbackRegression stage=rig.model_request session_id={} messages={} tools={} response_format_present={} assistant_tool_calls={} tool_results={}",
                                state.chat_session_id,
                                request.messages.len(),
                                request.tools.len(),
                                request.response_format.is_some(),
                                assistant_tool_calls.len(),
                                tool_results.len(),
                            ));
                            self.phase = RigAgentRunPhase::StreamingModel {
                                run,
                                stream: model_stream(self.provider.clone(), request),
                                accumulated_text: String::new(),
                                accumulated_reasoning_content: String::new(),
                                tool_calls: Vec::new(),
                                usage: LlmUsage::default(),
                                finish_reason: LlmFinishReason::Stop,
                                tool_count,
                                tool_names,
                            };
                        }
                        AgentRunStep::CallTools { calls } => {
                            self.phase = RigAgentRunPhase::ToolRequest {
                                run,
                                assistant_reasoning_content,
                                calls,
                            };
                        }
                        AgentRunStep::Done(response) => {
                            let final_text = visible_text_from_model_output(&response.output);
                            self.phase = RigAgentRunPhase::Done {
                                message_id: uuid::Uuid::new_v4(),
                                final_text,
                                status: AgentTurnStatus::Completed,
                            };
                        }
                    }
                }
                RigAgentRunPhase::StreamingModel {
                    mut run,
                    mut stream,
                    mut accumulated_text,
                    mut accumulated_reasoning_content,
                    mut tool_calls,
                    mut usage,
                    mut finish_reason,
                    tool_count,
                    tool_names,
                } => {
                    if let Some(event) = stream.next().await {
                        let event = match event {
                            Ok(event) => event,
                            Err(error) => {
                                mhb_temp_backend_log(format!(
                                    "tag=AgentFallbackRegression stage=rig.provider_error session_id={} code={} retryable={} message={}",
                                    state.chat_session_id,
                                    error.stable_code(),
                                    error.is_retryable(),
                                    temp_sanitize_error(&error.to_string()),
                                ));
                                return Err(error);
                            }
                        };
                        match event {
                            LlmStreamEvent::Delta { content } => {
                                accumulated_text.push_str(&content);
                                mhb_temp_backend_log(format!(
                                    "tag=AgentFallbackRegression stage=rig.provider_delta session_id={} chunk_chars={} chunk_trimmed_empty={} accumulated_chars={}",
                                    state.chat_session_id,
                                    content.chars().count(),
                                    content.trim().is_empty(),
                                    accumulated_text.chars().count(),
                                ));
                                self.phase = RigAgentRunPhase::StreamingModel {
                                    run,
                                    stream,
                                    accumulated_text,
                                    accumulated_reasoning_content,
                                    tool_calls,
                                    usage,
                                    finish_reason,
                                    tool_count,
                                    tool_names,
                                };
                                return Ok(Some(LoopStep::MessageDelta { text: content }));
                            }
                            LlmStreamEvent::ReasoningDelta { content } => {
                                accumulated_reasoning_content.push_str(&content);
                                self.phase = RigAgentRunPhase::StreamingModel {
                                    run,
                                    stream,
                                    accumulated_text,
                                    accumulated_reasoning_content,
                                    tool_calls,
                                    usage,
                                    finish_reason,
                                    tool_count,
                                    tool_names,
                                };
                                continue;
                            }
                            LlmStreamEvent::ToolCall { tool_call } => {
                                mhb_temp_backend_log(format!(
                                    "tag=AgentFallbackRegression stage=rig.provider_tool_call session_id={} name={} args_chars={}",
                                    state.chat_session_id,
                                    tool_call.name,
                                    tool_call.arguments.chars().count(),
                                ));
                                tool_calls.push(tool_call);
                                self.phase = RigAgentRunPhase::StreamingModel {
                                    run,
                                    stream,
                                    accumulated_text,
                                    accumulated_reasoning_content,
                                    tool_calls,
                                    usage,
                                    finish_reason,
                                    tool_count,
                                    tool_names,
                                };
                                continue;
                            }
                            LlmStreamEvent::Finish {
                                finish_reason: fr,
                                usage: u,
                            } => {
                                mhb_temp_backend_log(format!(
                                    "tag=AgentFallbackRegression stage=rig.provider_finish session_id={} finish_reason={fr:?} input_tokens={} output_tokens={} accumulated_chars={} tool_calls={}",
                                    state.chat_session_id,
                                    u.input_tokens,
                                    u.output_tokens,
                                    accumulated_text.chars().count(),
                                    tool_calls.len(),
                                ));
                                finish_reason = fr;
                                usage = u;
                                self.phase = RigAgentRunPhase::StreamingModel {
                                    run,
                                    stream,
                                    accumulated_text,
                                    accumulated_reasoning_content,
                                    tool_calls,
                                    usage,
                                    finish_reason,
                                    tool_count,
                                    tool_names,
                                };
                                continue;
                            }
                            LlmStreamEvent::Error { message } => {
                                mhb_temp_backend_log(format!(
                                    "tag=AgentFallbackRegression stage=rig.provider_stream_error_event session_id={} message={}",
                                    state.chat_session_id,
                                    temp_sanitize_error(&message),
                                ));
                                return Err(maohuoban_ai_domain::ai::AiError::Infrastructure(
                                    message,
                                ));
                            }
                        }
                    }

                    let assistant_content =
                        assistant_content_from_stream(&accumulated_text, &tool_calls);
                    let visible_text = visible_text_from_model_output(&accumulated_text);
                    mhb_temp_backend_log(format!(
                        "tag=AgentFallbackRegression stage=rig.stream_end session_id={} accumulated_chars={} visible_chars={} visible_trimmed_empty={} tool_calls={}",
                        state.chat_session_id,
                        accumulated_text.chars().count(),
                        visible_text.chars().count(),
                        visible_text.trim().is_empty(),
                        tool_calls.len(),
                    ));
                    let outcome = run
                        .model_response(ModelTurn::new(
                            None,
                            assistant_content,
                            rig_usage(usage),
                            tool_names.clone(),
                            tool_names,
                        ))
                        .map_err(rig_error)?;
                    ensure_model_turn_continue(&outcome)?;

                    self.phase = RigAgentRunPhase::Preparing {
                        run: Some(run),
                        assistant_reasoning_content: non_empty_string(
                            accumulated_reasoning_content,
                        ),
                        assistant_tool_calls: tool_calls.clone(),
                        tool_results: Vec::new(),
                    };
                    return Ok(Some(LoopStep::CallModel {
                        model_label: ModelLabel::Primary,
                        tool_count,
                        outcome: ModelCallOutcome::Finished {
                            finish_reason,
                            usage,
                            provider: "rig_agent_run_stream".to_owned(),
                            model: ModelLabel::Primary.as_str().to_owned(),
                        },
                    }));
                }
                RigAgentRunPhase::ToolRequest {
                    run,
                    assistant_reasoning_content,
                    calls,
                } => {
                    let tool_calls = calls.iter().map(llm_tool_call_from_pending).collect();
                    self.phase = RigAgentRunPhase::ToolExecution {
                        run,
                        assistant_reasoning_content,
                        assistant_tool_calls: tool_calls,
                        tool_calls: calls.iter().map(llm_tool_call_from_pending).collect(),
                    };
                }
                RigAgentRunPhase::ToolExecution {
                    mut run,
                    assistant_reasoning_content,
                    assistant_tool_calls,
                    tool_calls,
                } => {
                    if !tool_calls.is_empty() {
                        self.phase = RigAgentRunPhase::ToolExecution {
                            run,
                            assistant_reasoning_content,
                            assistant_tool_calls,
                            tool_calls: Vec::new(),
                        };
                        return Ok(Some(LoopStep::call_tools(tool_calls)));
                    }

                    let (tool_results, hard_stop) = execute_tool_calls(
                        self.registry.clone(),
                        self.tool_context.clone(),
                        assistant_tool_calls.clone(),
                        &mut self.guardrail,
                    )
                    .await;

                    if let Some(GuardrailDecision::HardStop {
                        safe_user_message, ..
                    }) = hard_stop
                    {
                        self.phase = RigAgentRunPhase::Done {
                            message_id: uuid::Uuid::new_v4(),
                            final_text: safe_user_message,
                            status: AgentTurnStatus::Failed,
                        };
                        return Ok(Some(LoopStep::CallTools { tool_results }));
                    }

                    let needs_confirmation = tool_results.iter().any(|result| {
                        matches!(result.status, LoopToolStatus::RequiresConfirmation)
                    });

                    if needs_confirmation {
                        self.phase = RigAgentRunPhase::Done {
                            message_id: uuid::Uuid::new_v4(),
                            final_text: String::new(),
                            status: AgentTurnStatus::AwaitingConfirmation,
                        };
                    } else {
                        run.tool_results(rig_tool_results(&tool_results))
                            .map_err(rig_error)?;
                        self.phase = RigAgentRunPhase::Preparing {
                            run: Some(run),
                            assistant_reasoning_content,
                            assistant_tool_calls,
                            tool_results: tool_results.clone(),
                        };
                    }

                    return Ok(Some(LoopStep::CallTools { tool_results }));
                }
                RigAgentRunPhase::EvidenceToolExecution {
                    run,
                    assistant_tool_calls,
                    tool_calls,
                } => {
                    if !tool_calls.is_empty() {
                        self.phase = RigAgentRunPhase::EvidenceToolExecution {
                            run,
                            assistant_tool_calls,
                            tool_calls: Vec::new(),
                        };
                        return Ok(Some(LoopStep::call_tools(tool_calls)));
                    }

                    let (tool_results, hard_stop) = execute_tool_calls(
                        self.registry.clone(),
                        self.tool_context.clone(),
                        assistant_tool_calls.clone(),
                        &mut self.guardrail,
                    )
                    .await;

                    if let Some(GuardrailDecision::HardStop {
                        safe_user_message, ..
                    }) = hard_stop
                    {
                        self.phase = RigAgentRunPhase::Done {
                            message_id: uuid::Uuid::new_v4(),
                            final_text: safe_user_message,
                            status: AgentTurnStatus::Failed,
                        };
                        return Ok(Some(LoopStep::CallTools { tool_results }));
                    }

                    let needs_confirmation = tool_results.iter().any(|result| {
                        matches!(result.status, LoopToolStatus::RequiresConfirmation)
                    });

                    if needs_confirmation {
                        self.phase = RigAgentRunPhase::Done {
                            message_id: uuid::Uuid::new_v4(),
                            final_text: String::new(),
                            status: AgentTurnStatus::AwaitingConfirmation,
                        };
                    } else {
                        self.phase = RigAgentRunPhase::Preparing {
                            run: Some(run),
                            assistant_reasoning_content: None,
                            assistant_tool_calls: Vec::new(),
                            tool_results: tool_results.clone(),
                        };
                    }

                    return Ok(Some(LoopStep::CallTools { tool_results }));
                }
                RigAgentRunPhase::Done {
                    message_id,
                    final_text,
                    status,
                } => {
                    mhb_temp_backend_log(format!(
                        "tag=AgentFallbackRegression stage=rig.done session_id={} message_id={} status={status:?} final_chars={} final_trimmed_empty={}",
                        state.chat_session_id,
                        message_id,
                        final_text.chars().count(),
                        final_text.trim().is_empty(),
                    ));
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

fn assistant_content_from_stream(
    accumulated_text: &str,
    tool_calls: &[LlmToolCall],
) -> OneOrMany<AssistantContent> {
    let mut items = Vec::new();
    let visible_text = visible_text_from_model_output(accumulated_text);
    if !visible_text.is_empty() {
        items.push(AssistantContent::text(visible_text));
    }
    items.extend(tool_calls.iter().map(|tool_call| {
        AssistantContent::tool_call(
            tool_call.id.clone(),
            tool_call.name.clone(),
            serde_json::from_str(&tool_call.arguments)
                .unwrap_or_else(|_| serde_json::Value::Object(serde_json::Map::new())),
        )
    }));

    OneOrMany::many(items).unwrap_or_else(|_| OneOrMany::one(AssistantContent::text("")))
}

fn llm_tool_call_from_pending(call: &PendingToolCall) -> LlmToolCall {
    LlmToolCall {
        id: call.tool_call.id.clone(),
        name: call.tool_call.function.name.clone(),
        arguments: call.tool_call.function.arguments.to_string(),
    }
}

fn rig_tool_results(tool_results: &[LoopToolResult]) -> Vec<UserContent> {
    tool_results
        .iter()
        .map(|result| {
            let message = tool_result_to_message(result);
            UserContent::tool_result(
                result.tool_call.id.clone(),
                OneOrMany::one(ToolResultContent::text(message.content)),
            )
        })
        .collect()
}

fn rig_usage(usage: LlmUsage) -> RigUsage {
    RigUsage {
        input_tokens: u64::from(usage.input_tokens),
        output_tokens: u64::from(usage.output_tokens),
        total_tokens: u64::from(usage.total_tokens),
        cached_input_tokens: 0,
        cache_creation_input_tokens: 0,
        tool_use_prompt_tokens: 0,
        reasoning_tokens: 0,
    }
}

fn ensure_model_turn_continue(outcome: &ModelTurnOutcome) -> AiResult<()> {
    match outcome {
        ModelTurnOutcome::Continue { .. } | ModelTurnOutcome::TurnRetried => Ok(()),
        ModelTurnOutcome::NeedsResolution(_) => {
            Err(maohuoban_ai_domain::ai::AiError::Infrastructure(
                "rig agent run needs invalid tool-call resolution".to_owned(),
            ))
        }
    }
}

fn rig_error(error: impl std::fmt::Display) -> maohuoban_ai_domain::ai::AiError {
    maohuoban_ai_domain::ai::AiError::Infrastructure(format!("rig agent run error: {error}"))
}

// MHB_TEMP_BACKEND_LOG: AgentFallbackRegression 临时后端日志，确认修复后删除。
fn mhb_temp_backend_log(line: impl AsRef<str>) {
    use std::io::Write;

    let path = std::env::var("MHB_BACKEND_TEMP_LOG")
        .unwrap_or_else(|_| "work/debug/AgentFallbackRegression.log".to_owned());
    if let Some(parent) = std::path::Path::new(&path).parent() {
        let _ = std::fs::create_dir_all(parent);
    }
    if let Ok(mut file) = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(&path)
    {
        let _ = writeln!(file, "{}", line.as_ref());
    }
}

fn temp_sanitize_error(message: &str) -> String {
    message
        .chars()
        .take(160)
        .map(|ch| if ch.is_control() { ' ' } else { ch })
        .collect()
}
