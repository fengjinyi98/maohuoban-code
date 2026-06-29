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

use crate::ai::guardrail::{GuardrailDecision, ToolCallGuardrail, ToolCallRecord};
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
/// - 集成 ToolCallGuardrail 防止工具循环
pub struct AgentRuntimeLoopEngine {
    provider: Arc<dyn LlmProvider>,
    registry: Arc<ToolRegistry>,
    tool_context: AiToolContext,
    fact_package: Option<AiFactPackage>,
    guardrail: ToolCallGuardrail,
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
            guardrail: ToolCallGuardrail::new(),
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
            let user_msg_index = messages.len().saturating_sub(1);

            let mut pre_user_messages: Vec<LlmMessage> = Vec::new();

            pre_user_messages.push(LlmMessage {
                role: LlmRole::System,
                content: workbench_context_prompt(workbench),
                tool_call_id: None,
                tool_calls: Vec::new(),
            });

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

/// execute_tool_calls 执行工具调用并接入 guardrail
/// 核心职责：
/// - 执行前通过 guardrail 评估是否允许调用
/// - HardStop 时跳过执行，返回安全文案
/// - SoftReminder 时仍执行但附加提醒
/// - 执行后记录结果到 guardrail
async fn execute_tool_calls(
    registry: Arc<ToolRegistry>,
    tool_context: AiToolContext,
    tool_calls: Vec<LlmToolCall>,
    guardrail: &mut ToolCallGuardrail,
) -> (Vec<LoopToolResult>, Option<GuardrailDecision>) {
    let mut results = Vec::with_capacity(tool_calls.len());

    for tool_call in tool_calls {
        let risk_level = registry
            .get(&tool_call.name)
            .map(|tool| tool.metadata().risk_level);

        let decision = guardrail.evaluate(&tool_call, risk_level);

        match decision {
            GuardrailDecision::HardStop {
                safe_user_message,
                internal_reason,
            } => {
                let failure = maohuoban_ai_domain::ai::ToolFailure::new(
                    "guardrail.hard_stop",
                    false,
                    &safe_user_message,
                    &internal_reason,
                );
                let result = LoopToolResult::failed_with_failure(tool_call.clone(), failure);
                guardrail.record(ToolCallRecord {
                    tool_call: tool_call.clone(),
                    status: LoopToolStatus::Failed,
                    produced_facts: false,
                    risk_level,
                });
                results.push(result);
                return (
                    results,
                    Some(GuardrailDecision::HardStop {
                        safe_user_message,
                        internal_reason,
                    }),
                );
            }
            GuardrailDecision::SoftReminder { message } => {
                let args = serde_json::from_str::<Value>(&tool_call.arguments)
                    .unwrap_or_else(|_| Value::Object(serde_json::Map::new()));
                let result = registry.call(&tool_call.name, &tool_context, &args).await;
                let mut loop_result = to_loop_tool_result(tool_call.clone(), result);
                let produced_facts = output_has_facts(loop_result.output.as_deref());
                loop_result.guardrail_message = Some(message);
                guardrail.record(ToolCallRecord {
                    tool_call: tool_call.clone(),
                    status: loop_result.status,
                    produced_facts,
                    risk_level,
                });
                results.push(loop_result);
            }
            GuardrailDecision::Allow => {
                let args = serde_json::from_str::<Value>(&tool_call.arguments)
                    .unwrap_or_else(|_| Value::Object(serde_json::Map::new()));
                let result = registry.call(&tool_call.name, &tool_context, &args).await;
                let loop_result = to_loop_tool_result(tool_call.clone(), result);
                let produced_facts = output_has_facts(loop_result.output.as_deref());
                guardrail.record(ToolCallRecord {
                    tool_call: tool_call.clone(),
                    status: loop_result.status,
                    produced_facts,
                    risk_level,
                });
                results.push(loop_result);
            }
        }
    }

    (results, None)
}

/// request_tool_count 计算模型请求中的工具数量
fn request_tool_count(request: &LlmChatRequest) -> u32 {
    u32::try_from(request.tools.len()).unwrap_or(u32::MAX)
}

/// output_has_facts 判断工具输出是否包含非空事实
/// 核心职责：
/// - 解析 output JSON，检查 facts 数组是否非空
/// - 解析失败或 facts 为空时返回 false，确保无进展检测能正确触发
fn output_has_facts(output: Option<&str>) -> bool {
    let Some(json_str) = output else {
        return false;
    };
    let Ok(parsed) = serde_json::from_str::<Value>(json_str) else {
        return false;
    };
    parsed
        .get("facts")
        .and_then(Value::as_array)
        .is_some_and(|facts| !facts.is_empty())
}

/// streaming_model_purpose_code 返回诊断使用的阶段编码
fn streaming_model_purpose_code(purpose: &StreamingModelPurpose) -> &'static str {
    match purpose {
        StreamingModelPurpose::Initial => "initial",
        StreamingModelPurpose::Followup => "followup",
    }
}

