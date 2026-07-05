use maohuoban_ai_application::ai::diagnostics::redact_ai_diagnostics_text;
use maohuoban_ai_application::ai::finalizer::{FinalizerAsyncJobKind, FinalizerSynchronousWrite};
use maohuoban_ai_domain::ai::{AiContentBlock, AiConversationSurface, AiSessionTurnStatus};
use maohuoban_diagnostics::Severity;
use serde_json::json;
use uuid::Uuid;

use super::super::diagnostics_common::{length_bucket, record_ai_event, surface_code, uuid_prefix};

pub(super) fn record_chat_ingress_received(
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
pub(super) fn record_chat_auth_result(
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

pub(super) fn turn_status_code(status: AiSessionTurnStatus) -> &'static str {
    status.as_str()
}

pub(super) fn synchronous_write_code(write: FinalizerSynchronousWrite) -> &'static str {
    match write {
        FinalizerSynchronousWrite::AssistantMessage => "assistant_message",
        FinalizerSynchronousWrite::Citations => "citations",
        FinalizerSynchronousWrite::ProposedActions => "proposed_actions",
        FinalizerSynchronousWrite::TurnStatus => "turn_status",
        FinalizerSynchronousWrite::SessionHeader => "session_header",
    }
}

pub(super) fn async_job_code(job: FinalizerAsyncJobKind) -> &'static str {
    match job {
        FinalizerAsyncJobKind::SessionSummary => "session_summary",
        FinalizerAsyncJobKind::MemoryCandidate => "memory_candidate",
        FinalizerAsyncJobKind::Evaluation => "evaluation",
    }
}

pub(super) fn content_block_kind_code(block: &AiContentBlock) -> &'static str {
    match block {
        AiContentBlock::SectionHeading { .. } => "section_heading",
        AiContentBlock::Paragraph { .. } => "paragraph",
        AiContentBlock::Divider { .. } => "divider",
        AiContentBlock::List { .. } => "list",
        AiContentBlock::Quote { .. } => "quote",
        AiContentBlock::Table { .. } => "table",
        AiContentBlock::PetProfileCardSkeleton { .. } => "pet_profile_card_skeleton",
        AiContentBlock::PetProfileCard { .. } => "pet_profile_card",
    }
}
