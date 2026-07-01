// MHB_STRUCTURE_EXEMPTION: ai/runtime 为既有 Agent Runtime 目录；本次只追加可观测点，后续 code-structure P1 统一迁移到 Infrastructure/Services 分层目录。
use std::sync::Arc;

use crate::ai::guardrail::{GuardrailDecision, ToolCallGuardrail};
use crate::ai::output::visible_text_from_model_output;
use crate::ai::ports::LlmProvider;
use crate::ai::tools::{AiToolContext, ToolRegistry};
use async_trait::async_trait;
use futures_util::{StreamExt, stream::BoxStream};
use maohuoban_ai_domain::ai::{
    AgentSessionState, AgentTurnId, AiError, AiFactPackage, AiResult, LlmChatRequest,
    LlmFinishReason, LlmStreamEvent, LlmUsage, LoopStep, LoopToolStatus, ModelCallOutcome,
    ModelLabel, ProviderError, ProviderErrorCategory,
};

use super::agent_runtime_diagnostics::AgentRuntimeDiagnostics;
use super::{
    LoopEngine,
    evidence_planner::EvidencePlanner,
    runtime_phase::RuntimePhase,
    runtime_request::{build_request, request_tool_count},
    streaming_model_purpose::{StreamingModelPurpose, streaming_model_purpose_code},
    tool_executor::execute_tool_calls,
    tool_messages::non_empty_string,
};

/// AgentRuntimeLoopEngine 毛球 Agent Runtime loop 实现
/// 核心职责：
/// - 组装模型请求、工具执行和结果回灌
/// - 保持 Tool Gateway、Provider 和 Runtime 可替换
/// - 集成 ToolCallGuardrail 防止工具循环
pub struct AgentRuntimeLoopEngine {
    provider: Arc<dyn LlmProvider>,
    registry: Arc<ToolRegistry>,
    tool_context: AiToolContext,
    fact_package: Option<AiFactPackage>,
    guardrail: ToolCallGuardrail,
    phase: RuntimePhase,
    evidence_prefetched_turn_id: Option<AgentTurnId>,
}

