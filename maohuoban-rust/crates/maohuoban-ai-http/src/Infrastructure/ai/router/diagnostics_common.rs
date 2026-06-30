use maohuoban_ai_domain::ai::{
    AiAgentActivityStatus, AiAnswerVerification, AiCitation, AiConversationSurface, AiGateDecision,
    AiIntent, AiPetResolution, AiProposedAction, AiStreamEvent, AiToolCallStatus,
    AiVerificationStatus, LlmFinishReason, LlmUsage,
};
use maohuoban_diagnostics::{DiagnosticEvent, Diagnostics, EventKind, Severity};
use serde_json::{Value, json};
use uuid::Uuid;

pub(super) fn record_ai_event(name: &str, severity: Severity, metadata: Vec<(&str, Value)>) {
    let Some(diagnostics) = Diagnostics::current() else {
        return;
    };
    let mut event = DiagnosticEvent::new(EventKind::Analytics, severity, name);
    for (key, value) in metadata {
        event = event.metadata(key, value);
    }
    diagnostics.record(event);
}

pub(super) fn stream_event_metadata(event: &AiStreamEvent) -> Vec<(&'static str, Value)> {
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

pub(super) fn stream_event_severity(event: &AiStreamEvent) -> Severity {
    if matches!(event, AiStreamEvent::Error { .. }) {
        Severity::Error
    } else {
        Severity::Info
    }
}

pub(super) fn severity(success: bool) -> Severity {
    if success {
        Severity::Info
    } else {
        Severity::Error
    }
}

pub(super) fn uuid_prefix(value: Option<Uuid>) -> String {
    value.map_or_else(String::new, |value| {
        value.to_string().chars().take(8).collect()
    })
}

pub(super) fn length_bucket(count: usize) -> &'static str {
    match count {
        0 => "0",
        1..=32 => "1_32",
        33..=128 => "33_128",
        129..=512 => "129_512",
        _ => "513_plus",
    }
}

pub(super) fn intent_code(intent: AiIntent) -> &'static str {
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

pub(super) fn gate_decision_code(gate_decision: &AiGateDecision) -> &'static str {
    if !gate_decision.enters_workbench() {
        "blocked"
    } else if gate_decision.context_loaded {
        "load_context"
    } else {
        "enter_workbench"
    }
}

pub(super) fn surface_code(surface: AiConversationSurface) -> &'static str {
    match surface {
        AiConversationSurface::HomePrivate => "home_private",
        AiConversationSurface::PetProfile => "pet_profile",
        AiConversationSurface::AbnormalDetail => "abnormal_detail",
        AiConversationSurface::ConfirmationTask => "confirmation_task",
        AiConversationSurface::UgcComment => "ugc_comment",
    }
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

fn delta_metadata(text: &str) -> Vec<(&'static str, Value)> {
    vec![
        (
            "delta_length_bucket",
            json!(length_bucket(text.chars().count())),
        ),
        ("delta_text", json!(text)),
    ]
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
        ("final_text", json!(final_text)),
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
