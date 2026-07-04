// agent_runtime_diagnostics Runtime 模型调用诊断
// 核心职责：
// - 记录 Runtime 阶段、请求策略和 provider 错误归因
// - 保证诊断事件只包含脱敏计数、开关和哈希

use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};

use maohuoban_ai_domain::ai::AiAnswerVerification;
use maohuoban_ai_domain::ai::{AiError, LlmChatRequest, LlmDiagnosticsCorrelation, LlmRole};
use maohuoban_diagnostics::{DiagnosticEvent, Diagnostics, EventKind, Severity};
use serde_json::Value;
use uuid::Uuid;

use crate::ai::diagnostics::{
    AiDiagnosticsCorrelation, redact_ai_diagnostics_text, redact_ai_diagnostics_value,
};
use crate::ai::planning::PlanningDiagnosticsSnapshot;

const AI_RUNTIME_FAIL_DEBUG_TAG: &str = "[DEBUG:AiRuntimeFail]";

/// LoopRoundCompletion Runtime 单轮模型完成摘要
/// 核心职责：
/// - 聚合模型阶段完成诊断字段
/// - 降低诊断记录入口参数数量
#[derive(Clone, Copy)]
pub(super) struct LoopRoundCompletion<'a> {
    pub(super) correlation: &'a LlmDiagnosticsCorrelation,
    pub(super) phase: &'static str,
    pub(super) round: u8,
    pub(super) tool_calls_count: usize,
    pub(super) finish_reason: &'a str,
    pub(super) usage: &'a maohuoban_ai_domain::ai::LlmUsage,
    pub(super) accumulated_total_tokens: u32,
}

/// AgentRuntimeDiagnostics Runtime 模型调用诊断
/// 核心职责：
/// - 记录模型请求和模型流错误摘要
/// - 保持诊断字段脱敏且可关联 Runtime 阶段
pub(super) struct AgentRuntimeDiagnostics;

impl AgentRuntimeDiagnostics {
    /// record_planning_snapshot 记录 Runtime 规划协议快照
    /// 核心职责：
    /// - 暴露 task_type、step_list、terminal_step 和 policy_decision
    /// - 固定 session_id、turn_id、message_id 三个规划关联键
    pub(super) fn record_planning_snapshot(snapshot: &PlanningDiagnosticsSnapshot) {
        let Some(diagnostics) = Diagnostics::current() else {
            return;
        };
        let mut event = DiagnosticEvent::new(
            EventKind::Analytics,
            Severity::Debug,
            "ai.runtime.planning.decided",
        )
        .metadata("debug_tag", serde_json::json!(AI_RUNTIME_FAIL_DEBUG_TAG));
        for (key, value) in snapshot.to_metadata_entries() {
            event = event.metadata(key, value);
        }
        diagnostics.record(event);
    }

    /// record_model_request_prepared 记录 Runtime 模型请求摘要
    pub(super) fn record_model_request_prepared(
        chat_session_id: Uuid,
        phase: &'static str,
        round: u8,
        request: &LlmChatRequest,
    ) {
        let Some(diagnostics) = Diagnostics::current() else {
            return;
        };
        let mut event = DiagnosticEvent::new(
            EventKind::Analytics,
            Severity::Debug,
            "ai.runtime.model.request.prepared",
        )
        .metadata("debug_tag", serde_json::json!(AI_RUNTIME_FAIL_DEBUG_TAG));
        for (key, value) in
            runtime_correlation(chat_session_id, &request.diagnostics_correlation).to_metadata()
        {
            event = event.metadata(key, value);
        }
        event = event
            .metadata("phase", serde_json::json!(phase))
            .metadata("round", serde_json::json!(round))
            .metadata("stream", serde_json::json!(request.stream))
            .metadata("tool_count", serde_json::json!(request.tools.len()))
            .metadata(
                "response_format_present",
                serde_json::json!(request.response_format.is_some()),
            )
            .metadata(
                "response_format_type",
                serde_json::json!(response_format_type(request.response_format.as_ref())),
            )
            .metadata(
                "max_output_tokens_present",
                serde_json::json!(request.max_output_tokens.is_some()),
            )
            .metadata("temperature", serde_json::json!(request.temperature))
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
            .metadata(
                "content_length_bucket",
                serde_json::json!(length_bucket(total_message_chars(request))),
            )
            .metadata(
                "message_contents",
                serde_json::json!(request_message_contents(request)),
            )
            .metadata(
                "message_reasoning_contents",
                serde_json::json!(request_reasoning_contents(request)),
            )
            .metadata(
                "tool_schemas",
                serde_json::json!(request_tool_schemas(request)),
            );
        diagnostics.record(event);
    }

