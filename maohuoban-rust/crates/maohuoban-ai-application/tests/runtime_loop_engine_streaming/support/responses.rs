use maohuoban_ai_domain::ai::{
    AiResult, LlmChatResponse, LlmFinishReason, LlmMessage, LlmRole, LlmStreamEvent, LlmToolCall,
    LlmUsage,
};
use serde_json::json;

pub fn response_to_stream_events(response: LlmChatResponse) -> Vec<AiResult<LlmStreamEvent>> {
    let mut events = Vec::new();
    for tool_call in response.tool_calls {
        events.push(Ok(LlmStreamEvent::ToolCall { tool_call }));
    }
    if !response.message.content.is_empty() {
        events.push(Ok(LlmStreamEvent::Delta {
            content: response.message.content,
        }));
    }
    events.push(Ok(LlmStreamEvent::Finish {
        finish_reason: response.finish_reason,
        usage: response.usage,
    }));
    events
}

pub fn tool_response() -> LlmChatResponse {
    LlmChatResponse {
        message: LlmMessage {
            role: LlmRole::Assistant,
            content: String::new(),
            reasoning_content: None,
            tool_call_id: None,
            tool_calls: Vec::new(),
        },
        tool_calls: vec![LlmToolCall {
            id: "call_1".to_owned(),
            name: "load_pet_identity_context".to_owned(),
            arguments: json!({
                "pet_id": "11111111-1111-1111-1111-111111111111"
            })
            .to_string(),
        }],
        usage: LlmUsage {
            input_tokens: 8,
            output_tokens: 2,
            total_tokens: 10,
        },
        finish_reason: LlmFinishReason::ToolCalls,
        provider: "scripted".to_owned(),
        model: "primary".to_owned(),
    }
}

pub fn final_response() -> LlmChatResponse {
    LlmChatResponse {
        message: LlmMessage {
            role: LlmRole::Assistant,
            content: "毛球当前状态正常".to_owned(),
            reasoning_content: None,
            tool_call_id: None,
            tool_calls: Vec::new(),
        },
        tool_calls: vec![],
        usage: LlmUsage {
            input_tokens: 12,
            output_tokens: 6,
            total_tokens: 18,
        },
        finish_reason: LlmFinishReason::Stop,
        provider: "scripted".to_owned(),
        model: "primary".to_owned(),
    }
}

pub fn final_response_with_text(text: &str) -> LlmChatResponse {
    LlmChatResponse {
        message: LlmMessage {
            role: LlmRole::Assistant,
            content: text.to_owned(),
            reasoning_content: None,
            tool_call_id: None,
            tool_calls: Vec::new(),
        },
        tool_calls: vec![],
        usage: LlmUsage {
            input_tokens: 12,
            output_tokens: 6,
            total_tokens: 18,
        },
        finish_reason: LlmFinishReason::Stop,
        provider: "scripted".to_owned(),
        model: "primary".to_owned(),
    }
}

pub fn diet_tool_response() -> LlmChatResponse {
    LlmChatResponse {
        message: LlmMessage {
            role: LlmRole::Assistant,
            content: String::new(),
            reasoning_content: None,
            tool_call_id: None,
            tool_calls: Vec::new(),
        },
        tool_calls: vec![LlmToolCall {
            id: "call_2".to_owned(),
            name: "load_pet_current_diet_context".to_owned(),
            arguments: json!({
                "pet_id": "11111111-1111-1111-1111-111111111111"
            })
            .to_string(),
        }],
        usage: LlmUsage {
            input_tokens: 10,
            output_tokens: 2,
            total_tokens: 12,
        },
        finish_reason: LlmFinishReason::ToolCalls,
        provider: "scripted".to_owned(),
        model: "primary".to_owned(),
    }
}
