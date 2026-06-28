use std::sync::Arc;

use async_trait::async_trait;
use futures_util::{StreamExt, stream::BoxStream};
use maohuoban_ai_domain::ai::{
    AgentSessionState, AgentSessionWorkbench, AiFactPackage, AiResult, LlmChatRequest,
    LlmFinishReason, LlmMessage, LlmRole, LlmStreamEvent, LlmToolCall, LlmToolSchema, LlmUsage,
    LoopStep, LoopToolResult, LoopToolStatus, ModelCallOutcome, ModelLabel,
    PROVIDER_USER_VISIBLE_FAILURE_MESSAGE,
};
use serde_json::Value;

use crate::ai::fact_projection::AiFactProjection;
use crate::ai::output::visible_text_from_model_output;
use crate::ai::ports::LlmProvider;
use crate::ai::prompt::AiPromptBuilder;
use crate::ai::tools::{AiToolContext, AiToolResult, ToolDefinitionInfo, ToolRegistry};

use super::LoopEngine;

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
        let tools: Vec<LlmToolSchema> = self
            .registry
            .list_definitions()
            .into_iter()
            .filter(|tool| tool_visible_for_workbench(tool, state.workbench.as_ref()))
            .map(|tool| LlmToolSchema {
                name: tool.name,
                description: tool.description,
                parameters: tool.parameters,
            })
            .collect();

        LlmChatRequest {
            model: "primary".to_owned(),
            messages: self.build_messages(state, assistant_tool_calls, tool_results),
            tools,
            tool_choice: None,
            temperature: 0.2,
            stream: false,
            max_output_tokens: None,
            response_format: None,
        }
    }
}

#[async_trait]
impl LoopEngine for AgentRuntimeLoopEngine {
    async fn next(&mut self, state: &mut AgentSessionState) -> AiResult<Option<LoopStep>> {
        loop {
            match std::mem::replace(&mut self.phase, RuntimePhase::Model) {
                RuntimePhase::Model => {
                    let mut request = self.build_request(state, &[], &[]);
                    request.stream = true;
                    let tool_count = request_tool_count(&request);
                    self.phase = RuntimePhase::StreamingModel {
                        stream: model_stream(self.provider.clone(), request),
                        purpose: StreamingModelPurpose::Initial,
                        accumulated_text: String::new(),
                        tool_calls: Vec::new(),
                        usage: LlmUsage::default(),
                        finish_reason: LlmFinishReason::Stop,
                        tool_count,
                    };
                    continue;
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
                        match event? {
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
                    } else {
                        self.phase = RuntimePhase::ToolExecution {
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
                }
                RuntimePhase::ToolExecution { tool_calls } => {
                    let assistant_tool_calls = tool_calls.clone();
                    let tool_results = execute_tool_calls(
                        self.registry.clone(),
                        self.tool_context.clone(),
                        tool_calls,
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
                    self.phase = RuntimePhase::StreamingModel {
                        stream: model_stream(self.provider.clone(), request),
                        purpose: StreamingModelPurpose::Followup,
                        accumulated_text: String::new(),
                        tool_calls: Vec::new(),
                        usage: LlmUsage::default(),
                        finish_reason: LlmFinishReason::Stop,
                        tool_count,
                    };
                    continue;
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

/// workbench_context_prompt 构建模型可见工作台上下文
/// 核心职责：
/// - 将 Agent 定义、能力目录和可见上下文投影给模型
/// - 保持工具执行权仍由 Tool Gateway 控制
fn workbench_context_prompt(workbench: &AgentSessionWorkbench) -> String {
    let payload = serde_json::to_string(workbench).unwrap_or_else(|_| "{}".to_owned());
    format!(
        "## AgentSession Workbench\n\
         这是本轮可见能力目录、上下文包和记忆包。模型只能在这些能力边界内回答、追问或申请工具。\n\
         {payload}"
    )
}

/// tool_visible_for_workbench 判断工具是否应投影给本轮模型
/// 核心职责：
/// - 无私域上下文时隐藏宠物私域读取工具
/// - 保留未携带 Workbench 的旧路径兼容行为
fn tool_visible_for_workbench(
    tool: &ToolDefinitionInfo,
    workbench: Option<&AgentSessionWorkbench>,
) -> bool {
    let Some(workbench) = workbench else {
        return true;
    };

    if workbench_has_private_context(workbench) {
        return true;
    }

    !is_private_pet_tool(tool)
}

/// workbench_has_private_context 判断本轮是否具备私域宠物能力
/// 核心职责：
/// - 只以已解析 selected_pet 作为私域工具可见依据
/// - 避免能力声明或工具目录摘要绕过宠物授权上下文
fn workbench_has_private_context(workbench: &AgentSessionWorkbench) -> bool {
    workbench.context_pack.selected_pet.is_some()
}

/// is_private_pet_tool 判断工具是否读取宠物私域事实
/// 核心职责：
/// - 依据 scope 和 domain tag 识别当前私域工具组
fn is_private_pet_tool(tool: &ToolDefinitionInfo) -> bool {
    tool.scope.starts_with("pet.")
        || tool.domain_tags.iter().any(|tag| {
            matches!(
                tag.as_str(),
                "identity" | "diet" | "inventory" | "diet_confirmation"
            )
        })
}

fn tool_result_to_message(tool_result: &LoopToolResult) -> LlmMessage {
    let content = match tool_result.status {
        LoopToolStatus::Succeeded => tool_result
            .output
            .clone()
            .unwrap_or_else(|| "{}".to_owned()),
        LoopToolStatus::Denied => serde_json::json!({
            "status": "denied",
            "reason": tool_result.denied_reason.clone().unwrap_or_default(),
        })
        .to_string(),
        LoopToolStatus::Failed => serde_json::json!({
            "status": "failed",
            "reason": tool_result.failed_reason.clone().unwrap_or_default(),
        })
        .to_string(),
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
        return LoopToolResult::succeeded(
            tool_call,
            AiFactProjection::build_tool_result_json(&result.facts),
        );
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
