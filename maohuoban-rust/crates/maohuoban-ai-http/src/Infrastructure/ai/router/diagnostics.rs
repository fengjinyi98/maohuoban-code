use maohuoban_ai_application::ai::diagnostics::{
    AiDiagnosticsCorrelation, redact_ai_diagnostics_text, redact_ai_diagnostics_value,
};
use maohuoban_ai_application::ai::finalizer::{
    FinalizationReceipt, FinalizerAsyncJobKind, FinalizerSynchronousWrite,
};
use maohuoban_ai_application::ai::planning::PlanningDiagnosticsSnapshot;
use maohuoban_ai_domain::ai::{
    AgentSessionWorkbench, AiContentBlock, AiConversationSurface, AiGateDecision,
    AiSessionTurnStatus, AiStreamEvent,
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

/// record_chat_stream_ingress_received 记录流式入口到达
/// 核心职责：
/// - 在鉴权前记录 AI stream 请求已到达后端
/// - 为鉴权短路场景补齐 AI 专项观测点
pub(crate) fn record_chat_stream_ingress_received(
    chat_session_id: Option<Uuid>,
    selected_pet_id: Option<Uuid>,
    surface: AiConversationSurface,
    message: &str,
) {
    record_chat_ingress_received(
        "ai.chat.stream.ingress.received",
        chat_session_id,
        selected_pet_id,
        surface,
        message,
    );
}

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

/// record_chat_stream_auth_succeeded 记录流式入口鉴权成功
pub(crate) fn record_chat_stream_auth_succeeded(
    actor_user_id: Uuid,
    chat_session_id: Option<Uuid>,
    selected_pet_id: Option<Uuid>,
    surface: AiConversationSurface,
    message: &str,
) {
    record_chat_auth_result(
        "ai.chat.stream.auth.succeeded",
        Severity::Info,
        Some(actor_user_id),
        chat_session_id,
        selected_pet_id,
        surface,
        message,
        None,
        None,
        None,
    );
}

/// record_chat_stream_auth_failed 记录流式入口鉴权失败
pub(crate) fn record_chat_stream_auth_failed(
    chat_session_id: Option<Uuid>,
    selected_pet_id: Option<Uuid>,
    surface: AiConversationSurface,
    message: &str,
    has_authorization: bool,
    bearer_prefix_present: bool,
    error_code: &str,
) {
    record_chat_auth_result(
        "ai.chat.stream.auth.failed",
        Severity::Error,
        None,
        chat_session_id,
        selected_pet_id,
        surface,
        message,
        Some(has_authorization),
        Some(bearer_prefix_present),
        Some(error_code),
    );
}

/// record_chat_non_stream_ingress_received 记录非流式入口到达
pub(crate) fn record_chat_non_stream_ingress_received(
    chat_session_id: Option<Uuid>,
    selected_pet_id: Option<Uuid>,
    surface: AiConversationSurface,
    message: &str,
) {
    record_chat_ingress_received(
        "ai.chat.non_stream.ingress.received",
        chat_session_id,
        selected_pet_id,
        surface,
        message,
    );
}

/// record_chat_non_stream_auth_succeeded 记录非流式入口鉴权成功
pub(crate) fn record_chat_non_stream_auth_succeeded(
    actor_user_id: Uuid,
    chat_session_id: Option<Uuid>,
    selected_pet_id: Option<Uuid>,
    surface: AiConversationSurface,
    message: &str,
) {
    record_chat_auth_result(
        "ai.chat.non_stream.auth.succeeded",
        Severity::Info,
        Some(actor_user_id),
        chat_session_id,
        selected_pet_id,
        surface,
        message,
        None,
        None,
        None,
    );
}

/// record_chat_non_stream_auth_failed 记录非流式入口鉴权失败
pub(crate) fn record_chat_non_stream_auth_failed(
    chat_session_id: Option<Uuid>,
    selected_pet_id: Option<Uuid>,
    surface: AiConversationSurface,
    message: &str,
    has_authorization: bool,
    bearer_prefix_present: bool,
    error_code: &str,
) {
    record_chat_auth_result(
        "ai.chat.non_stream.auth.failed",
        Severity::Error,
        None,
        chat_session_id,
        selected_pet_id,
        surface,
        message,
        Some(has_authorization),
        Some(bearer_prefix_present),
        Some(error_code),
    );
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

/// record_chat_render_plan_selected 记录本轮允许的结构化渲染块类型
pub(crate) fn record_chat_render_plan_selected(
    session_id: Uuid,
    message_id: Uuid,
    surface: AiConversationSurface,
    target_pet_present: bool,
    allowed_block_kinds: &[&str],
) {
    let mut metadata = AiDiagnosticsCorrelation::for_session(session_id)
        .with_message_id(message_id)
        .to_metadata();
    metadata.extend(vec![
        ("surface", json!(surface_code(surface))),
        ("target_pet_present", json!(target_pet_present)),
        ("allowed_block_kinds", json!(allowed_block_kinds)),
    ]);
    record_ai_event("ai.chat.render_plan.selected", Severity::Info, metadata);
}

/// record_chat_workbench_built 记录本轮 Workbench 观测基线
/// 核心职责：
/// - 固定能力目录、可见工具、上下文摘要和记忆/历史计数字段
/// - 支撑后续 planner、skill 和 memory worktree 复用同一观测边界
pub(crate) fn record_chat_workbench_built(
    session_id: Uuid,
    turn_id: Uuid,
    message_id: Uuid,
    workbench: &AgentSessionWorkbench,
    visible_tool_names: &[String],
) {
    let recent_conversation_count = workbench
        .recent_conversation_pack
        .as_ref()
        .map_or(0, |pack| pack.entries.len());
    let mut metadata = AiDiagnosticsCorrelation::for_session(session_id)
        .with_turn_id(turn_id)
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

fn record_chat_ingress_received(
    event_name: &str,
    chat_session_id: Option<Uuid>,
    selected_pet_id: Option<Uuid>,
    surface: AiConversationSurface,
    message: &str,
) {
    record_ai_event(
        event_name,
        Severity::Info,
        vec![
            (
                "chat_session_id_prefix",
                json!(uuid_prefix(chat_session_id)),
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
            (
                "has_existing_chat_session",
                json!(chat_session_id.is_some()),
            ),
        ],
    );
}

#[allow(clippy::too_many_arguments)]
fn record_chat_auth_result(
    event_name: &str,
    severity: Severity,
    actor_user_id: Option<Uuid>,
    chat_session_id: Option<Uuid>,
    selected_pet_id: Option<Uuid>,
    surface: AiConversationSurface,
    message: &str,
    has_authorization: Option<bool>,
    bearer_prefix_present: Option<bool>,
    error_code: Option<&str>,
) {
    let mut metadata = vec![
        (
            "chat_session_id_prefix",
            json!(uuid_prefix(chat_session_id)),
        ),
        ("actor_user_id_prefix", json!(uuid_prefix(actor_user_id))),
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
        (
            "has_existing_chat_session",
            json!(chat_session_id.is_some()),
        ),
    ];
    if let Some(value) = has_authorization {
        metadata.push(("has_authorization", json!(value)));
    }
    if let Some(value) = bearer_prefix_present {
        metadata.push(("bearer_prefix_present", json!(value)));
    }
    if let Some(value) = error_code {
        metadata.push(("auth_error_code", json!(value)));
    }
    record_ai_event(event_name, severity, metadata);
}

fn turn_status_code(status: AiSessionTurnStatus) -> &'static str {
    status.as_str()
}

fn synchronous_write_code(write: FinalizerSynchronousWrite) -> &'static str {
    match write {
        FinalizerSynchronousWrite::AssistantMessage => "assistant_message",
        FinalizerSynchronousWrite::Citations => "citations",
        FinalizerSynchronousWrite::ProposedActions => "proposed_actions",
        FinalizerSynchronousWrite::TurnStatus => "turn_status",
        FinalizerSynchronousWrite::SessionHeader => "session_header",
    }
}

fn async_job_code(job: FinalizerAsyncJobKind) -> &'static str {
    match job {
        FinalizerAsyncJobKind::SessionSummary => "session_summary",
        FinalizerAsyncJobKind::MemoryCandidate => "memory_candidate",
        FinalizerAsyncJobKind::Evaluation => "evaluation",
    }
}

fn content_block_kind_code(block: &AiContentBlock) -> &'static str {
    match block {
        AiContentBlock::SectionHeading { .. } => "section_heading",
        AiContentBlock::Paragraph { .. } => "paragraph",
        AiContentBlock::PetProfileCardSkeleton { .. } => "pet_profile_card_skeleton",
        AiContentBlock::PetProfileCard { .. } => "pet_profile_card",
    }
}