    /// record_model_stream_error 记录 Runtime 模型流错误摘要
    pub(super) fn record_model_stream_error(
        chat_session_id: Uuid,
        correlation: &LlmDiagnosticsCorrelation,
        phase: &'static str,
        round: u8,
        tool_count: u32,
        error: &AiError,
    ) {
        let Some(diagnostics) = Diagnostics::current() else {
            return;
        };
        let mut event = DiagnosticEvent::new(
            EventKind::Analytics,
            Severity::Error,
            "ai.runtime.model.stream.error",
        )
        .metadata("debug_tag", serde_json::json!(AI_RUNTIME_FAIL_DEBUG_TAG));
        for (key, value) in runtime_correlation(chat_session_id, correlation).to_metadata() {
            event = event.metadata(key, value);
        }
        event = event
            .metadata("phase", serde_json::json!(phase))
            .metadata("round", serde_json::json!(round))
            .metadata("tool_count", serde_json::json!(tool_count))
            .metadata("stable_code", serde_json::json!(error.stable_code()))
            .metadata("retryable", serde_json::json!(error.is_retryable()))
            .metadata(
                "provider_category",
                serde_json::json!(provider_category(error)),
            )
            .metadata(
                "error_detail_kind",
                serde_json::json!(error_detail_kind(error)),
            )
            .metadata(
                "diagnostic_message_present",
                serde_json::json!(sanitized_provider_message(error).is_some()),
            )
            .metadata(
                "diagnostic_message",
                serde_json::json!(redact_ai_diagnostics_text(
                    &sanitized_provider_message(error).unwrap_or_default()
                )),
            )
            .metadata(
                "error_message_hash",
                serde_json::json!(stable_hash(&error.to_string())),
            )
            .metadata(
                "error_message_length",
                serde_json::json!(error.to_string().chars().count()),
            );
        diagnostics.record(event);
    }

    /// record_loop_round_completed 记录 Runtime 单轮模型阶段完成
    pub(super) fn record_loop_round_completed(
        chat_session_id: Uuid,
        completion: LoopRoundCompletion<'_>,
    ) {
        let Some(diagnostics) = Diagnostics::current() else {
            return;
        };
        let mut event = DiagnosticEvent::new(
            EventKind::Analytics,
            Severity::Info,
            "ai.runtime.loop.round.completed",
        )
        .metadata("debug_tag", serde_json::json!(AI_RUNTIME_FAIL_DEBUG_TAG));
        for (key, value) in
            runtime_correlation(chat_session_id, completion.correlation).to_metadata()
        {
            event = event.metadata(key, value);
        }
        event = event
            .metadata("phase", serde_json::json!(completion.phase))
            .metadata("round", serde_json::json!(completion.round))
            .metadata(
                "tool_calls_count",
                serde_json::json!(completion.tool_calls_count),
            )
            .metadata("finish_reason", serde_json::json!(completion.finish_reason))
            .metadata(
                "input_tokens",
                serde_json::json!(completion.usage.input_tokens),
            )
            .metadata(
                "output_tokens",
                serde_json::json!(completion.usage.output_tokens),
            )
            .metadata(
                "accumulated_total_tokens",
                serde_json::json!(completion.accumulated_total_tokens),
            );
        diagnostics.record(event);
    }

    /// record_turn_terminated 记录 Runtime turn 终止原因
    pub(super) fn record_turn_terminated(
        chat_session_id: Uuid,
        termination_reason: &str,
        total_rounds: u8,
        final_status: &str,
        accumulated_total_tokens: u32,
    ) {
        let Some(diagnostics) = Diagnostics::current() else {
            return;
        };
        diagnostics.record(
            DiagnosticEvent::new(
                EventKind::Analytics,
                Severity::Info,
                "ai.runtime.turn.terminated",
            )
            .metadata("debug_tag", serde_json::json!(AI_RUNTIME_FAIL_DEBUG_TAG))
            .metadata("chat_session_id", serde_json::json!(chat_session_id))
            .metadata("termination_reason", serde_json::json!(termination_reason))
            .metadata("total_rounds", serde_json::json!(total_rounds))
            .metadata("final_status", serde_json::json!(final_status))
            .metadata(
                "accumulated_total_tokens",
                serde_json::json!(accumulated_total_tokens),
            ),
        );
    }

