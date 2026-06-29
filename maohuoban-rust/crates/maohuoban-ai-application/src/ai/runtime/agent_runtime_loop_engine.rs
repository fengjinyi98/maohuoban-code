// MHB_STRUCTURE_EXEMPTION: ai/runtime 为既有 Agent Runtime 目录；本次只追加可观测点，后续 code-structure P1 统一迁移到 Infrastructure/Services 分层目录。
use std::sync::Arc;

use async_trait::async_trait;
use futures_util::{StreamExt, stream::BoxStream};
use maohuoban_ai_domain::ai::{
    AgentSessionState, AiFactPackage, AiResult, LlmChatRequest, LlmFinishReason, LlmMessage,
    LlmRole, LlmStreamEvent, LlmToolCall, LlmUsage, LoopStep, LoopToolResult, LoopToolStatus,
    ModelCallOutcome, ModelLabel, PROVIDER_USER_VISIBLE_FAILURE_MESSAGE, ToolFactProjector,
};
use serde_json::Value;

use crate::ai::output::visible_text_from_model_output;
use crate::ai::ports::LlmProvider;
use crate::ai::prompt::AiPromptBuilder;
use crate::ai::tools::{AiToolContext, AiToolResult, ToolRegistry};

#[path = "../Infrastructure/runtime/agent_runtime_diagnostics.rs"]
mod agent_runtime_diagnostics;
#[path = "../Infrastructure/runtime/agent_runtime_request_policy.rs"]
mod agent_runtime_request_policy;

use agent_runtime_diagnostics::AgentRuntimeDiagnostics;
use agent_runtime_request_policy::AgentRuntimeRequestPolicy;

use super::{LoopEngine, workbench_prompt_projection::workbench_context_prompt};

/// AgentRuntimeLoopEngine 毛球 Agent Runtime loop 实现
/// 核心职责：
/// - 组装模型请求、工具执行和结果回灌
/// - 保持 Tool Gateway、Provider 和 Runtime 可替换
pub struct AgentRuntimeLoopEngine {
    provider: Arc<dyn LlmProvider>,
    registry: Arc<ToolRegistry>,
    tool_context: AiToolContext,
    fact_package: Option<AiFactPackage>,
    phase: RuntimePhase,
}

enum RuntimePhase {
    Model,
    StreamingModel {
        stream: BoxStream<'static, AiResult<LlmStreamEvent>>,
        purpose: StreamingModelPurpose,
        accumulated_text: String,
        tool_calls: Vec<LlmToolCall>,
        usage: LlmUsage,
        finish_reason: LlmFinishReason,
        tool_count: u32,
    },
    ToolExecution {
        assistant_tool_calls: Vec<LlmToolCall>,
        tool_calls: Vec<LlmToolCall>,
    },
    FollowupModel {
        assistant_tool_calls: Vec<LlmToolCall>,
        tool_results: Vec<LoopToolResult>,
    },
    Done {
        message_id: uuid::Uuid,
        final_text: String,
        status: maohuoban_ai_domain::ai::AgentTurnStatus,
    },
}

enum StreamingModelPurpose {
    Initial,
    Followup,
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
            phase: RuntimePhase::Model,
        }
    }

    fn build_messages(
        &self,
        state: &AgentSessionState,
        assistant_tool_calls: &[LlmToolCall],
        tool_results: &[LoopToolResult],
    ) -> Vec<LlmMessage> {
        let user_message = state.user_inputs.last().cloned().unwrap_or_default();
        let mut messages =
            AiPromptBuilder::new().build_messages(&user_message, &[], self.fact_package.as_ref());

        if let Some(workbench) = state.workbench.as_ref() {
            let insert_index = messages.len().saturating_sub(1);
            messages.insert(
                insert_index,
                LlmMessage {
                    role: LlmRole::System,
                    content: workbench_context_prompt(workbench),
                    tool_call_id: None,
                    tool_calls: Vec::new(),
                },
            );
        }

        if !assistant_tool_calls.is_empty() {
            messages.push(LlmMessage {
                role: LlmRole::Assistant,
                content: String::new(),
                tool_call_id: None,
                tool_calls: assistant_tool_calls.to_vec(),
            });
        }

        for tool_result in tool_results {
            messages.push(tool_result_to_message(tool_result));
        }

        messages
    }

    fn build_request(
        &self,
        state: &AgentSessionState,
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

        LlmChatRequest {
            model: "primary".to_owned(),
            messages: self.build_messages(state, assistant_tool_calls, tool_results),
            tools,
            tool_choice: None,
            temperature: 0.2,
            stream: false,
            max_output_tokens: None,
            response_format,
        }
    }
}

