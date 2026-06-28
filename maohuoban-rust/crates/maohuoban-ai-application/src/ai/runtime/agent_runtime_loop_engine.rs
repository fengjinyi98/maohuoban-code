use std::sync::Arc;

use async_trait::async_trait;
use maohuoban_ai_domain::ai::{
    AgentSessionState, AiFactPackage, AiResult, LlmChatRequest, LlmMessage, LlmRole, LlmToolCall,
    LlmToolSchema, LoopStep, LoopToolResult, LoopToolStatus, ModelCallOutcome, ModelLabel,
    PROVIDER_USER_VISIBLE_FAILURE_MESSAGE,
};
use serde_json::Value;

use crate::ai::output::visible_text_from_model_output;
use crate::ai::ports::LlmProvider;
use crate::ai::prompt::AiPromptBuilder;
use crate::ai::tools::{AiToolContext, AiToolResult, ToolRegistry};

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

#[derive(Debug, Clone)]
enum RuntimePhase {
    Model,
    ToolExecution {
        tool_calls: Vec<LlmToolCall>,
    },
    FollowupModel {
        tool_results: Vec<LoopToolResult>,
    },
    Done {
        message_id: uuid::Uuid,
        final_text: String,
        status: maohuoban_ai_domain::ai::AgentTurnStatus,
    },
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
        tool_results: &[LoopToolResult],
    ) -> Vec<LlmMessage> {
        let user_message = state.user_inputs.last().cloned().unwrap_or_default();
        let mut messages =
            AiPromptBuilder::new().build_messages(&user_message, &[], self.fact_package.as_ref());

        for tool_result in tool_results {
            messages.push(tool_result_to_message(tool_result));
        }

        messages
    }

    fn build_request(
        &self,
        state: &AgentSessionState,
        tool_results: &[LoopToolResult],
    ) -> LlmChatRequest {
        let tools: Vec<LlmToolSchema> = self
            .registry
            .list_definitions()
            .into_iter()
            .map(|tool| LlmToolSchema {
                name: tool.name,
                description: tool.description,
                parameters: tool.parameters,
            })
            .collect();

        LlmChatRequest {
            model: "primary".to_owned(),
            messages: self.build_messages(state, tool_results),
            tools,
            tool_choice: None,
            temperature: 0.2,
            stream: false,
            max_output_tokens: None,
            response_format: None,
        }
    }

    async fn execute_tool_calls(&self, tool_calls: Vec<LlmToolCall>) -> Vec<LoopToolResult> {
        let mut results = Vec::with_capacity(tool_calls.len());

        for tool_call in tool_calls {
            let args = serde_json::from_str::<Value>(&tool_call.arguments)
                .unwrap_or_else(|_| Value::Object(serde_json::Map::new()));
            let result = self
                .registry
                .call(&tool_call.name, &self.tool_context, &args)
                .await;
            results.push(to_loop_tool_result(tool_call, result));
        }

        results
    }
}

#[async_trait]
impl LoopEngine for AgentRuntimeLoopEngine {
    async fn next(&mut self, state: &mut AgentSessionState) -> AiResult<Option<LoopStep>> {
        match std::mem::replace(&mut self.phase, RuntimePhase::Model) {
            RuntimePhase::Model => {
                let request = self.build_request(state, &[]);
                let response = self.provider.complete(&request).await?;

                if response.tool_calls.is_empty() {
                    self.phase = RuntimePhase::Done {
                        message_id: uuid::Uuid::new_v4(),
                        final_text: visible_text_from_model_output(&response.message.content),
                        status: maohuoban_ai_domain::ai::AgentTurnStatus::Completed,
                    };
                    Ok(Some(LoopStep::CallModel {
                        model_label: ModelLabel::Primary,
                        tool_count: request_tool_count(&request),
                        outcome: ModelCallOutcome::Finished {
                            finish_reason: response.finish_reason,
                            usage: response.usage,
                            provider: response.provider,
                            model: response.model,
                        },
                    }))
                } else {
                    let tool_calls = response.tool_calls;
                    self.phase = RuntimePhase::ToolExecution {
                        tool_calls: tool_calls.clone(),
                    };
                    Ok(Some(LoopStep::CallModel {
                        model_label: ModelLabel::Primary,
                        tool_count: request_tool_count(&request),
                        outcome: ModelCallOutcome::Finished {
                            finish_reason: response.finish_reason,
                            usage: response.usage,
                            provider: response.provider,
                            model: response.model,
                        },
                    }))
                }
            }
            RuntimePhase::ToolExecution { tool_calls } => {
                let tool_results = self.execute_tool_calls(tool_calls).await;
                let needs_confirmation = tool_results
                    .iter()
                    .any(|result| matches!(result.status, LoopToolStatus::RequiresConfirmation));

                if needs_confirmation {
                    self.phase = RuntimePhase::Done {
                        message_id: uuid::Uuid::new_v4(),
                        final_text: String::new(),
                        status: maohuoban_ai_domain::ai::AgentTurnStatus::AwaitingConfirmation,
                    };
                } else {
                    self.phase = RuntimePhase::FollowupModel {
                        tool_results: tool_results.clone(),
                    };
                }

                Ok(Some(LoopStep::CallTools { tool_results }))
            }
            RuntimePhase::FollowupModel { tool_results } => {
                let request = self.build_request(state, &tool_results);
                let response = self.provider.complete(&request).await?;

                self.phase = RuntimePhase::Done {
                    message_id: uuid::Uuid::new_v4(),
                    final_text: visible_text_from_model_output(&response.message.content),
                    status: maohuoban_ai_domain::ai::AgentTurnStatus::Completed,
                };

                Ok(Some(LoopStep::CallModel {
                    model_label: ModelLabel::Primary,
                    tool_count: request_tool_count(&request),
                    outcome: ModelCallOutcome::Finished {
                        finish_reason: response.finish_reason,
                        usage: response.usage,
                        provider: response.provider,
                        model: response.model,
                    },
                }))
            }
            RuntimePhase::Done {
                message_id,
                final_text,
                status,
            } => Ok(Some(LoopStep::Done {
                message_id,
                final_text,
                status,
            })),
        }
    }
}

/// request_tool_count 计算模型请求中的工具数量
/// 核心职责：
/// - 将集合长度转换为 Runtime 事件使用的稳定计数
/// - 避免平台相关截断影响事件字段
fn request_tool_count(request: &LlmChatRequest) -> u32 {
    u32::try_from(request.tools.len()).unwrap_or(u32::MAX)
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
            serde_json::to_string(&result.facts).unwrap_or_else(|_| "[]".to_owned()),
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
