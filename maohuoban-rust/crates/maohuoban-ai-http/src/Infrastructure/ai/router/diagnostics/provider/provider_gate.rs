use maohuoban_ai_application::ai::diagnostics::AiDiagnosticsCorrelation;
use maohuoban_ai_domain::ai::AiGateDecision;
use maohuoban_diagnostics::Severity;
use serde_json::json;
use uuid::Uuid;

use super::super::diagnostics_common::{
    gate_decision_code, intent_code, record_ai_event, uuid_prefix,
};

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