    /// record_output_guard_decided 记录输出守卫裁决
    pub(super) fn record_output_guard_decided(
        chat_session_id: Uuid,
        verification: &AiAnswerVerification,
        repair_attempt: u8,
        candidate_answer: &str,
        successful_write_tools: &[String],
    ) {
        let Some(diagnostics) = Diagnostics::current() else {
            return;
        };
        diagnostics.record(
            DiagnosticEvent::new(
                EventKind::Analytics,
                Severity::Info,
                "ai.runtime.output_guard.decided",
            )
            .metadata("debug_tag", serde_json::json!(AI_RUNTIME_FAIL_DEBUG_TAG))
            .metadata("chat_session_id", serde_json::json!(chat_session_id))
            .metadata(
                "verdict",
                serde_json::json!(if verification.is_blocked() {
                    "blocked"
                } else {
                    "passed"
                }),
            )
            .metadata(
                "blocked_reason",
                serde_json::json!(
                    verification
                        .blocked_reason
                        .map(maohuoban_ai_domain::ai::AiBlockedReason::as_str)
                ),
            )
            .metadata("repair_attempt", serde_json::json!(repair_attempt))
            .metadata(
                "successful_write_tools",
                serde_json::json!(successful_write_tools),
            )
            .metadata(
                "evidence_refs",
                serde_json::json!(build_output_guard_evidence_refs(
                    verification,
                    successful_write_tools,
                )),
            )
            .metadata(
                "candidate_text_length_bucket",
                serde_json::json!(length_bucket(candidate_answer.chars().count())),
            ),
        );
    }
}

fn build_output_guard_evidence_refs(
    verification: &AiAnswerVerification,
    successful_write_tools: &[String],
) -> Vec<String> {
    match verification.blocked_reason {
        Some(maohuoban_ai_domain::ai::AiBlockedReason::UnconfirmedWrite) => {
            vec![format!(
                "tool_ledger.successful_write_tools:{}",
                successful_write_tools.join(",")
            )]
        }
        Some(maohuoban_ai_domain::ai::AiBlockedReason::WeakHintMisuse) => {
            vec!["fact_package.weak_hints".to_owned()]
        }
        Some(maohuoban_ai_domain::ai::AiBlockedReason::UnsupportedFact) => {
            vec!["fact_package.strong_facts".to_owned()]
        }
        Some(maohuoban_ai_domain::ai::AiBlockedReason::PrivacyBlocked) | None => Vec::new(),
    }
}

fn runtime_correlation(
    chat_session_id: Uuid,
    correlation: &LlmDiagnosticsCorrelation,
) -> AiDiagnosticsCorrelation {
    let mut value = AiDiagnosticsCorrelation::from_llm_diagnostics(correlation);
    if value.session_id.is_none() {
        value.session_id = Some(chat_session_id);
    }
    value
}

fn response_format_type(value: Option<&Value>) -> String {
    value
        .and_then(|format| format.get("type"))
        .and_then(Value::as_str)
        .map_or_else(|| "none".to_owned(), str::to_owned)
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

fn request_message_contents(request: &LlmChatRequest) -> Vec<String> {
    request
        .messages
        .iter()
        .map(|message| redact_ai_diagnostics_text(&message.content))
        .collect()
}

fn request_reasoning_contents(request: &LlmChatRequest) -> Vec<String> {
    request
        .messages
        .iter()
        .map(|message| {
            redact_ai_diagnostics_text(&message.reasoning_content.clone().unwrap_or_default())
        })
        .collect()
}

fn request_tool_schemas(request: &LlmChatRequest) -> Vec<serde_json::Value> {
    request
        .tools
        .iter()
        .map(|tool| {
            redact_ai_diagnostics_value(&serde_json::json!({
                "name": tool.name,
                "description": tool.description,
                "parameters": tool.parameters,
            }))
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

fn total_message_chars(request: &LlmChatRequest) -> usize {
    request
        .messages
        .iter()
        .map(|message| message.content.chars().count())
        .sum()
}

fn length_bucket(length: usize) -> &'static str {
    match length {
        0..=128 => "0-128",
        129..=512 => "129-512",
        513..=2048 => "513-2048",
        2049..=8192 => "2049-8192",
        _ => "8193+",
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
            } else if message.contains("empty assistant content without tool calls") {
                "empty_assistant_content_without_tool_calls"
            } else if message.contains("stream ended before completion marker") {
                "stream_ended_before_completion_marker"
            } else if message.starts_with("http ") {
                "http_status_error"
            } else {
                provider_error.category().as_str()
            }
        }
        AiError::Infrastructure(_) => "infrastructure",
        AiError::ProviderRequestFailed(_) => "provider_request_failed",
        AiError::ProviderStreamError(_) => "provider_stream_error",
        _ => "other",
    }
}

fn sanitized_provider_message(error: &AiError) -> Option<String> {
    let AiError::Provider(provider_error) = error else {
        return None;
    };
    let message = provider_error.message();
    if message.contains("data_hash=")
        || message.contains("stream ended before completion marker")
        || message.contains("empty assistant content without tool calls")
    {
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
