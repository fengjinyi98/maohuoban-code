// OpenAiProviderDiagnostics OpenAI 兼容 Provider 诊断
// 核心职责：
// - 记录实际发给上游的请求策略摘要
// - 记录 SSE 解码阶段的脱敏失败证据

use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};

use maohuoban_ai_domain::ai::{AiError, LlmChatRequest, LlmRole};
use maohuoban_diagnostics::{DiagnosticEvent, Diagnostics, EventKind, Severity};
use serde_json::Value;

use super::openai_stream_stats::ProviderStreamStats;

const AI_RUNTIME_FAIL_DEBUG_TAG: &str = "[DEBUG:AiRuntimeFail]";

/// OpenAiProviderDiagnostics OpenAI 兼容 Provider 诊断
/// 核心职责：
/// - 只记录协议层计数、开关、阶段推断和哈希
/// - 避免记录用户正文、工具结果、Authorization 和原始上游响应
pub(crate) struct OpenAiProviderDiagnostics;

impl OpenAiProviderDiagnostics {
    /// record_request_prepared 记录实际 Provider 请求体摘要
    /// 核心职责：
    /// - 确认 Runtime 策略进入 provider 后是否被配置覆盖
    /// - 标记工具、JSON Output、stream 和 max_tokens 等关键开关
    pub(crate) fn record_request_prepared(
        mode: &'static str,
        request: &LlmChatRequest,
        body: &Value,
        model: &str,
        base_url: &str,
    ) {
        let Some(diagnostics) = Diagnostics::current() else {
            return;
        };
        let event = DiagnosticEvent::new(
            EventKind::Analytics,
            Severity::Debug,
            "ai.provider.openai.request.prepared",
        )
        .metadata("debug_tag", serde_json::json!(AI_RUNTIME_FAIL_DEBUG_TAG))
        .metadata("mode", serde_json::json!(mode))
        .metadata("phase_guess", serde_json::json!(phase_guess(request)))
        .metadata("base_url_kind", serde_json::json!(base_url_kind(base_url)))
        .metadata("model", serde_json::json!(model))
        .metadata(
            "request_stream",
            serde_json::json!(body.get("stream").and_then(Value::as_bool).unwrap_or(false)),
        )
        .metadata("body_tool_count", serde_json::json!(body_tool_count(body)))
        .metadata(
            "body_response_format_present",
            serde_json::json!(body.get("response_format").is_some()),
        )
        .metadata(
            "body_response_format_type",
            serde_json::json!(response_format_type(body.get("response_format"))),
        )
        .metadata(
            "body_max_tokens_present",
            serde_json::json!(body.get("max_tokens").is_some()),
        )
        .metadata(
            "tool_choice_present",
            serde_json::json!(body.get("tool_choice").is_some()),
        )
        .metadata(
            "message_roles",
            serde_json::json!(request_message_roles(request)),
        )
        .metadata("message_count", serde_json::json!(request.messages.len()))
        .metadata(
            "assistant_tool_call_message_count",
            serde_json::json!(assistant_tool_call_message_count(request)),
        )
        .metadata(
            "tool_result_message_count",
            serde_json::json!(tool_result_message_count(request)),
        )
        .metadata(
            "has_json_instruction",
            serde_json::json!(request_has_json_instruction(request)),
        );
        diagnostics.record(event);
    }

    /// record_http_response_started 记录上游 HTTP 响应入口
    /// 核心职责：
    /// - 标记 HTTP 状态和内容类型族
    /// - 不记录响应 body
    pub(crate) fn record_http_response_started(
        mode: &'static str,
        request: &LlmChatRequest,
        status: u16,
        content_type: Option<&str>,
    ) {
        let Some(diagnostics) = Diagnostics::current() else {
            return;
        };
        let event = DiagnosticEvent::new(
            EventKind::Analytics,
            severity_from_status(status),
            "ai.provider.openai.http.response.started",
        )
        .metadata("debug_tag", serde_json::json!(AI_RUNTIME_FAIL_DEBUG_TAG))
        .metadata("mode", serde_json::json!(mode))
        .metadata("phase_guess", serde_json::json!(phase_guess(request)))
        .metadata("http_status", serde_json::json!(status))
        .metadata(
            "content_type_kind",
            serde_json::json!(content_type_kind(content_type)),
        );
        diagnostics.record(event);
    }

    /// record_stream_decode_error 记录 SSE 解码失败
    /// 核心职责：
    /// - 捕获解码器看到的错误分类和流计数
    /// - 只记录脱敏错误摘要
    pub(crate) fn record_stream_decode_error(
        request: &LlmChatRequest,
        error: &AiError,
        stats: ProviderStreamStats,
        decoder_idle: bool,
    ) {
        Self::record_stream_terminal_event(
            "ai.provider.openai.stream.decode_error",
            Severity::Error,
            request,
            Some(error),
            stats,
            decoder_idle,
        );
    }

    /// record_stream_completed 记录 SSE 正常结束
    /// 核心职责：
    /// - 输出 chunk 和事件计数
    /// - 区分 finish 与 DONE 标记是否到达
    pub(crate) fn record_stream_completed(
        request: &LlmChatRequest,
        stats: ProviderStreamStats,
        decoder_idle: bool,
    ) {
        Self::record_stream_terminal_event(
            "ai.provider.openai.stream.completed",
            Severity::Debug,
            request,
            None,
            stats,
            decoder_idle,
        );
    }

