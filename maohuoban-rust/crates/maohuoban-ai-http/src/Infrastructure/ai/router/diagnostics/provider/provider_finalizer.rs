use maohuoban_ai_application::ai::diagnostics::AiDiagnosticsCorrelation;
use maohuoban_ai_application::ai::finalizer::FinalizationReceipt;
use maohuoban_diagnostics::Severity;
use serde_json::json;
use uuid::Uuid;

use super::super::diagnostics_common::{record_ai_event, uuid_prefix};
use super::helpers::{async_job_code, synchronous_write_code, turn_status_code};

/// record_chat_provider_error 记录 Provider 错误分类
/// 核心职责：
/// - 捕获 provider 未配置、上游请求失败和流错误
/// - 保留前端可展示安全文案是否存在
pub(crate) fn record_chat_provider_error(
    session_id: Uuid,
    engine_mode: &str,
    code: &str,
    retryable: bool,
    safe_fallback_text: Option<&str>,
) {
    record_ai_event(
        "ai.chat.provider.error",
        Severity::Error,
        vec![
            (
                "chat_session_id_prefix",
                json!(uuid_prefix(Some(session_id))),
            ),
            ("engine_mode", json!(engine_mode)),
            ("error_code", json!(code)),
            ("retryable", json!(retryable)),
            (
                "safe_text_present",
                json!(safe_fallback_text.is_some_and(|text| !text.trim().is_empty())),
            ),
        ],
    );
}

/// record_chat_finalizer_completed 记录 Finalizer 收口完成事件
/// 核心职责：
/// - 暴露 turn 终态、同步写入对象和异步触发对象
/// - 将异步后处理失败作为 fail-open 诊断尾部记录
pub(crate) fn record_chat_finalizer_completed(
    session_id: Uuid,
    turn_id: Uuid,
    message_id: Option<Uuid>,
    receipt: &FinalizationReceipt,
) {
    let mut metadata = AiDiagnosticsCorrelation::for_session(session_id)
        .with_turn_id(turn_id)
        .to_metadata();
    if let Some(message_id) = message_id {
        metadata = AiDiagnosticsCorrelation::for_session(session_id)
            .with_turn_id(turn_id)
            .with_message_id(message_id)
            .to_metadata();
    }
    metadata.extend(vec![
        (
            "terminal_status",
            json!(turn_status_code(receipt.terminal_status)),
        ),
        (
            "synchronous_writes",
            json!(
                receipt
                    .synchronous_writes
                    .iter()
                    .map(|write| synchronous_write_code(*write))
                    .collect::<Vec<_>>()
            ),
        ),
        (
            "async_triggers",
            json!(
                receipt
                    .async_triggers
                    .iter()
                    .map(|job| async_job_code(*job))
                    .collect::<Vec<_>>()
            ),
        ),
        (
            "async_failures",
            json!(
                receipt
                    .async_failures
                    .iter()
                    .map(|failure| json!({
                        "job": async_job_code(failure.job_kind),
                        "error_code": failure.error_code,
                    }))
                    .collect::<Vec<_>>()
            ),
        ),
    ]);
    record_ai_event("ai.chat.finalizer.completed", Severity::Info, metadata);
}
