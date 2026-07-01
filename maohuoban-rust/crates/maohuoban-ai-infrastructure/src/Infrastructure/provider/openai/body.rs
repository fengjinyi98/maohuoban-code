//! body OpenAI 兼容请求体序列化
//! 核心职责：
//! - 将内部 LlmChatRequest 转换为 OpenAI 兼容 JSON 请求体
//! - 所有字段裁剪通过 ProviderRequestPolicy 统一决策
//! - 禁止在此直接判断 capability 字段

use maohuoban_ai_application::ai::provider_capability::ProviderRequestPolicy;
use maohuoban_ai_domain::ai::{LlmChatRequest, LlmRole, LlmToolCall, ProviderCapability};

/// build_openai_body 构建 OpenAI 兼容请求体
/// 核心职责：
/// - 所有请求字段裁剪统一通过 ProviderRequestPolicy 决策
/// - capability 只作为 policy 输入，不在此直接判断
pub(crate) fn build_openai_body(
    request: &LlmChatRequest,
    model: &str,
    capability: &ProviderCapability,
) -> serde_json::Value {
    let send_reasoning = ProviderRequestPolicy::should_send_reasoning_content(capability);
    let send_tools = ProviderRequestPolicy::should_send_tools(capability, request);
    let send_tool_choice = ProviderRequestPolicy::should_send_tool_choice(capability, request);
    let send_response_format =
        ProviderRequestPolicy::should_send_response_format(capability, request);

    let messages: Vec<serde_json::Value> = request
        .messages
        .iter()
        .map(|message| {
            let mut msg = serde_json::json!({
                "role": match message.role {
                    LlmRole::System => "system",
                    LlmRole::User => "user",
                    LlmRole::Assistant => "assistant",
                    LlmRole::Tool => "tool",
                },
                "content": message.content,
            });
            if let Some(id) = &message.tool_call_id {
                msg["tool_call_id"] = serde_json::Value::String(id.clone());
            }
            if send_reasoning {
                if let Some(reasoning_content) = &message.reasoning_content {
                    msg["reasoning_content"] = serde_json::Value::String(reasoning_content.clone());
                }
            }
            if send_tools && !message.tool_calls.is_empty() {
                msg["tool_calls"] = serde_json::Value::Array(
                    message
                        .tool_calls
                        .iter()
                        .map(openai_tool_call_json)
                        .collect(),
                );
            }
            msg
        })
        .collect();

    let mut body = serde_json::json!({
        "model": model,
        "messages": messages,
        "temperature": request.temperature,
        "stream": request.stream,
    });

    if send_tools {
        let tools: Vec<serde_json::Value> = request
            .tools
            .iter()
            .map(|tool| {
                serde_json::json!({
                    "type": "function",
                    "function": {
                        "name": tool.name,
                        "description": tool.description,
                        "parameters": tool.parameters,
                    }
                })
            })
            .collect();
        body["tools"] = serde_json::Value::Array(tools);
    }

    if send_tool_choice {
        if let Some(choice) = &request.tool_choice {
            body["tool_choice"] = serde_json::Value::String(choice.clone());
        }
    }

    if let Some(max) = request.max_output_tokens {
        body["max_tokens"] = serde_json::Value::Number(max.into());
    }

    let send_json_output = ProviderRequestPolicy::should_send_json_output(capability, request);

    if send_response_format {
        if let Some(fmt) = request.response_format.clone() {
            // json_object 类型额外受 supports_json_output 门控
            let is_json_object = fmt
                .get("type")
                .and_then(|t| t.as_str())
                .is_some_and(|t| t == "json_object");
            if !is_json_object || send_json_output {
                body["response_format"] = fmt;
            }
        }
    }

    body
}

/// openai_tool_call_json 将内部 LlmToolCall 序列化为 OpenAI tool_calls 元素
fn openai_tool_call_json(tool_call: &LlmToolCall) -> serde_json::Value {
    serde_json::json!({
        "id": tool_call.id.clone(),
        "type": "function",
        "function": {
            "name": tool_call.name.clone(),
            "arguments": tool_call.arguments.clone(),
        }
    })
}
