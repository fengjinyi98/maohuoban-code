//! sse SSE chunk 解析
//! 核心职责：
//! - 将 OpenAI 兼容 SSE chunk 解析为内部 LlmStreamEvent
//! - 支持 delta、finish、usage、error 和 [DONE] 标记

use maohuoban_ai_domain::ai::{
    AiError, AiResult, LlmFinishReason, LlmStreamEvent, LlmToolCall, LlmUsage, ProviderError,
    ProviderErrorCategory,
};

/// parse_sse_buffer 解析 SSE 缓冲区
/// 核心职责：
/// - 按空行分割 SSE 事件
/// - 返回已解析事件列表和剩余不完整数据
#[must_use]
pub fn parse_sse_buffer(buffer: &str) -> (Vec<AiResult<LlmStreamEvent>>, String) {
    let mut events = Vec::new();
    let mut remaining = String::new();

    let mut lines = buffer.split('\n').peekable();
    let mut event_lines: Vec<&str> = Vec::new();

    for line in lines.by_ref() {
        if line.is_empty() {
            // 空行表示事件结束
            if !event_lines.is_empty() {
                if let Some(event) = parse_sse_event(&event_lines) {
                    events.push(event);
                }
                event_lines.clear();
            }
        } else {
            event_lines.push(line);
        }
    }

    // 剩余不完整数据
    for line in event_lines {
        remaining.push_str(line);
        remaining.push('\n');
    }

    (events, remaining)
}

/// parse_sse_event 解析单个 SSE 事件
fn parse_sse_event(lines: &[&str]) -> Option<AiResult<LlmStreamEvent>> {
    let mut data_parts: Vec<&str> = Vec::new();

    for line in lines {
        if let Some(data) = line.strip_prefix("data: ") {
            data_parts.push(data);
        } else if let Some(data) = line.strip_prefix("data:") {
            data_parts.push(data);
        }
    }

    if data_parts.is_empty() {
        return None;
    }

    let data = data_parts.join("\n");

    // [DONE] 标记
    if data.trim() == "[DONE]" {
        return None;
    }

    let json: serde_json::Value = match serde_json::from_str(&data) {
        Ok(j) => j,
        Err(error) => {
            return Some(Err(AiError::Provider(ProviderError::new(
                ProviderErrorCategory::InvalidResponse,
                format!("invalid sse json: {error}"),
            ))));
        }
    };

    if let Some(error) = json.get("error") {
        return Some(parse_error_event(error));
    }

    let choices = json.get("choices")?.as_array()?;
    let choice = choices.first()?;

    if let Some(event) = parse_finish_event(choice, &json) {
        return Some(Ok(event));
    }

    let delta = choice.get("delta")?;
    let content = delta.get("content").and_then(|c| c.as_str()).unwrap_or("");

    if let Some(event) = parse_tool_call_event(delta) {
        return Some(Ok(event));
    }

    if content.is_empty() {
        None
    } else {
        Some(Ok(LlmStreamEvent::Delta {
            content: content.to_owned(),
        }))
    }
}

/// parse_error_event 解析 Provider SSE 错误事件
/// 核心职责：
/// - 将上游 error payload 映射为 Provider upstream 分类
fn parse_error_event(error: &serde_json::Value) -> AiResult<LlmStreamEvent> {
    let message = error
        .get("message")
        .and_then(|m| m.as_str())
        .unwrap_or("unknown error")
        .to_owned();
    Err(AiError::Provider(ProviderError::new(
        ProviderErrorCategory::Upstream,
        message,
    )))
}

/// parse_finish_event 解析 SSE 完成事件
/// 核心职责：
/// - 映射 finish_reason
/// - 抽取 usage token 用量
fn parse_finish_event(
    choice: &serde_json::Value,
    event: &serde_json::Value,
) -> Option<LlmStreamEvent> {
    let reason = choice.get("finish_reason").and_then(|f| f.as_str())?;
    if reason == "null" {
        return None;
    }

    let finish_reason = match reason {
        "length" => LlmFinishReason::Length,
        "tool_calls" => LlmFinishReason::ToolCalls,
        "content_filter" => LlmFinishReason::ContentFilter,
        _ => LlmFinishReason::Stop,
    };

    Some(LlmStreamEvent::Finish {
        finish_reason,
        usage: event.get("usage").map(parse_usage).unwrap_or_default(),
    })
}

/// parse_usage 解析 OpenAI usage 字段
/// 核心职责：
/// - 将缺失 token 字段按 0 处理
fn parse_usage(usage: &serde_json::Value) -> LlmUsage {
    LlmUsage {
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
    }
}

/// parse_tool_call_event 解析工具调用 delta
/// 核心职责：
/// - 抽取首个工具调用的 id、name 和 arguments
/// - name 为空时忽略该 delta
fn parse_tool_call_event(delta: &serde_json::Value) -> Option<LlmStreamEvent> {
    let first_call = delta
        .get("tool_calls")
        .and_then(|t| t.as_array())
        .and_then(|tool_calls| tool_calls.first())?;

    let function = first_call.get("function");
    let name = function
        .and_then(|f| f.get("name"))
        .and_then(|n| n.as_str())
        .unwrap_or("")
        .to_owned();
    if name.is_empty() {
        return None;
    }

    Some(LlmStreamEvent::ToolCall {
        tool_call: LlmToolCall {
            id: first_call
                .get("id")
                .and_then(|i| i.as_str())
                .unwrap_or("")
                .to_owned(),
            name,
            arguments: function
                .and_then(|f| f.get("arguments"))
                .and_then(|a| a.as_str())
                .unwrap_or("{}")
                .to_owned(),
        },
    })
}

/// parse_sse_stream 解析完整 SSE 文本流为事件列表
/// 核心职责：
/// - 用于测试和同步解析场景
#[must_use]
pub fn parse_sse_stream(text: &str) -> Vec<AiResult<LlmStreamEvent>> {
    let (events, _remaining) = parse_sse_buffer(text);
    events
}