impl AgentRuntimeLoopEngine {
    /// new 构造 runtime loop
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
            phase: RuntimePhase::Model,
            evidence_prefetched_turn_id: None,
        }
    }
}

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
                    let already_prefetched =
                        self.evidence_prefetched_turn_id == state.current_turn_id;
                    let evidence_tool_calls = if already_prefetched {
                        Vec::new()
                    } else {
                        EvidencePlanner::plan(state, self.registry.as_ref())
                    };
                    if !evidence_tool_calls.is_empty() {
                        self.evidence_prefetched_turn_id = state.current_turn_id;
                        self.phase = RuntimePhase::EvidenceToolExecution {
                            assistant_tool_calls: evidence_tool_calls.clone(),
                            tool_calls: evidence_tool_calls,
                        };
                        continue;
                    }

                    let mut request = build_request(
                        state,
                        self.fact_package.as_ref(),
                        self.registry.as_ref(),
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
                        stream: model_stream(self.provider.clone(), request),
                        purpose: StreamingModelPurpose::Initial,
                        accumulated_text: String::new(),
                        accumulated_reasoning_content: String::new(),
                        tool_calls: Vec::new(),
                        usage: LlmUsage::default(),
                        finish_reason: LlmFinishReason::Stop,
                        tool_count,
                        diagnostics_correlation,
                    };
                }
                RuntimePhase::StreamingModel {
                    mut stream,
                    purpose,
                    mut accumulated_text,
                    mut accumulated_reasoning_content,
                    mut tool_calls,
                    mut usage,
                    mut finish_reason,
                    tool_count,
                    diagnostics_correlation,
                } => {
                    if let Some(event) = stream.next().await {
                        let event = match event {
                            Ok(event) => event,
                            Err(error) => {
                                AgentRuntimeDiagnostics::record_model_stream_error(
                                    state.chat_session_id,
                                    &diagnostics_correlation,
                                    streaming_model_purpose_code(&purpose),
                                    tool_count,
                                    &error,
                                );
                                return Err(error);
                            }
                        };
                        match event {
                            LlmStreamEvent::Delta { content } => {
                                accumulated_text.push_str(&content);
                                let suppress_visible_delta =
                                    accumulated_text.trim().is_empty() && content.trim().is_empty();
                                self.phase = RuntimePhase::StreamingModel {
                                    stream,
                                    purpose,
                                    accumulated_text,
                                    accumulated_reasoning_content,
                                    tool_calls,
                                    usage,
                                    finish_reason,
                                    tool_count,
                                    diagnostics_correlation,
                                };
                                if suppress_visible_delta {
                                    continue;
                                }
                                return Ok(Some(LoopStep::MessageDelta { text: content }));
                            }
                            LlmStreamEvent::ReasoningDelta { content } => {
                                accumulated_reasoning_content.push_str(&content);
                                self.phase = RuntimePhase::StreamingModel {
                                    stream,
                                    purpose,
                                    accumulated_text,
                                    accumulated_reasoning_content,
                                    tool_calls,
                                    usage,
                                    finish_reason,
                                    tool_count,
                                    diagnostics_correlation,
                                };
                                continue;
                            }
                            LlmStreamEvent::ToolCall { tool_call } => {
                                tool_calls.push(tool_call);
                                self.phase = RuntimePhase::StreamingModel {
                                    stream,
                                    purpose,
                                    accumulated_text,
                                    accumulated_reasoning_content,
                                    tool_calls,
                                    usage,
                                    finish_reason,
                                    tool_count,
                                    diagnostics_correlation,
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
                                    stream,
                                    purpose,
                                    accumulated_text,
                                    accumulated_reasoning_content,
                                    tool_calls,
                                    usage,
                                    finish_reason,
                                    tool_count,
                                    diagnostics_correlation,
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
                        let visible_text = visible_text_from_model_output(&accumulated_text);
                        if visible_text.trim().is_empty() {
                            return Err(empty_assistant_content_error());
                        }
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
                    if !tool_calls.is_empty() {
                        self.phase = RuntimePhase::ToolExecution {
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
                        self.phase = RuntimePhase::Done {
                            message_id: uuid::Uuid::new_v4(),
                            final_text: safe_user_message,
                            status: maohuoban_ai_domain::ai::AgentTurnStatus::Failed,
                        };
                        return Ok(Some(LoopStep::CallTools { tool_results }));
                    }

                    let needs_confirmation = tool_results.iter().any(|result| {
                        matches!(result.status, LoopToolStatus::RequiresConfirmation)
                    });

                    if needs_confirmation {
                        self.phase = RuntimePhase::Done {
                            message_id: uuid::Uuid::new_v4(),
                            final_text: String::new(),
                            status: maohuoban_ai_domain::ai::AgentTurnStatus::AwaitingConfirmation,
                        };
                    } else {
                        self.phase = RuntimePhase::FollowupModel {
                            assistant_reasoning_content,
                            assistant_tool_calls,
                            tool_results: tool_results.clone(),
                        };
                    }

                    return Ok(Some(LoopStep::CallTools { tool_results }));
                }
                RuntimePhase::EvidenceToolExecution {
                    assistant_tool_calls,
                    tool_calls,
                } => {
                    if !tool_calls.is_empty() {
                        self.phase = RuntimePhase::EvidenceToolExecution {
                            assistant_tool_calls,
                            tool_calls: Vec::new(),
                        };
                        return Ok(Some(LoopStep::call_tools(tool_calls)));
                    }

                    let (tool_results, hard_stop) = execute_tool_calls(
                        self.registry.clone(),
                        self.tool_context.clone(),
                        assistant_tool_calls,
                        &mut self.guardrail,
                    )
                    .await;

                    if let Some(GuardrailDecision::HardStop {
                        safe_user_message, ..
                    }) = hard_stop
                    {
                        self.phase = RuntimePhase::Done {
                            message_id: uuid::Uuid::new_v4(),
                            final_text: safe_user_message,
                            status: maohuoban_ai_domain::ai::AgentTurnStatus::Failed,
                        };
                        return Ok(Some(LoopStep::CallTools { tool_results }));
                    }

                    let needs_confirmation = tool_results.iter().any(|result| {
                        matches!(result.status, LoopToolStatus::RequiresConfirmation)
                    });

                    if needs_confirmation {
                        self.phase = RuntimePhase::Done {
                            message_id: uuid::Uuid::new_v4(),
                            final_text: String::new(),
                            status: maohuoban_ai_domain::ai::AgentTurnStatus::AwaitingConfirmation,
                        };
                    } else {
                        self.phase = RuntimePhase::FollowupModel {
                            assistant_reasoning_content: None,
                            assistant_tool_calls: Vec::new(),
                            tool_results: tool_results.clone(),
                        };
                    }

                    return Ok(Some(LoopStep::CallTools { tool_results }));
                }
                RuntimePhase::FollowupModel {
                    assistant_reasoning_content,
                    assistant_tool_calls,
                    tool_results,
                } => {
                    let mut request = build_request(
                        state,
                        self.fact_package.as_ref(),
                        self.registry.as_ref(),
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
                        stream: model_stream(self.provider.clone(), request),
                        purpose: StreamingModelPurpose::Followup,
                        accumulated_text: String::new(),
                        accumulated_reasoning_content: String::new(),
                        tool_calls: Vec::new(),
                        usage: LlmUsage::default(),
                        finish_reason: LlmFinishReason::Stop,
                        tool_count,
                        diagnostics_correlation,
                    };
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

pub(crate) fn model_stream(
    provider: Arc<dyn LlmProvider>,
    request: LlmChatRequest,
) -> BoxStream<'static, AiResult<LlmStreamEvent>> {
    Box::pin(async_stream::try_stream! {
        let mut stream = provider.stream(&request);
        while let Some(event) = stream.next().await {
            yield event?;
        }
    })
}

/// execute_tool_calls 执行工具调用并接入 guardrail
/// 核心职责：
/// - 执行前通过 guardrail 评估是否允许调用
/// - HardStop 时跳过执行，返回安全文案
/// - SoftReminder 时仍执行但附加提醒
/// - 执行后记录结果到 guardrail
fn empty_assistant_content_error() -> AiError {
    AiError::Provider(ProviderError::new(
        ProviderErrorCategory::InvalidResponse,
        "empty assistant content without tool calls",
    ))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ai::ports::FakeLlmProvider;
    use maohuoban_ai_domain::ai::{
        AgentId, AiConversationSurface, LlmChatResponse, LlmMessage, LlmRole, LlmStreamEvent,
    };

    #[tokio::test]
    async fn whitespace_only_stream_returns_invalid_response_error() {
        let response = LlmChatResponse {
            message: LlmMessage {
                role: LlmRole::Assistant,
                content: String::new(),
                reasoning_content: None,
                tool_call_id: None,
                tool_calls: Vec::new(),
            },
            tool_calls: Vec::new(),
            usage: LlmUsage::default(),
            finish_reason: LlmFinishReason::Stop,
            provider: "fake".to_owned(),
            model: "fake".to_owned(),
        };
        let provider = Arc::new(FakeLlmProvider::new(
            response,
            vec![
                LlmStreamEvent::Delta {
                    content: "                                               ".to_owned(),
                },
                LlmStreamEvent::Finish {
                    finish_reason: LlmFinishReason::Stop,
                    usage: LlmUsage {
                        input_tokens: 10,
                        output_tokens: 71,
                        total_tokens: 81,
                    },
                },
            ],
        ));
        let registry = Arc::new(ToolRegistry::new());
        let tool_context = AiToolContext {
            actor_user_id: uuid::Uuid::new_v4(),
            authorized_pet_id: uuid::Uuid::nil(),
        };
        let mut engine = AgentRuntimeLoopEngine::new(provider, registry, tool_context, None);
        let mut state = AgentSessionState::new(
            uuid::Uuid::new_v4(),
            AgentId::main_pet_care_agent(),
            AiConversationSurface::HomePrivate,
        );
        state.begin_turn("我问你的第一个问题是什么".to_owned());

        let error = loop {
            match engine.next(&mut state).await {
                Ok(Some(LoopStep::MessageDelta { text })) => {
                    panic!("空白流不应输出可见 delta: {text:?}");
                }
                Ok(Some(_)) => {}
                Ok(None) => panic!("空白流不应正常结束"),
                Err(error) => break error,
            }
        };

        assert_eq!(error.stable_code(), "ai.provider.invalid_response");
    }
}
