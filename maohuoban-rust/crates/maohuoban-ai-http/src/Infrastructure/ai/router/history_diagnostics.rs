use maohuoban_diagnostics::Severity;
use serde_json::json;
use uuid::Uuid;

use super::diagnostics_common::{record_ai_event, severity, uuid_prefix};

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
