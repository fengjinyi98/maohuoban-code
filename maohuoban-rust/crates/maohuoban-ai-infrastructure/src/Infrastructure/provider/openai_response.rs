use maohuoban_ai_domain::ai::{
    AiError, LlmChatResponse, LlmFinishReason, LlmMessage, LlmRole, LlmToolCall, LlmUsage,
    ProviderError, ProviderErrorCategory,
};

pub(crate) fn parse_openai_response(body: &str) -> Result<LlmChatResponse, AiError> {
    let json: serde_json::Value = serde_json::from_str(body).map_err(|error| {
        provider_error(
            ProviderErrorCategory::InvalidResponse,
            format!("invalid json: {error}"),
        )
    })?;

    let choice = json
        .get("choices")
        .and_then(|choices| choices.get(0))
        .ok_or_else(|| {
            provider_error(
                ProviderErrorCategory::InvalidResponse,
                "no choices in response",
            )
        })?;

    let message = choice.get("message").ok_or_else(|| {
        provider_error(
            ProviderErrorCategory::InvalidResponse,
            "no message in choice",
        )
    })?;

    let content = message
        .get("content")
        .and_then(|value| value.as_str())
        .unwrap_or("")
        .to_owned();
    let reasoning_content = message
        .get("reasoning_content")
        .and_then(|value| value.as_str())
        .filter(|value| !value.is_empty())
        .map(str::to_owned);

    let finish_reason = match choice
        .get("finish_reason")
        .and_then(|value| value.as_str())
        .unwrap_or("stop")
    {
        "length" => LlmFinishReason::Length,
        "tool_calls" => LlmFinishReason::ToolCalls,
        "content_filter" => LlmFinishReason::ContentFilter,
        _ => LlmFinishReason::Stop,
    };

    let tool_calls: Vec<LlmToolCall> = message
        .get("tool_calls")
        .and_then(|value| value.as_array())
        .map(|items| {
            items
                .iter()
                .filter_map(|item| {
                    let id = item.get("id")?.as_str()?.to_owned();
                    let function = item.get("function")?;
                    let name = function.get("name")?.as_str()?.to_owned();
                    let arguments = function
                        .get("arguments")
                        .and_then(|value| value.as_str())
                        .unwrap_or("{}")
                        .to_owned();
                    Some(LlmToolCall {
                        id,
                        name,
                        arguments,
                    })
                })
                .collect()
        })
        .unwrap_or_default();

    if tool_calls.is_empty() && content.trim().is_empty() {
        return Err(provider_error(
            ProviderErrorCategory::InvalidResponse,
            "empty assistant content without tool calls",
        ));
    }

    let usage = json
        .get("usage")
        .map(|usage| LlmUsage {
            input_tokens: usage
                .get("prompt_tokens")
                .and_then(serde_json::Value::as_u64)
                .unwrap_or(0) as u32,
            output_tokens: usage
                .get("completion_tokens")
                .and_then(serde_json::Value::as_u64)
                .unwrap_or(0) as u32,
            total_tokens: usage
                .get("total_tokens")
                .and_then(serde_json::Value::as_u64)
                .unwrap_or(0) as u32,
        })
        .unwrap_or_default();

    let model = json
        .get("model")
        .and_then(|value| value.as_str())
        .unwrap_or("")
        .to_owned();

    Ok(LlmChatResponse {
        message: LlmMessage {
            role: LlmRole::Assistant,
            content,
            reasoning_content,
            tool_call_id: None,
            tool_calls: tool_calls.clone(),
        },
        tool_calls,
        usage,
        finish_reason,
        provider: "openai_compatible".to_owned(),
        model,
    })
}

fn provider_error(category: ProviderErrorCategory, message: impl Into<String>) -> AiError {
    AiError::Provider(ProviderError::new(category, message))
}
