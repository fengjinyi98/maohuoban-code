use maohuoban_ai_domain::ai::{LlmChatRequest, LlmRole, LlmToolCall};

pub(crate) fn build_openai_body(request: &LlmChatRequest, model: &str) -> serde_json::Value {
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
            if let Some(reasoning_content) = &message.reasoning_content {
                msg["reasoning_content"] = serde_json::Value::String(reasoning_content.clone());
            }
            if !message.tool_calls.is_empty() {
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

    let mut body = serde_json::json!({
        "model": model,
        "messages": messages,
        "temperature": request.temperature,
        "stream": request.stream,
    });

    if !tools.is_empty() {
        body["tools"] = serde_json::Value::Array(tools);
    }
    if let Some(choice) = &request.tool_choice {
        body["tool_choice"] = serde_json::Value::String(choice.clone());
    }
    if let Some(max) = request.max_output_tokens {
        body["max_tokens"] = serde_json::Value::Number(max.into());
    }
    if let Some(fmt) = request.response_format.clone() {
        body["response_format"] = fmt;
    }

    body
}

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
