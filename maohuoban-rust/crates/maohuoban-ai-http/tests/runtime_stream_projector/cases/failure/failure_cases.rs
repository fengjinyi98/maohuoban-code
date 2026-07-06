use maohuoban_ai_domain::ai::{AgentEvent, AgentTurnId, AgentTurnStatus, AiStreamEvent};
use uuid::Uuid;

use crate::runtime_stream_projector::AgentEventSseProjector;
use crate::visible_output_plan::VisibleOutputPlan;

#[test]
fn projector_reports_unrepaired_output_guard_failure_without_fallback_text_completion() {
    let message_id = Uuid::new_v4();
    let turn_id = AgentTurnId::new();
    let mut projector =
        AgentEventSseProjector::new(message_id, None, "梅录", true, VisibleOutputPlan::empty());

    let delta_events = projector.project(AgentEvent::MessageDelta {
        turn_id,
        text: "目前档案里没有生日记录，所以还不知道梅录多大。".to_owned(),
    });
    assert!(delta_events.is_empty());

    let completed_events = projector.project(AgentEvent::TurnFinished {
        turn_id,
        message_id,
        final_text: "目前档案里没有生日记录，所以还不知道梅录多大。".to_owned(),
        status: AgentTurnStatus::Completed,
        termination_reason: None,
    });

    let error = completed_events
        .iter()
        .find_map(|event| match event {
            AiStreamEvent::Error {
                code,
                safe_fallback_text,
                ..
            } => Some((code, safe_fallback_text)),
            _ => None,
        })
        .expect("unrepaired invalid answer should emit error event");

    assert_eq!(error.0, "ai.output_guard.unrepaired");
    assert_eq!(error.1, &None);
    assert!(
        completed_events
            .iter()
            .all(|event| !matches!(event, AiStreamEvent::AnswerCompleted { .. })),
        "projector must not convert verifier fallback into completed user text"
    );
}

#[test]
fn projector_reports_failed_turn_without_empty_answer_completion() {
    let message_id = Uuid::new_v4();
    let turn_id = AgentTurnId::new();
    let mut projector =
        AgentEventSseProjector::new(message_id, None, "梅录", true, VisibleOutputPlan::empty());

    let events = projector.project(AgentEvent::TurnFinished {
        turn_id,
        message_id,
        final_text: String::new(),
        status: AgentTurnStatus::Failed,
        termination_reason: None,
    });

    assert!(
        matches!(
            events.as_slice(),
            [
                AiStreamEvent::Error {
                    code,
                    retryable: true,
                    safe_fallback_text: None,
                    ..
                }
            ] if code == "ai.output_guard.unrepaired"
        ),
        "failed runtime turn should be projected as retryable output guard error: {events:?}"
    );
    assert!(
        events
            .iter()
            .all(|event| !matches!(event, AiStreamEvent::AnswerCompleted { .. })),
        "failed runtime turn must not emit an empty answer_completed event"
    );
}
