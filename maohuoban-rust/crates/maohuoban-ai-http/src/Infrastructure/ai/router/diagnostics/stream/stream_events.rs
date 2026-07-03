use maohuoban_ai_application::ai::diagnostics::{
    AiDiagnosticsCorrelation, redact_ai_diagnostics_value,
};
use maohuoban_ai_application::ai::planning::PlanningDiagnosticsSnapshot;
use maohuoban_ai_domain::ai::{AiContentBlock, AiStreamEvent};
use maohuoban_diagnostics::Severity;
use serde_json::{Value, json};
use uuid::Uuid;

use super::super::diagnostics_common::{
    record_ai_event, stream_event_metadata, stream_event_severity, uuid_prefix,
};
use super::helpers::content_block_kind_code;

/// record_chat_stream_event_emitted 记录后端输出 SSE 事件
/// 核心职责：
/// - 记录稳定 SSE 事件名和关键状态
/// - 避免记录 delta 文本、最终回答全文和安全提示全文
pub(crate) fn record_chat_stream_event_emitted(session_id: Uuid, event: &AiStreamEvent) {
    let mut metadata = vec![
        (
            "chat_session_id_prefix",
            json!(uuid_prefix(Some(session_id))),
        ),
        ("event_name", json!(event.event_name())),
    ];
    metadata.extend(stream_event_metadata(event));
    record_ai_event(
        "ai.chat.stream.event.emitted",
        stream_event_severity(event),
        metadata,
    );
}

pub(crate) fn record_chat_content_blocks_emitted(
    session_id: Uuid,
    message_id: Uuid,
    event_name: &str,
    content_blocks: &[AiContentBlock],
) {
    let mut metadata = AiDiagnosticsCorrelation::for_session(session_id)
        .with_message_id(message_id)
        .to_metadata();
    metadata.extend(vec![
        ("event_name", json!(event_name)),
        ("block_count", json!(content_blocks.len())),
        (
            "block_kinds",
            json!(
                content_blocks
                    .iter()
                    .map(content_block_kind_code)
                    .collect::<Vec<_>>()
            ),
        ),
    ]);
    record_ai_event("ai.chat.content_blocks.emitted", Severity::Info, metadata);
}

pub(crate) fn record_chat_runtime_agent_event(
    session_id: Uuid,
    message_id: Uuid,
    event_name: &str,
    payload: &Value,
) {
    record_ai_event(
        "ai.chat.runtime.agent_event",
        Severity::Debug,
        vec![
            (
                "chat_session_id_prefix",
                json!(uuid_prefix(Some(session_id))),
            ),
            ("message_id_prefix", json!(uuid_prefix(Some(message_id)))),
            ("event_name", json!(event_name)),
            ("payload", redact_ai_diagnostics_value(payload)),
        ],
    );
}

/// record_chat_planning_decided 记录规划协议决策
/// 核心职责：
/// - 固定 task_type、step_list、current_step、replan_reason 和 policy_decision 字段
/// - 保持 HTTP diagnostics 与 Runtime planning snapshot 使用同一字段合同
pub(crate) fn record_chat_planning_decided(snapshot: &PlanningDiagnosticsSnapshot) {
    record_ai_event(
        "ai.chat.planning.decided",
        Severity::Info,
        snapshot.to_metadata_entries(),
    );
}
