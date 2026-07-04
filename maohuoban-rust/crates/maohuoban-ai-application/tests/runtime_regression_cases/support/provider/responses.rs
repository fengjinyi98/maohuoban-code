use maohuoban_ai_domain::ai::{
    LlmChatResponse, LlmFinishReason, LlmMessage, LlmRole, LlmStreamEvent, LlmToolCall, LlmUsage,
};

/// `response_to_stream_events` 将非流式响应投影为流式事件
/// 核心职责：
/// - 固定工具调用事件顺序
/// - 固定文本 delta 和 finish 事件输出
pub fn response_to_stream_events(
    response: LlmChatResponse,
) -> Vec<maohuoban_ai_domain::ai::AiResult<LlmStreamEvent>> {
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

/// `final_text_response` 构造最终文本模型响应
/// 核心职责：
/// - 固定 assistant 文本响应
/// - 固定 provider/model 元数据
pub fn final_text_response(text: &str) -> LlmChatResponse {
    LlmChatResponse {
        message: LlmMessage {
            role: LlmRole::Assistant,
            content: text.to_owned(),
            reasoning_content: None,
            tool_call_id: None,
            tool_calls: Vec::new(),
        },
        tool_calls: vec![],
        usage: LlmUsage::default(),
        finish_reason: LlmFinishReason::Stop,
        provider: "scripted".to_owned(),
        model: "primary".to_owned(),
    }
}

/// `tool_call_response` 构造工具调用模型响应
/// 核心职责：
/// - 固定单个工具调用 ID
/// - 固定 `tool_calls` finish reason
#[allow(clippy::needless_pass_by_value)]
pub fn tool_call_response(tool_name: &str, args: serde_json::Value) -> LlmChatResponse {
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
            name: tool_name.to_owned(),
            arguments: args.to_string(),
        }],
        usage: LlmUsage::default(),
        finish_reason: LlmFinishReason::ToolCalls,
        provider: "scripted".to_owned(),
        model: "primary".to_owned(),
    }
}

/// `json_response` 构造 JSON 包裹答案响应
/// 核心职责：
/// - 固定 `answer_text` JSON 响应格式
/// - 验证 runtime finalizer 会提取可见答案
pub fn json_response(answer_text: &str) -> LlmChatResponse {
    let content = serde_json::json!({"answer_text": answer_text}).to_string();
    LlmChatResponse {
        message: LlmMessage {
            role: LlmRole::Assistant,
            content,
            reasoning_content: None,
            tool_call_id: None,
            tool_calls: Vec::new(),
        },
        tool_calls: vec![],
        usage: LlmUsage::default(),
        finish_reason: LlmFinishReason::Stop,
        provider: "scripted".to_owned(),
        model: "primary".to_owned(),
    }
}

/// `think_response` 构造带思考标签的模型响应
/// 核心职责：
/// - 固定 `<think>` 内部内容
/// - 验证 runtime finalizer 过滤不可见推理文本
pub fn think_response(inner: &str, visible: &str) -> LlmChatResponse {
    let content = format!("<think>{inner}</think>{visible}");
    LlmChatResponse {
        message: LlmMessage {
            role: LlmRole::Assistant,
            content,
            reasoning_content: None,
            tool_call_id: None,
            tool_calls: Vec::new(),
        },
        tool_calls: vec![],
        usage: LlmUsage::default(),
        finish_reason: LlmFinishReason::Stop,
        provider: "scripted".to_owned(),
        model: "primary".to_owned(),
    }
}