/// tool_result_to_message 将工具结果转为模型可见消息
/// 核心职责：
/// - 成功结果直接回灌 output，guardrail_message 以结构化字段注入
/// - 失败结果携带 error_code 和 recoverable，供模型决策追问或换工具
/// - 不泄露 internal_reason
fn tool_result_to_message(tool_result: &LoopToolResult) -> LlmMessage {
    let content = match tool_result.status {
        LoopToolStatus::Succeeded => {
            let base = tool_result
                .output
                .clone()
                .unwrap_or_else(|| "{}".to_owned());
            if let Some(msg) = &tool_result.guardrail_message {
                merge_guardrail_message(&base, msg)
            } else {
                base
            }
        }
        LoopToolStatus::Denied => {
            let projected = ToolFactProjector::project_denied(
                tool_result.denied_reason.as_deref().unwrap_or_default(),
            );
            serde_json::to_string(&projected).unwrap_or_else(|_| "{}".to_owned())
        }
        LoopToolStatus::Failed => {
            if let Some(failure) = &tool_result.failure {
                serde_json::json!({
                    "status": "failed",
                    "error_code": failure.error_code,
                    "recoverable": failure.recoverable,
                    "message": failure.safe_user_message,
                })
                .to_string()
            } else {
                let projected = ToolFactProjector::project_failed(
                    tool_result.failed_reason.as_deref().unwrap_or_default(),
                );
                serde_json::to_string(&projected).unwrap_or_else(|_| "{}".to_owned())
            }
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

/// to_loop_tool_result 将 AiToolResult 转为 LoopToolResult
/// 核心职责：
/// - 传播结构化失败信息
/// - 保留 legacy 兼容
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

    if let Some(failure) = result.failure {
        return LoopToolResult::failed_with_failure(tool_call, failure);
    }

    if let Some(reason) = result.denied_reason {
        return LoopToolResult::denied(tool_call, reason);
    }

    if let Some(reason) = result.failed_reason {
        return LoopToolResult::failed(tool_call, reason);
    }

    LoopToolResult::failed(tool_call, PROVIDER_USER_VISIBLE_FAILURE_MESSAGE.to_owned())
}

/// merge_guardrail_message 将 guardrail 提醒以结构化字段注入工具输出 JSON
/// 核心职责：
/// - 解析原始 output JSON，追加 `_guardrail_reminder` 字段
/// - 解析失败时回退为包含原始 output 和 reminder 的 JSON 对象
/// - 保持原始 facts/reference_ids 结构不变
fn merge_guardrail_message(base_output: &str, message: &str) -> String {
    match serde_json::from_str::<Value>(base_output) {
        Ok(mut json) => {
            if let Some(obj) = json.as_object_mut() {
                obj.insert(
                    "_guardrail_reminder".to_owned(),
                    Value::String(message.to_owned()),
                );
            }
            serde_json::to_string(&json).unwrap_or_else(|_| base_output.to_owned())
        }
        Err(_) => serde_json::json!({
            "output": base_output,
            "_guardrail_reminder": message,
        })
        .to_string(),
    }
}
