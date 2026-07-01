use maohuoban_ai_domain::ai::{LlmFinishReason, LlmStreamEvent, LlmUsage};
use reqwest::header::HeaderMap;

pub(crate) fn header_summary(headers: &HeaderMap) -> String {
    headers
        .iter()
        .filter_map(|(name, value)| {
            let name = name.as_str();
            if name.eq_ignore_ascii_case("authorization") || name.eq_ignore_ascii_case("cookie") {
                return None;
            }
            Some(format!(
                "{}={:?}",
                name,
                value.to_str().unwrap_or("<non-utf8>")
            ))
        })
        .collect::<Vec<_>>()
        .join(";")
}

pub(crate) fn stream_event_name(event: &LlmStreamEvent) -> &'static str {
    match event {
        LlmStreamEvent::Delta { .. } => "delta",
        LlmStreamEvent::ReasoningDelta { .. } => "reasoning_delta",
        LlmStreamEvent::ToolCall { .. } => "tool_call",
        LlmStreamEvent::Finish { .. } => "finish",
        LlmStreamEvent::Error { .. } => "error",
    }
}

pub(crate) fn stream_event_payload(event: &LlmStreamEvent) -> serde_json::Value {
    match event {
        LlmStreamEvent::Delta { content } => serde_json::json!({ "content": content }),
        LlmStreamEvent::ReasoningDelta { content } => {
            serde_json::json!({ "content": content })
        }
        LlmStreamEvent::ToolCall { tool_call } => serde_json::json!({
            "id": tool_call.id,
            "name": tool_call.name,
            "arguments": tool_call.arguments,
        }),
        LlmStreamEvent::Finish {
            finish_reason,
            usage,
        } => finish_payload(*finish_reason, *usage),
        LlmStreamEvent::Error { message } => serde_json::json!({ "message": message }),
    }
}

fn finish_payload(finish_reason: LlmFinishReason, usage: LlmUsage) -> serde_json::Value {
    serde_json::json!({
        "finish_reason": format!("{finish_reason:?}"),
        "usage": {
            "input_tokens": usage.input_tokens,
            "output_tokens": usage.output_tokens,
            "total_tokens": usage.total_tokens,
        }
    })
}