    /// record_stream_incomplete 记录 SSE 非正常结束
    /// 核心职责：
    /// - 标记 completion marker 或 decoder idle 缺失
    /// - 支撑 stream_interrupted 与 invalid_response 分流
    pub(crate) fn record_stream_incomplete(
        request: &LlmChatRequest,
        stats: ProviderStreamStats,
        decoder_idle: bool,
    ) {
        Self::record_stream_terminal_event(
            "ai.provider.openai.stream.incomplete",
            Severity::Error,
            request,
            None,
            stats,
            decoder_idle,
        );
    }

    fn record_stream_terminal_event(
        message: &'static str,
        severity: Severity,
        request: &LlmChatRequest,
        error: Option<&AiError>,
        stats: ProviderStreamStats,
        decoder_idle: bool,
    ) {
        let Some(diagnostics) = Diagnostics::current() else {
            return;
        };
        let event = DiagnosticEvent::new(EventKind::Analytics, severity, message)
            .metadata("debug_tag", serde_json::json!(AI_RUNTIME_FAIL_DEBUG_TAG))
            .metadata("phase_guess", serde_json::json!(phase_guess(request)))
            .metadata("chunk_count", serde_json::json!(stats.chunk_count))
            .metadata(
                "decoded_event_count",
                serde_json::json!(stats.decoded_event_count),
            )
            .metadata("delta_count", serde_json::json!(stats.delta_count))
            .metadata("tool_call_count", serde_json::json!(stats.tool_call_count))
            .metadata("finish_count", serde_json::json!(stats.finish_count))
            .metadata(
                "stream_completed",
                serde_json::json!(stats.stream_completed),
            )
            .metadata("decoder_idle", serde_json::json!(decoder_idle))
            .metadata(
                "provider_category",
                serde_json::json!(error.map_or("none", provider_category)),
            )
            .metadata(
                "error_detail_kind",
                serde_json::json!(error.map_or("none", error_detail_kind)),
            )
            .metadata(
                "diagnostic_message",
                serde_json::json!(
                    error
                        .and_then(sanitized_provider_message)
                        .unwrap_or_default()
                ),
            )
            .metadata(
                "error_message_hash",
                serde_json::json!(
                    error.map_or_else(String::new, |value| stable_hash(&value.to_string()))
                ),
            );
        diagnostics.record(event);
    }
}

fn body_tool_count(body: &Value) -> usize {
    body.get("tools")
        .and_then(Value::as_array)
        .map_or(0, Vec::len)
}

fn response_format_type(value: Option<&Value>) -> String {
    value
        .and_then(|format| format.get("type"))
        .and_then(Value::as_str)
        .map_or_else(|| "none".to_owned(), str::to_owned)
}

fn phase_guess(request: &LlmChatRequest) -> &'static str {
    if assistant_tool_call_message_count(request) > 0 || tool_result_message_count(request) > 0 {
        "followup"
    } else {
        "initial"
    }
}

fn request_message_roles(request: &LlmChatRequest) -> String {
    request
        .messages
        .iter()
        .map(|message| match message.role {
            LlmRole::System => "system",
            LlmRole::User => "user",
            LlmRole::Assistant => "assistant",
            LlmRole::Tool => "tool",
        })
        .collect::<Vec<_>>()
        .join(",")
}

fn assistant_tool_call_message_count(request: &LlmChatRequest) -> usize {
    request
        .messages
        .iter()
        .filter(|message| message.role == LlmRole::Assistant && !message.tool_calls.is_empty())
        .count()
}

fn tool_result_message_count(request: &LlmChatRequest) -> usize {
    request
        .messages
        .iter()
        .filter(|message| message.role == LlmRole::Tool)
        .count()
}

fn request_has_json_instruction(request: &LlmChatRequest) -> bool {
    request.messages.iter().any(|message| {
        matches!(message.role, LlmRole::System | LlmRole::User)
            && message.content.to_ascii_lowercase().contains("json")
    })
}

fn base_url_kind(base_url: &str) -> &'static str {
    if base_url.contains("localhost:3050") || base_url.contains("127.0.0.1:3050") {
        "local_3050"
    } else if base_url.contains("localhost") || base_url.contains("127.0.0.1") {
        "local"
    } else if base_url.contains("api.deepseek.com") {
        "deepseek"
    } else {
        "remote"
    }
}

fn content_type_kind(content_type: Option<&str>) -> &'static str {
    let Some(content_type) = content_type else {
        return "missing";
    };
    if content_type.contains("text/event-stream") {
        "event_stream"
    } else if content_type.contains("application/json") {
        "json"
    } else {
        "other"
    }
}

fn severity_from_status(status: u16) -> Severity {
    if status >= 400 {
        Severity::Error
    } else {
        Severity::Debug
    }
}

fn provider_category(error: &AiError) -> &'static str {
    match error {
        AiError::Provider(provider_error) => provider_error.category().as_str(),
        _ => "none",
    }
}

fn error_detail_kind(error: &AiError) -> &'static str {
    match error {
        AiError::Provider(provider_error) => {
            let message = provider_error.message();
            if message.contains("invalid sse json") {
                "invalid_sse_json"
            } else if message.contains("stream ended before completion marker") {
                "stream_ended_before_completion_marker"
            } else if message.starts_with("http ") {
                "http_status_error"
            } else {
                provider_error.category().as_str()
            }
        }
        _ => "other",
    }
}

fn sanitized_provider_message(error: &AiError) -> Option<String> {
    let AiError::Provider(provider_error) = error else {
        return None;
    };
    let message = provider_error.message();
    if message.contains("data_hash=") || message.contains("stream ended before completion marker") {
        Some(message.to_owned())
    } else {
        None
    }
}

fn stable_hash(value: &str) -> String {
    let mut hasher = DefaultHasher::new();
    value.hash(&mut hasher);
    format!("{:016x}", hasher.finish())
}
