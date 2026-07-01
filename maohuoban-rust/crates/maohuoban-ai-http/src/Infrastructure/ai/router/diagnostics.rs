use maohuoban_ai_application::ai::diagnostics::{
    AiDiagnosticsCorrelation, redact_ai_diagnostics_text, redact_ai_diagnostics_value,
};
use maohuoban_ai_domain::ai::{
    AgentSessionWorkbench, AiConversationSurface, AiGateDecision, AiStreamEvent,
};
use maohuoban_diagnostics::Severity;
use serde_json::{Value, json};
use uuid::Uuid;

use super::diagnostics_common::{
    gate_decision_code, intent_code, length_bucket, record_ai_event, stream_event_metadata,
    stream_event_severity, surface_code, uuid_prefix,
};
pub(crate) use super::history_diagnostics::{
    record_history_messages_loaded, record_history_mutation_completed,
    record_history_sessions_loaded,
};

/// record_chat_stream_request_received 记录流式聊天请求入口
/// 核心职责：
/// - 标记后端已接收到当前用户的 AI stream 请求
/// - 只保留脱敏 ID、入口 surface 和消息长度分桶
pub(crate) fn record_chat_stream_request_received(
    actor_user_id: Uuid,
    session_id: Uuid,
    message_id: Uuid,
    selected_pet_id: Option<Uuid>,
    surface: AiConversationSurface,
    message: &str,
) {
    let mut metadata = AiDiagnosticsCorrelation::for_session(session_id)
        .with_message_id(message_id)
        .to_metadata();
    metadata.extend(vec![
        (
            "actor_user_id_prefix",
            json!(uuid_prefix(Some(actor_user_id))),
        ),
        (
            "selected_pet_id_prefix",
            json!(uuid_prefix(selected_pet_id)),
        ),
        ("surface", json!(surface_code(surface))),
        ("message", json!(redact_ai_diagnostics_text(message))),
        (
            "message_length_bucket",
            json!(length_bucket(message.chars().count())),
        ),
        ("has_selected_pet", json!(selected_pet_id.is_some())),
    ]);
    record_ai_event("ai.chat.stream.request.received", Severity::Info, metadata);
}

/// record_chat_gate_decided 记录 AI gate 决策
/// 核心职责：
/// - 暴露意图分类、是否加载上下文和宠物解析结果
/// - 支撑 off-topic、provider 分支和历史持久化归因
pub(crate) fn record_chat_gate_decided(
    session_id: Uuid,
    selected_pet_id: Option<Uuid>,
    resolved_pet_id: Option<Uuid>,
    gate_decision: &AiGateDecision,
) {
    let mut metadata = AiDiagnosticsCorrelation::for_session(session_id).to_metadata();
    metadata.extend(vec![
        (
            "selected_pet_id_prefix",
            json!(uuid_prefix(selected_pet_id)),
        ),
        (
            "resolved_pet_id_prefix",
            json!(uuid_prefix(resolved_pet_id)),
        ),
        ("intent", json!(intent_code(gate_decision.intent))),
        ("gate_decision", json!(gate_decision_code(gate_decision))),
        ("context_loaded", json!(gate_decision.context_loaded)),
        ("allow_processing", json!(gate_decision.allow_processing())),
        (
            "risk_signal_present",
            json!(gate_decision.risk_signal.is_some()),
        ),
    ]);
    record_ai_event("ai.chat.gate.decided", Severity::Info, metadata);
}

/// record_chat_provider_started 记录进入 Provider 分支
/// 核心职责：
/// - 区分 gate 跳过和真实 Provider 链路
/// - 标记目标宠物、初始事件和事实包准备状态
pub(crate) fn record_chat_provider_started(
    session_id: Uuid,
    message_id: Uuid,
    engine_mode: &str,
    target_pet_present: bool,
    initial_event_count: usize,
    fact_package_present: bool,
) {
    let mut metadata = AiDiagnosticsCorrelation::for_session(session_id)
        .with_message_id(message_id)
        .to_metadata();
    metadata.extend(vec![
        ("engine_mode", json!(engine_mode)),
        ("target_pet_present", json!(target_pet_present)),
        ("initial_event_count", json!(initial_event_count)),
        ("fact_package_present", json!(fact_package_present)),
    ]);
    record_ai_event("ai.chat.provider.started", Severity::Info, metadata);
}

/// record_chat_runtime_engine_selected 记录 Runtime engine 选择结果
/// 核心职责：
/// - 在成功链路显式暴露 self_hosted
/// - 关联 route、stream、工具数量和目标宠物状态
pub(crate) fn record_chat_runtime_engine_selected(
    session_id: Uuid,
    message_id: Uuid,
    engine_mode: &str,
    route: &str,
    stream: bool,
    target_pet_present: bool,
    tool_count: usize,
) {
    let mut metadata = AiDiagnosticsCorrelation::for_session(session_id)
        .with_message_id(message_id)
        .to_metadata();
    metadata.extend(vec![
        ("engine_mode", json!(engine_mode)),
        ("route", json!(route)),
        ("stream", json!(stream)),
        ("target_pet_present", json!(target_pet_present)),
        ("tool_count", json!(tool_count)),
    ]);
    record_ai_event("ai.chat.runtime.engine.selected", Severity::Info, metadata);
}

/// record_chat_workbench_built 记录本轮 Workbench 观测基线
/// 核心职责：
/// - 固定能力目录、可见工具、上下文摘要和记忆/历史计数字段
/// - 支撑后续 planner、skill 和 memory worktree 复用同一观测边界
pub(crate) fn record_chat_workbench_built(
    session_id: Uuid,
    message_id: Uuid,
    workbench: &AgentSessionWorkbench,
    visible_tool_names: &[String],
) {
    let recent_conversation_count = workbench
        .recent_conversation_pack
        .as_ref()
        .map_or(0, |pack| pack.entries.len());
    let mut metadata = AiDiagnosticsCorrelation::for_session(session_id)
        .with_message_id(message_id)
        .to_metadata();
    metadata.extend(vec![
        (
            "capability_catalog",
            json!(
                workbench
                    .capability_catalog
                    .capabilities
                    .iter()
                    .map(|capability| capability.code.clone())
                    .collect::<Vec<_>>()
            ),
        ),
        ("visible_tools", json!(visible_tool_names)),
        (
            "context_summary_present",
            json!(workbench.context_pack.session_summary.is_some()),
        ),
        (
            "context_summary_length_bucket",
            json!(length_bucket(
                workbench
                    .context_pack
                    .session_summary
                    .as_deref()
                    .map_or(0, |summary| summary.chars().count())
            )),
        ),
        ("memory_count", json!(workbench.memory_pack.entries.len())),
        (
            "recent_conversation_count",
            json!(recent_conversation_count),
        ),
        (
            "selected_pet_present",
            json!(workbench.context_pack.selected_pet.is_some()),
        ),
        (
            "authorized_pet_count",
            json!(workbench.context_pack.authorized_pets.len()),
        ),
    ]);
    record_ai_event("ai.chat.workbench.built", Severity::Info, metadata);
}

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
