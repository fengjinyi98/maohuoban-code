//! sse SSE chunk 解析
//! 核心职责：
//! - 将 OpenAI 兼容 SSE chunk 解析为内部 LlmStreamEvent
//! - 支持 delta、finish、usage、error 和 [DONE] 标记

use std::collections::BTreeMap;

use maohuoban_ai_domain::ai::{
    AiError, AiResult, LlmFinishReason, LlmStreamEvent, LlmToolCall, LlmUsage, ProviderError,
    ProviderErrorCategory,
};

#[derive(Default)]
struct ToolCallFragment {
    id: Option<String>,
    name: Option<String>,
    arguments: String,
}

/// SseStreamDecoder OpenAI 兼容 SSE 流式解码器
/// 核心职责：
/// - 持有跨网络 chunk 的 SSE 缓冲区
/// - 聚合同一 tool call index 的 name 和 arguments 分片
pub(crate) struct SseStreamDecoder {
    buffer: String,
    tool_call_fragments: BTreeMap<u32, ToolCallFragment>,
}

impl SseStreamDecoder {
    /// new 构造空解码器
    #[must_use]
    pub(crate) fn new() -> Self {
        Self {
            buffer: String::new(),
            tool_call_fragments: BTreeMap::new(),
        }
    }

    /// push_str 追加 SSE 文本并返回已完成事件
    pub(crate) fn push_str(&mut self, input: &str) -> Vec<AiResult<LlmStreamEvent>> {
        self.buffer.push_str(input);
        let buffer = std::mem::take(&mut self.buffer);
        let mut events = Vec::new();
        let mut remaining = String::new();
        let mut event_lines: Vec<&str> = Vec::new();

        for line in buffer.split('\n') {
            if line.is_empty() {
                if !event_lines.is_empty() {
                    events.extend(self.parse_sse_event(&event_lines));
                    event_lines.clear();
                }
            } else {
                event_lines.push(line);
            }
        }

        for line in event_lines {
            remaining.push_str(line);
            remaining.push('\n');
        }
        self.buffer = remaining;

        events
    }

    /// remaining 返回未完成 SSE 事件文本
    #[must_use]
    pub(crate) fn remaining(&self) -> &str {
        &self.buffer
    }

    /// is_idle 判断当前解码器是否没有未完成事件或工具调用
    #[must_use]
    pub(crate) fn is_idle(&self) -> bool {
        self.buffer.trim().is_empty() && self.tool_call_fragments.is_empty()
    }

    /// parse_sse_event 解析单个 SSE 事件
    fn parse_sse_event(&mut self, lines: &[&str]) -> Vec<AiResult<LlmStreamEvent>> {
        let mut data_parts: Vec<&str> = Vec::new();

        for line in lines {
            if let Some(data) = line.strip_prefix("data: ") {
                data_parts.push(data);
            } else if let Some(data) = line.strip_prefix("data:") {
                data_parts.push(data);
            }
        }

        if data_parts.is_empty() {
            return Vec::new();
        }

        let data = data_parts.join("\n");

        if data.trim() == "[DONE]" {
            return self.flush_tool_calls();
        }

        let json: serde_json::Value = match serde_json::from_str(&data) {
            Ok(j) => j,
            Err(error) => {
                return vec![Err(AiError::Provider(ProviderError::new(
                    ProviderErrorCategory::InvalidResponse,
                    format!("invalid sse json: {error}"),
                )))];
            }
        };

        if let Some(error) = json.get("error") {
            return vec![parse_error_event(error)];
        }

        let Some(choices) = json.get("choices").and_then(serde_json::Value::as_array) else {
            return Vec::new();
        };
        let Some(choice) = choices.first() else {
            return Vec::new();
        };

        let mut events = Vec::new();
        if let Some(delta) = choice.get("delta") {
            self.merge_tool_call_delta(delta);
            if let Some(content) = delta.get("content").and_then(serde_json::Value::as_str) {
                if !content.is_empty() {
                    events.push(Ok(LlmStreamEvent::Delta {
                        content: content.to_owned(),
                    }));
                }
            }
        }

        if let Some(finish) = parse_finish_event(choice, &json) {
            events.extend(self.flush_tool_calls());
            events.push(Ok(finish));
        }

        events
    }

    /// merge_tool_call_delta 合并工具调用分片
    /// 核心职责：
    /// - 以 OpenAI tool call index 归并同一调用
    /// - 分别追加 function.arguments 片段并保留首个非空 name/id
    fn merge_tool_call_delta(&mut self, delta: &serde_json::Value) {
        let Some(tool_calls) = delta
            .get("tool_calls")
            .and_then(serde_json::Value::as_array)
        else {
            return;
        };

        for (fallback_index, tool_call) in tool_calls.iter().enumerate() {
            let index = tool_call
                .get("index")
                .and_then(serde_json::Value::as_u64)
                .and_then(|value| u32::try_from(value).ok())
                .unwrap_or_else(|| u32::try_from(fallback_index).unwrap_or(u32::MAX));
            let fragment = self.tool_call_fragments.entry(index).or_default();

            if fragment.id.is_none() {
                fragment.id = tool_call
                    .get("id")
                    .and_then(serde_json::Value::as_str)
                    .filter(|id| !id.is_empty())
                    .map(str::to_owned);
            }

            if let Some(function) = tool_call.get("function") {
                if fragment.name.is_none() {
                    fragment.name = function
                        .get("name")
                        .and_then(serde_json::Value::as_str)
                        .filter(|name| !name.is_empty())
                        .map(str::to_owned);
                }

                if let Some(arguments) = function
                    .get("arguments")
                    .and_then(serde_json::Value::as_str)
                {
                    fragment.arguments.push_str(arguments);
                }
            }
        }
    }

    /// flush_tool_calls 输出已聚合工具调用
    /// 核心职责：
    /// - 丢弃没有 name 的不完整工具调用
    /// - 保持 index 顺序稳定输出给 Runtime
    fn flush_tool_calls(&mut self) -> Vec<AiResult<LlmStreamEvent>> {
        let fragments = std::mem::take(&mut self.tool_call_fragments);
        fragments
            .into_values()
            .filter_map(|fragment| {
                let name = fragment.name?;
                Some(Ok(LlmStreamEvent::ToolCall {
                    tool_call: LlmToolCall {
                        id: fragment.id.unwrap_or_default(),
                        name,
                        arguments: if fragment.arguments.is_empty() {
                            "{}".to_owned()
                        } else {
                            fragment.arguments
                        },
                    },
                }))
            })
            .collect()
    }
}

/// parse_sse_buffer 解析 SSE 缓冲区
/// 核心职责：
/// - 按空行分割 SSE 事件
/// - 返回已解析事件列表和剩余不完整数据
#[must_use]
pub fn parse_sse_buffer(buffer: &str) -> (Vec<AiResult<LlmStreamEvent>>, String) {
    let mut decoder = SseStreamDecoder::new();
    let events = decoder.push_str(buffer);
    (events, decoder.remaining().to_owned())
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

/// parse_sse_stream 解析完整 SSE 文本流为事件列表
/// 核心职责：
/// - 用于测试和同步解析场景
#[must_use]
pub fn parse_sse_stream(text: &str) -> Vec<AiResult<LlmStreamEvent>> {
    let (events, _remaining) = parse_sse_buffer(text);
    events
}
