use maohuoban_ai_domain::ai::{
    AiAgentActivityStatus, AiAnswerVerification, AiCitation, AiConversationSurface, AiGateDecision,
    AiIntent, AiPetResolution, AiProposedAction, AiStreamEvent, AiToolCallStatus,
    AiVerificationStatus, LlmFinishReason, LlmUsage,
};
use maohuoban_diagnostics::{DiagnosticEvent, Diagnostics, EventKind, Severity};
use serde_json::{Value, json};
use uuid::Uuid;

/// record_chat_stream_request_received 记录流式聊天请求入口
/// 核心职责：
/// - 标记后端已接收到当前用户的 AI stream 请求
/// - 只保留脱敏 ID、入口 surface 和消息长度分桶
pub(crate) fn record_chat_stream_request_received(
    actor_user_id: Uuid,
    session_id: Uuid,
    selected_pet_id: Option<Uuid>,
    surface: AiConversationSurface,
    message: &str,
) {
    record_ai_event(
        "ai.chat.stream.request.received",
        Severity::Info,
        vec![
            (
                "actor_user_id_prefix",
                json!(uuid_prefix(Some(actor_user_id))),
            ),
            (
                "chat_session_id_prefix",
                json!(uuid_prefix(Some(session_id))),
            ),
            (
                "selected_pet_id_prefix",
                json!(uuid_prefix(selected_pet_id)),
            ),
            ("surface", json!(surface_code(surface))),
            (
                "message_length_bucket",
                json!(length_bucket(message.chars().count())),
            ),
            ("has_selected_pet", json!(selected_pet_id.is_some())),
        ],
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
    record_ai_event(
        "ai.chat.gate.decided",
        Severity::Info,
        vec![
            (
                "chat_session_id_prefix",
                json!(uuid_prefix(Some(session_id))),
            ),
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
        ],
    );
}

/// record_chat_session_persisted 记录会话和用户消息持久化结果
/// 核心职责：
/// - 标记 session upsert 与 user message insert 是否成功
/// - 关联用户、会话和目标宠物脱敏 ID
pub(crate) fn record_chat_session_persisted(
    actor_user_id: Uuid,
    session_id: Uuid,
    primary_pet_id: Option<Uuid>,
    session_persisted: bool,
    user_message_persisted: bool,
) {
    record_ai_event(
        "ai.chat.session.persisted",
        severity(session_persisted && user_message_persisted),
        vec![
            (
                "actor_user_id_prefix",
                json!(uuid_prefix(Some(actor_user_id))),
            ),
            (
                "chat_session_id_prefix",
                json!(uuid_prefix(Some(session_id))),
            ),
            ("primary_pet_id_prefix", json!(uuid_prefix(primary_pet_id))),
            ("session_persisted", json!(session_persisted)),
            ("user_message_persisted", json!(user_message_persisted)),
        ],
    );
}

/// record_chat_provider_started 记录进入 Provider 分支
/// 核心职责：
/// - 区分 gate 跳过和真实 Provider 链路
/// - 标记目标宠物、初始事件和事实包准备状态
pub(crate) fn record_chat_provider_started(
    session_id: Uuid,
    message_id: Uuid,
    target_pet_present: bool,
    initial_event_count: usize,
    fact_package_present: bool,
) {
    record_ai_event(
        "ai.chat.provider.started",
        Severity::Info,
        vec![
            (
                "chat_session_id_prefix",
                json!(uuid_prefix(Some(session_id))),
            ),
            ("message_id_prefix", json!(uuid_prefix(Some(message_id)))),
            ("target_pet_present", json!(target_pet_present)),
            ("initial_event_count", json!(initial_event_count)),
            ("fact_package_present", json!(fact_package_present)),
        ],
    );
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

/// record_chat_provider_error 记录 Provider 错误分类
/// 核心职责：
/// - 捕获 provider 未配置、上游请求失败和流错误
/// - 保留前端可展示安全文案是否存在
pub(crate) fn record_chat_provider_error(
    session_id: Uuid,
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
            ("error_code", json!(code)),
            ("retryable", json!(retryable)),
            (
                "safe_text_present",
                json!(safe_fallback_text.is_some_and(|text| !text.trim().is_empty())),
            ),
        ],
    );
}