// LoopEngine::next 保持 Runtime 阶段迁移集中，便于审查模型流、工具执行和终态顺序。
#[allow(clippy::too_many_lines)]
#[async_trait]
impl LoopEngine for AgentRuntimeLoopEngine {
    async fn next(&mut self, state: &mut AgentSessionState) -> AiResult<Option<LoopStep>> {
        loop {
            match std::mem::replace(&mut self.phase, RuntimePhase::Model) {
                RuntimePhase::Model => {
                    let mut request = self.build_request(state, &[], &[]);
                    request.stream = true;
                    let tool_count = request_tool_count(&request);
                    AgentRuntimeDiagnostics::record_model_request_prepared(
                        state.chat_session_id,
                        "initial",
                        &request,
                    );
                    self.phase = RuntimePhase::StreamingModel {
                        stream: model_stream(self.provider.clone(), request),
                        purpose: StreamingModelPurpose::Initial,
                        accumulated_text: String::new(),
                        tool_calls: Vec::new(),
                        usage: LlmUsage::default(),
                        finish_reason: LlmFinishReason::Stop,
                        tool_count,
                    };
                }
                RuntimePhase::StreamingModel {
                    mut stream,
                    purpose,
                    mut accumulated_text,
                    mut tool_calls,
                    mut usage,
                    mut finish_reason,
                    tool_count,
                } => {
                    if let Some(event) = stream.next().await {
                        let event = match event {
                            Ok(event) => event,
                            Err(error) => {
                                AgentRuntimeDiagnostics::record_model_stream_error(
                                    state.chat_session_id,
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
                                self.phase = RuntimePhase::StreamingModel {
                                    stream,
                                    purpose,
                                    accumulated_text,
                                    tool_calls,
                                    usage,
                                    finish_reason,
                                    tool_count,
                                };
                                return Ok(Some(LoopStep::MessageDelta { text: content }));
                            }
                            LlmStreamEvent::ToolCall { tool_call } => {
                                tool_calls.push(tool_call);
                                self.phase = RuntimePhase::StreamingModel {
                                    stream,
                                    purpose,
                                    accumulated_text,
                                    tool_calls,
                                    usage,
                                    finish_reason,
                                    tool_count,
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
                                    tool_calls,
                                    usage,
                                    finish_reason,
                                    tool_count,
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
                        self.phase = RuntimePhase::Done {
                            message_id: uuid::Uuid::new_v4(),
                            final_text: visible_text_from_model_output(&accumulated_text),
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
                    assistant_tool_calls,
                    tool_calls,
                } => {
                    if !tool_calls.is_empty() {
                        self.phase = RuntimePhase::ToolExecution {
                            assistant_tool_calls,
                            tool_calls: Vec::new(),
                        };
                        return Ok(Some(LoopStep::call_tools(tool_calls)));
                    }

                    let tool_results = execute_tool_calls(
                        self.registry.clone(),
                        self.tool_context.clone(),
                        assistant_tool_calls.clone(),
                    )
                    .await;
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
                            assistant_tool_calls,
                            tool_results: tool_results.clone(),
                        };
                    }

                    return Ok(Some(LoopStep::CallTools { tool_results }));
                }
                RuntimePhase::FollowupModel {
                    assistant_tool_calls,
                    tool_results,
                } => {
                    let mut request =
                        self.build_request(state, &assistant_tool_calls, &tool_results);
                    request.stream = true;
                    let tool_count = request_tool_count(&request);
                    AgentRuntimeDiagnostics::record_model_request_prepared(
                        state.chat_session_id,
                        "followup",
                        &request,
                    );
                    self.phase = RuntimePhase::StreamingModel {
                        stream: model_stream(self.provider.clone(), request),
                        purpose: StreamingModelPurpose::Followup,
                        accumulated_text: String::new(),
                        tool_calls: Vec::new(),
                        usage: LlmUsage::default(),
                        finish_reason: LlmFinishReason::Stop,
                        tool_count,
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

fn model_stream(
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

async fn execute_tool_calls(
    registry: Arc<ToolRegistry>,
    tool_context: AiToolContext,
    tool_calls: Vec<LlmToolCall>,
) -> Vec<LoopToolResult> {
    let mut results = Vec::with_capacity(tool_calls.len());

    for tool_call in tool_calls {
        let args = serde_json::from_str::<Value>(&tool_call.arguments)
            .unwrap_or_else(|_| Value::Object(serde_json::Map::new()));
        let result = registry.call(&tool_call.name, &tool_context, &args).await;
        results.push(to_loop_tool_result(tool_call, result));
    }

    results
}

/// request_tool_count 计算模型请求中的工具数量
/// 核心职责：
/// - 将集合长度转换为 Runtime 事件使用的稳定计数
/// - 避免平台相关截断影响事件字段
fn request_tool_count(request: &LlmChatRequest) -> u32 {
    u32::try_from(request.tools.len()).unwrap_or(u32::MAX)
}

/// streaming_model_purpose_code 返回诊断使用的阶段编码
/// 核心职责：
/// - 稳定标记初始工具规划和工具回灌后的最终回答
/// - 避免诊断包只能看到 provider 大类错误
fn streaming_model_purpose_code(purpose: &StreamingModelPurpose) -> &'static str {
    match purpose {
        StreamingModelPurpose::Initial => "initial",
        StreamingModelPurpose::Followup => "followup",
    }
}

fn tool_result_to_message(tool_result: &LoopToolResult) -> LlmMessage {
    let content = match tool_result.status {
        LoopToolStatus::Succeeded => tool_result
            .output
            .clone()
            .unwrap_or_else(|| "{}".to_owned()),
        LoopToolStatus::Denied => {
            let projected = ToolFactProjector::project_denied(
                tool_result.denied_reason.as_deref().unwrap_or_default(),
            );
            serde_json::to_string(&projected).unwrap_or_else(|_| "{}".to_owned())
        }
        LoopToolStatus::Failed => {
            let projected = ToolFactProjector::project_failed(
                tool_result.failed_reason.as_deref().unwrap_or_default(),
            );
            serde_json::to_string(&projected).unwrap_or_else(|_| "{}".to_owned())
        }
        LoopToolStatus::RequiresConfirmation => serde_json::json!({
            "status": "requires_confirmation",
            "confirmation": tool_result.confirmation,
        })
        .to_string(),
        LoopToolStatus::Requested => "{}".to_owned(),
    };

    LlmMessage {
        role: LlmRole::Tool,
        content,
        tool_call_id: Some(tool_result.tool_call.id.clone()),
        tool_calls: Vec::new(),
    }
}

fn to_loop_tool_result(tool_call: LlmToolCall, result: AiToolResult) -> LoopToolResult {
    if result.allowed {
        let mut projected = ToolFactProjector::project_facts(&result.facts);
        projected.reference_ids.extend(result.returned_ref_ids);
        let json =
            serde_json::to_string(&projected).unwrap_or_else(|_| "{\"facts\":[]}".to_owned());
        return LoopToolResult::succeeded(tool_call, json);
    }

    if let Some(confirmation) = result.confirmation {
        return LoopToolResult::requires_confirmation(tool_call, confirmation);
    }

    if let Some(reason) = result.denied_reason {
        return LoopToolResult::denied(tool_call, reason);
    }

    if let Some(reason) = result.failed_reason {
        return LoopToolResult::failed(tool_call, reason);
    }

    LoopToolResult::failed(tool_call, PROVIDER_USER_VISIBLE_FAILURE_MESSAGE.to_owned())
}
