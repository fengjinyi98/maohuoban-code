// OpenAiProviderDiagnostics OpenAI 兼容 Provider 诊断
// 核心职责：
// - 记录实际发给上游的请求摘要
// - 开发阶段记录完整请求体、响应体和流事件

use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};

use maohuoban_ai_application::ai::diagnostics::{
    AiDiagnosticsCorrelation, redact_ai_diagnostics_text, redact_ai_diagnostics_value,
};
use maohuoban_ai_domain::ai::{AiError, LlmChatRequest, LlmRole};
use maohuoban_diagnostics::{DiagnosticEvent, Diagnostics, EventKind, Severity};
use serde_json::Value;

use super::openai_stream_stats::ProviderStreamStats;

const AI_RUNTIME_FAIL_DEBUG_TAG: &str = "[DEBUG:AiRuntimeFail]";

/// OpenAiProviderDiagnostics OpenAI 兼容 Provider 诊断
/// 核心职责：
/// - 记录协议层计数、阶段推断和开发期完整载荷
/// - 避免记录 Authorization 等敏感认证字段
pub(crate) struct OpenAiProviderDiagnostics;

impl OpenAiProviderDiagnostics {
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
        let request_messages =
            redact_ai_diagnostics_value(&serde_json::json!(request_messages(request)));
        let request_tool_schemas =
            redact_ai_diagnostics_value(&serde_json::json!(request_tool_schemas(request)));
        let request_body = redact_ai_diagnostics_value(body);
        let request_body_text =
            redact_ai_diagnostics_text(&serde_json::to_string(&request_body).unwrap_or_default());
        let event = provider_diagnostic_event(
            "ai.provider.openai.request.prepared",
            Severity::Debug,
            request,
            model,
        )
        .metadata("mode", serde_json::json!(mode))
        .metadata("phase_guess", serde_json::json!(phase_guess(request)))
        .metadata("base_url_kind", serde_json::json!(base_url_kind(base_url)))
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
        )
        .metadata("request_messages", request_messages)
        .metadata("request_tool_schemas", request_tool_schemas)
        .metadata("request_body", request_body)
        .metadata("request_body_text", serde_json::json!(request_body_text));
        diagnostics.record(event);
    }

    pub(crate) fn record_http_response_started(
        mode: &'static str,
        request: &LlmChatRequest,
        model: &str,
        status: u16,
        content_type: Option<&str>,
        header_summary: &str,
    ) {
        let Some(diagnostics) = Diagnostics::current() else {
            return;
        };
        let event = provider_diagnostic_event(
            "ai.provider.openai.http.response.started",
            severity_from_status(status),
            request,
            model,
        )
        .metadata("mode", serde_json::json!(mode))
        .metadata("phase_guess", serde_json::json!(phase_guess(request)))
        .metadata("http_status", serde_json::json!(status))
        .metadata(
            "content_type_kind",
            serde_json::json!(content_type_kind(content_type)),
        )
        .metadata(
            "header_summary",
            serde_json::json!(redact_ai_diagnostics_text(header_summary)),
        );
        diagnostics.record(event);
    }

    pub(crate) fn record_http_response_body(
        mode: &'static str,
        request: &LlmChatRequest,
        model: &str,
        status: u16,
        response_body: &str,
    ) {
        let Some(diagnostics) = Diagnostics::current() else {
            return;
        };
        let event = provider_diagnostic_event(
            "ai.provider.openai.http.response.body",
            severity_from_status(status),
            request,
            model,
        )
        .metadata("mode", serde_json::json!(mode))
        .metadata("phase_guess", serde_json::json!(phase_guess(request)))
        .metadata("http_status", serde_json::json!(status))
        .metadata(
            "response_body",
            serde_json::json!(redact_ai_diagnostics_text(response_body)),
        );
        diagnostics.record(event);
    }

    pub(crate) fn record_stream_chunk(
        request: &LlmChatRequest,
        model: &str,
        chunk_index: u32,
        byte_len: usize,
        chunk_text: &str,
    ) {
        let Some(diagnostics) = Diagnostics::current() else {
            return;
        };
        let event = provider_diagnostic_event(
            "ai.provider.openai.stream.chunk",
            Severity::Debug,
            request,
            model,
        )
        .metadata("phase_guess", serde_json::json!(phase_guess(request)))
        .metadata("chunk_index", serde_json::json!(chunk_index))
        .metadata("byte_len", serde_json::json!(byte_len))
        .metadata(
            "chunk_text",
            serde_json::json!(redact_ai_diagnostics_text(chunk_text)),
        );
        diagnostics.record(event);
    }

    pub(crate) fn record_stream_event(
        request: &LlmChatRequest,
        model: &str,
        event_name: &str,
        payload: Value,
    ) {
        let Some(diagnostics) = Diagnostics::current() else {
            return;
        };
        let event = provider_diagnostic_event(
            "ai.provider.openai.stream.event",
            Severity::Debug,
            request,
            model,
        )
        .metadata("phase_guess", serde_json::json!(phase_guess(request)))
        .metadata("event_name", serde_json::json!(event_name))
        .metadata("payload", redact_ai_diagnostics_value(&payload));
        diagnostics.record(event);
    }

    pub(crate) fn record_stream_decode_error(
        request: &LlmChatRequest,
        model: &str,
        error: &AiError,
        stats: ProviderStreamStats,
        decoder_idle: bool,
    ) {
        Self::record_stream_terminal_event(
            "ai.provider.openai.stream.decode_error",
            Severity::Error,
            request,
            model,
            Some(error),
            stats,
            decoder_idle,
        );
    }

    pub(crate) fn record_stream_completed(
        request: &LlmChatRequest,
        model: &str,
        stats: ProviderStreamStats,
        decoder_idle: bool,
    ) {
        Self::record_stream_terminal_event(
            "ai.provider.openai.stream.completed",
            Severity::Debug,
            request,
            model,
            None,
            stats,
            decoder_idle,
        );
    }

    pub(crate) fn record_stream_incomplete(
        request: &LlmChatRequest,
        model: &str,
        stats: ProviderStreamStats,
        decoder_idle: bool,
    ) {
        Self::record_stream_terminal_event(
            "ai.provider.openai.stream.incomplete",
            Severity::Error,
            request,
            model,
            None,
            stats,
            decoder_idle,
        );
    }

    fn record_stream_terminal_event(
        message: &'static str,
        severity: Severity,
        request: &LlmChatRequest,
        model: &str,
        error: Option<&AiError>,
        stats: ProviderStreamStats,
        decoder_idle: bool,
    ) {
        let Some(diagnostics) = Diagnostics::current() else {
            return;
        };
        let event = provider_diagnostic_event(message, severity, request, model)
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

fn provider_diagnostic_event(
    message: &'static str,
    severity: Severity,
    request: &LlmChatRequest,
    model: &str,
) -> DiagnosticEvent {
    let mut event = DiagnosticEvent::new(EventKind::Analytics, severity, message)
        .metadata("debug_tag", serde_json::json!(AI_RUNTIME_FAIL_DEBUG_TAG));
    for (key, value) in
        AiDiagnosticsCorrelation::from_llm_diagnostics(&request.diagnostics_correlation)
            .with_provider("openai_compatible")
            .with_model(model)
            .to_metadata()
    {
        event = event.metadata(key, value);
    }
    event.metadata("model_route", serde_json::json!(request.model.as_str()))
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

fn request_messages(request: &LlmChatRequest) -> Vec<Value> {
    request
        .messages
        .iter()
        .map(|message| {
            serde_json::json!({
                "role": match message.role {
                    LlmRole::System => "system",
                    LlmRole::User => "user",
                    LlmRole::Assistant => "assistant",
                    LlmRole::Tool => "tool",
                },
                "content": message.content,
                "reasoning_content": message.reasoning_content,
                "tool_call_id": message.tool_call_id,
                "tool_calls": message.tool_calls,
            })
        })
        .collect()
}

fn request_tool_schemas(request: &LlmChatRequest) -> Vec<Value> {
    request
        .tools
        .iter()
        .map(|tool| {
            serde_json::json!({
                "name": tool.name,
                "description": tool.description,
                "parameters": tool.parameters,
            })
        })
        .collect()
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