/// record_chat_assistant_persisted 记录助手消息持久化结果
/// 核心职责：
/// - 关联 message_completed 与历史详情可见性
/// - 只记录完成原因、引用数量和 token 数
pub(crate) fn record_chat_assistant_persisted(
    session_id: Uuid,
    message_id: Uuid,
    success: bool,
    citation_count: usize,
    input_tokens: u32,
    output_tokens: u32,
    finish_reason: &str,
) {
    record_ai_event(
        "ai.chat.assistant.persisted",
        severity(success),
        vec![
            (
                "chat_session_id_prefix",
                json!(uuid_prefix(Some(session_id))),
            ),
            ("message_id_prefix", json!(uuid_prefix(Some(message_id)))),
            ("success", json!(success)),
            ("citation_count", json!(citation_count)),
            ("input_tokens", json!(input_tokens)),
            ("output_tokens", json!(output_tokens)),
            ("finish_reason", json!(finish_reason)),
        ],
    );
}

/// record_history_sessions_loaded 记录历史会话列表返回结果
/// 核心职责：
/// - 记录后端返回的会话、置顶和宠物快照数量
/// - 关联可授权宠物候选数量，定位头像补齐问题
pub(crate) fn record_history_sessions_loaded(
    actor_user_id: Uuid,
    session_count: usize,
    pinned_count: usize,
    pet_snapshot_count: usize,
    pet_candidate_count: usize,
) {
    record_ai_event(
        "ai.history.sessions.loaded",
        Severity::Info,
        vec![
            (
                "actor_user_id_prefix",
                json!(uuid_prefix(Some(actor_user_id))),
            ),
            ("session_count", json!(session_count)),
            ("pinned_count", json!(pinned_count)),
            ("pet_snapshot_count", json!(pet_snapshot_count)),
            ("pet_candidate_count", json!(pet_candidate_count)),
        ],
    );
}

/// record_history_messages_loaded 记录历史消息详情返回结果
/// 核心职责：
/// - 关联会话 ID 和返回消息数量
/// - 避免记录历史消息正文
pub(crate) fn record_history_messages_loaded(
    actor_user_id: Uuid,
    session_id: Uuid,
    message_count: usize,
) {
    record_ai_event(
        "ai.history.messages.loaded",
        Severity::Info,
        vec![
            (
                "actor_user_id_prefix",
                json!(uuid_prefix(Some(actor_user_id))),
            ),
            (
                "chat_session_id_prefix",
                json!(uuid_prefix(Some(session_id))),
            ),
            ("message_count", json!(message_count)),
        ],
    );
}

/// record_history_mutation_completed 记录历史会话操作结果
/// 核心职责：
/// - 统一观测重命名、置顶和删除动作
/// - 记录目标会话和操作是否成功
pub(crate) fn record_history_mutation_completed(
    action: &str,
    actor_user_id: Uuid,
    session_id: Uuid,
    success: bool,
) {
    record_ai_event(
        "ai.history.mutation.completed",
        severity(success),
        vec![
            ("action", json!(action)),
            (
                "actor_user_id_prefix",
                json!(uuid_prefix(Some(actor_user_id))),
            ),
            (
                "chat_session_id_prefix",
                json!(uuid_prefix(Some(session_id))),
            ),
            ("success", json!(success)),
        ],
    );
}

fn record_ai_event(name: &str, severity: Severity, metadata: Vec<(&str, Value)>) {
    let Some(diagnostics) = Diagnostics::current() else {
        return;
    };
    let mut event = DiagnosticEvent::new(EventKind::Analytics, severity, name);
    for (key, value) in metadata {
        event = event.metadata(key, value);
    }
    diagnostics.record(event);
}

fn stream_event_metadata(event: &AiStreamEvent) -> Vec<(&'static str, Value)> {
    match event {
        AiStreamEvent::MessageStarted {
            chat_session_id,
            message_id,
            target_pet,
            ..
        } => message_started_metadata(*chat_session_id, *message_id, target_pet.is_some()),
        AiStreamEvent::PetResolution { resolution } => pet_resolution_metadata(resolution),
        AiStreamEvent::ToolCall {
            tool_name,
            status,
            citation_count,
        } => tool_call_metadata(tool_name, *status, *citation_count),
        AiStreamEvent::AgentActivity {
            display_text,
            status,
        } => agent_activity_metadata(display_text, *status),
        AiStreamEvent::ExecutionTraceStarted { display_text, .. } => execution_trace_metadata(
            "execution_trace_started",
            AiAgentActivityStatus::Started,
            display_text,
            0,
        ),
        AiStreamEvent::ExecutionTraceCompleted {
            display_text,
            status,
            citation_count,
            ..
        } => execution_trace_metadata(
            "execution_trace_completed",
            *status,
            display_text,
            *citation_count,
        ),
        AiStreamEvent::Delta { text } | AiStreamEvent::AnswerDelta { text } => delta_metadata(text),
        AiStreamEvent::Citation { citation } => citation_metadata(citation),
        AiStreamEvent::ProposedAction { action } => proposed_action_metadata(action),
        AiStreamEvent::ConfirmationTask {
            confirmation_task_id,
            ..
        } => confirmation_task_metadata(*confirmation_task_id),
        AiStreamEvent::MessageCompleted {
            message_id,
            final_text,
            usage,
            finish_reason,
            citations,
            verification,
        }
        | AiStreamEvent::AnswerCompleted {
            message_id,
            final_text,
            usage,
            finish_reason,
            citations,
            verification,
        } => message_completed_metadata(
            *message_id,
            final_text,
            *usage,
            *finish_reason,
            citations.len(),
            verification,
        ),
        AiStreamEvent::Error {
            code,
            retryable,
            safe_fallback_text,
            ..
        } => error_metadata(code, *retryable, safe_fallback_text.as_deref()),
    }
}

