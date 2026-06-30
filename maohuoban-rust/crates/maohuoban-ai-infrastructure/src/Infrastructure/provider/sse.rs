//! sse SSE chunk 解析
//! 核心职责：
//! - 将 OpenAI 兼容 SSE chunk 解析为内部 LlmStreamEvent
//! - 支持 delta、finish、usage、error 和 [DONE] 标记

use std::collections::BTreeMap;
use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};
use std::io::Write;

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
        let mut events = Vec::new();

        while let Some((event_end, delimiter_len)) = next_sse_event_boundary(&self.buffer) {
            let event_text = self.buffer[..event_end].to_owned();
            self.buffer.drain(..event_end + delimiter_len);
            let event_lines: Vec<&str> = event_text.lines().collect();
            if !event_lines.is_empty() {
                events.extend(self.parse_sse_event(&event_lines));
            }
        }

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
        mhb_temp_backend_log(format!(
            "tag=AgentFallbackRegression stage=provider.sse_data lines={} data={:?}",
            lines.len(),
            data
        ));

        if data.trim() == "[DONE]" {
            mhb_temp_backend_log(
                "tag=AgentFallbackRegression stage=provider.sse_done".to_owned(),
            );
            return self.flush_tool_calls();
        }

        let json: serde_json::Value = match serde_json::from_str(&data) {
            Ok(j) => j,
            Err(error) => {
                mhb_temp_backend_log(format!(
                    "tag=AgentFallbackRegression stage=provider.sse_json_error error={error} data={:?}",
                    data
                ));
                return vec![Err(AiError::Provider(ProviderError::new(
                    ProviderErrorCategory::InvalidResponse,
                    invalid_sse_json_message(&data, &error),
                )))];
            }
        };

        if let Some(error) = json.get("error") {
            mhb_temp_backend_log(format!(
                "tag=AgentFallbackRegression stage=provider.sse_error_payload error={}",
                serde_json::to_string(error).unwrap_or_else(|_| "<json-encode-failed>".to_owned())
            ));
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
            if let Some(reasoning_content) = delta
                .get("reasoning_content")
                .and_then(serde_json::Value::as_str)
                && !reasoning_content.is_empty()
            {
                events.push(Ok(LlmStreamEvent::ReasoningDelta {
                    content: reasoning_content.to_owned(),
                }));
            }
            if let Some(content) = delta.get("content").and_then(serde_json::Value::as_str)
                && !content.is_empty()
            {
                events.push(Ok(LlmStreamEvent::Delta {
                    content: content.to_owned(),
                }));
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

// MHB_TEMP_BACKEND_LOG: AgentFallbackRegression 临时 SSE 解码日志，确认修复后删除。
fn mhb_temp_backend_log(line: impl AsRef<str>) {
    let path = std::env::var("MHB_BACKEND_TEMP_LOG")
        .unwrap_or_else(|_| "work/debug/AgentFallbackRegression.log".to_owned());
    if let Some(parent) = std::path::Path::new(&path).parent() {
        let _ = std::fs::create_dir_all(parent);
    }
    if let Ok(mut file) = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(&path)
    {
        let _ = writeln!(file, "{}", line.as_ref());
    }
}

/// next_sse_event_boundary 查找完整 SSE event 边界
/// 核心职责：
/// - 只以空行作为事件完成标记
/// - 保留网络 chunk 中未完成的最后一行
fn next_sse_event_boundary(buffer: &str) -> Option<(usize, usize)> {
    let lf = buffer.find("\n\n").map(|index| (index, 2));
    let crlf = buffer.find("\r\n\r\n").map(|index| (index, 4));

    match (lf, crlf) {
        (Some(left), Some(right)) => Some(if left.0 <= right.0 { left } else { right }),
        (Some(boundary), None) | (None, Some(boundary)) => Some(boundary),
        (None, None) => None,
    }
}

/// invalid_sse_json_message 构造脱敏 SSE 解析错误
/// 核心职责：
/// - 保留解析器错误、数据长度和哈希
/// - 避免把上游原始内容写入诊断或日志
fn invalid_sse_json_message(data: &str, error: &serde_json::Error) -> String {
    format!(
        "invalid sse json: parser={error}; data_len={}; data_hash={}; first_char_kind={}; line_count={}",
        data.chars().count(),
        stable_hash(data),
        first_char_kind(data),
        data.lines().count()
    )
}

fn stable_hash(value: &str) -> String {
    let mut hasher = DefaultHasher::new();
    value.hash(&mut hasher);
    format!("{:016x}", hasher.finish())
}

fn first_char_kind(value: &str) -> &'static str {
    match value.chars().next() {
        None => "empty",
        Some('{') => "object",
        Some('[') => "array",
        Some(ch) if ch.is_ascii_alphabetic() => "alpha",
        Some(ch) if ch.is_ascii_digit() => "digit",
        Some(ch) if ch.is_whitespace() => "whitespace",
        Some(_) => "other",
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