fn execution_trace_metadata(
    event_name: &'static str,
    status: AiAgentActivityStatus,
    display_text: &str,
    citation_count: u32,
) -> Vec<(&'static str, Value)> {
    vec![
        ("event_name", json!(event_name)),
        ("activity_status", json!(agent_activity_status_code(status))),
        (
            "display_text_present",
            json!(!display_text.trim().is_empty()),
        ),
        ("citation_count", json!(citation_count)),
    ]
}

fn agent_activity_metadata(
    display_text: &str,
    status: AiAgentActivityStatus,
) -> Vec<(&'static str, Value)> {
    vec![
        ("event_name", json!("agent_activity")),
        ("activity_status", json!(agent_activity_status_code(status))),
        (
            "display_text_present",
            json!(!display_text.trim().is_empty()),
        ),
    ]
}

fn message_started_metadata(
    chat_session_id: Uuid,
    message_id: Uuid,
    target_pet_present: bool,
) -> Vec<(&'static str, Value)> {
    vec![
        (
            "event_chat_session_id_prefix",
            json!(uuid_prefix(Some(chat_session_id))),
        ),
        ("message_id_prefix", json!(uuid_prefix(Some(message_id)))),
        ("target_pet_present", json!(target_pet_present)),
    ]
}

fn pet_resolution_metadata(resolution: &AiPetResolution) -> Vec<(&'static str, Value)> {
    vec![
        ("resolution", json!(pet_resolution_code(resolution))),
        (
            "resolved_pet_id_prefix",
            json!(uuid_prefix(resolution.resolved_pet_id())),
        ),
    ]
}

fn tool_call_metadata(
    tool_name: &str,
    status: AiToolCallStatus,
    citation_count: u32,
) -> Vec<(&'static str, Value)> {
    vec![
        ("tool_name", json!(tool_name)),
        ("tool_status", json!(tool_status_code(status))),
        ("citation_count", json!(citation_count)),
    ]
}

fn delta_metadata(text: &str) -> Vec<(&'static str, Value)> {
    vec![(
        "delta_length_bucket",
        json!(length_bucket(text.chars().count())),
    )]
}

fn citation_metadata(citation: &AiCitation) -> Vec<(&'static str, Value)> {
    vec![
        (
            "citation_source_kind",
            json!(format!("{:?}", citation.source_kind)),
        ),
        (
            "citation_source_id_prefix",
            json!(uuid_prefix(Some(citation.source_id))),
        ),
    ]
}

fn proposed_action_metadata(action: &AiProposedAction) -> Vec<(&'static str, Value)> {
    vec![
        ("action_id_prefix", json!(uuid_prefix(Some(action.id)))),
        (
            "target_pet_id_prefix",
            json!(uuid_prefix(Some(action.target_pet_id))),
        ),
        ("action_kind", json!(format!("{:?}", action.action_kind))),
        ("risk_level", json!(format!("{:?}", action.risk_level))),
    ]
}

fn confirmation_task_metadata(confirmation_task_id: Uuid) -> Vec<(&'static str, Value)> {
    vec![(
        "confirmation_task_id_prefix",
        json!(uuid_prefix(Some(confirmation_task_id))),
    )]
}

fn message_completed_metadata(
    message_id: Uuid,
    final_text: &str,
    usage: LlmUsage,
    finish_reason: LlmFinishReason,
    citation_count: usize,
    verification: &AiAnswerVerification,
) -> Vec<(&'static str, Value)> {
    vec![
        ("message_id_prefix", json!(uuid_prefix(Some(message_id)))),
        (
            "final_text_length_bucket",
            json!(length_bucket(final_text.chars().count())),
        ),
        ("input_tokens", json!(usage.input_tokens)),
        ("output_tokens", json!(usage.output_tokens)),
        ("finish_reason", json!(finish_reason_code(finish_reason))),
        ("citation_count", json!(citation_count)),
        (
            "verification_status",
            json!(verification_status_code(verification.status)),
        ),
        (
            "blocked_reason",
            verification
                .blocked_reason
                .map_or(Value::Null, |reason| json!(reason.as_str())),
        ),
    ]
}

fn error_metadata(
    code: &str,
    retryable: bool,
    safe_fallback_text: Option<&str>,
) -> Vec<(&'static str, Value)> {
    vec![
        ("error_code", json!(code)),
        ("retryable", json!(retryable)),
        (
            "safe_text_present",
            json!(safe_fallback_text.is_some_and(|text| !text.trim().is_empty())),
        ),
    ]
}

fn stream_event_severity(event: &AiStreamEvent) -> Severity {
    if matches!(event, AiStreamEvent::Error { .. }) {
        Severity::Error
    } else {
        Severity::Info
    }
}

fn severity(success: bool) -> Severity {
    if success {
        Severity::Info
    } else {
        Severity::Error
    }
}

fn uuid_prefix(value: Option<Uuid>) -> String {
    value.map_or_else(String::new, |value| {
        value.to_string().chars().take(8).collect()
    })
}

fn length_bucket(count: usize) -> &'static str {
    match count {
        0 => "0",
        1..=32 => "1_32",
        33..=128 => "33_128",
        129..=512 => "129_512",
        _ => "513_plus",
    }
}

fn intent_code(intent: AiIntent) -> &'static str {
    match intent {
        AiIntent::PetCare => "pet_care",
        AiIntent::PetRecordQuery => "pet_record_query",
        AiIntent::PetFood => "pet_food",
        AiIntent::PetHealthRisk => "pet_health_risk",
        AiIntent::EmotionalPetContext => "emotional_pet_context",
        AiIntent::AppSupport => "app_support",
        AiIntent::OffTopic => "off_topic",
        AiIntent::PromptInjection => "prompt_injection",
        AiIntent::CostAbuse => "cost_abuse",
    }
}

fn gate_decision_code(gate_decision: &AiGateDecision) -> &'static str {
    if !gate_decision.enters_workbench() {
        "blocked"
    } else if gate_decision.context_loaded {
        "load_context"
    } else {
        "enter_workbench"
    }
}

fn pet_resolution_code(resolution: &AiPetResolution) -> &'static str {
    match resolution {
        AiPetResolution::Resolved { .. } => "resolved",
        AiPetResolution::NeedsSelection { .. } => "needs_selection",
        AiPetResolution::UnauthorizedOrNotFound => "unauthorized_or_not_found",
        AiPetResolution::NoPetContext => "no_pet_context",
    }
}

fn tool_status_code(status: AiToolCallStatus) -> &'static str {
    match status {
        AiToolCallStatus::Started => "started",
        AiToolCallStatus::Allowed => "allowed",
        AiToolCallStatus::Denied => "denied",
        AiToolCallStatus::Failed => "failed",
    }
}

fn agent_activity_status_code(status: AiAgentActivityStatus) -> &'static str {
    match status {
        AiAgentActivityStatus::Started => "started",
        AiAgentActivityStatus::Completed => "completed",
        AiAgentActivityStatus::Failed => "failed",
    }
}

fn finish_reason_code(reason: LlmFinishReason) -> &'static str {
    match reason {
        LlmFinishReason::Stop => "stop",
        LlmFinishReason::Length => "length",
        LlmFinishReason::ToolCalls => "tool_calls",
        LlmFinishReason::ContentFilter => "content_filter",
        LlmFinishReason::Error => "error",
    }
}

fn verification_status_code(status: AiVerificationStatus) -> &'static str {
    match status {
        AiVerificationStatus::Passed => "passed",
        AiVerificationStatus::Blocked => "blocked",
        AiVerificationStatus::NeedsReview => "needs_review",
    }
}

fn surface_code(surface: AiConversationSurface) -> &'static str {
    match surface {
        AiConversationSurface::HomePrivate => "home_private",
        AiConversationSurface::PetProfile => "pet_profile",
        AiConversationSurface::AbnormalDetail => "abnormal_detail",
        AiConversationSurface::ConfirmationTask => "confirmation_task",
        AiConversationSurface::UgcComment => "ugc_comment",
    }
}
