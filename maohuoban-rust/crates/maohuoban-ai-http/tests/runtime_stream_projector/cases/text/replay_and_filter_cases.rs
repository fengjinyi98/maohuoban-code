use maohuoban_ai_domain::ai::{AgentEvent, AgentTurnId, AgentTurnStatus, AiStreamEvent};
use uuid::Uuid;

use crate::runtime_stream_projector::AgentEventSseProjector;
use crate::support::{REPLAY_CASE_JSON, ReplayFixture, replay_agent_event};
use crate::visible_output_plan::VisibleOutputPlan;

#[test]
fn projector_terminal_event_matches_replay_fixture_contract() {
    let fixture: ReplayFixture = serde_json::from_str(REPLAY_CASE_JSON).expect("parse replay case");
    let message_id = Uuid::new_v4();
    let turn_id = AgentTurnId::new();
    let mut projector =
        AgentEventSseProjector::new(message_id, None, "毛球", false, VisibleOutputPlan::empty());

    let projected = fixture
        .event_sequence
        .iter()
        .flat_map(|event_name| projector.project(replay_agent_event(event_name, turn_id)))
        .collect::<Vec<_>>();
    let terminal_event = projected
        .last()
        .unwrap_or_else(|| panic!("replay fixture produced no projected events: {fixture:?}"));

    assert_eq!(fixture.expected_terminal_state, "failed");
    assert_eq!(
        terminal_event.event_name(),
        fixture.expected_replay_read.projector_terminal_event
    );
    assert!(
        matches!(
            terminal_event,
            AiStreamEvent::Error {
                code,
                retryable: false,
                ..
            } if code == "ai.provider.not_configured"
        ),
        "provider failure replay must project stable error event, got {terminal_event:?}"
    );
}

#[test]
fn projector_streams_json_answer_text_incrementally_without_json_fields() {
    let message_id = Uuid::new_v4();
    let turn_id = AgentTurnId::new();
    let mut projector =
        AgentEventSseProjector::new(message_id, None, "豆包", false, VisibleOutputPlan::empty());

    let first_events = projector.project(AgentEvent::MessageDelta {
        turn_id,
        text: "{\"answer_text\":\"豆包精神".to_owned(),
    });
    let first_deltas: Vec<&str> = first_events
        .iter()
        .filter_map(|event| match event {
            AiStreamEvent::AnswerDelta { text } => Some(text.as_str()),
            _ => None,
        })
        .collect();

    assert_eq!(first_deltas, vec!["豆包精神"]);

    let second_events = projector.project(AgentEvent::MessageDelta {
        turn_id,
        text: "正常。\",\"display_blocks\":[]}".to_owned(),
    });
    let second_deltas: Vec<&str> = second_events
        .iter()
        .filter_map(|event| match event {
            AiStreamEvent::AnswerDelta { text } => Some(text.as_str()),
            _ => None,
        })
        .collect();

    assert_eq!(second_deltas, vec!["正常。"]);

    let completed_events = projector.project(AgentEvent::TurnFinished {
        turn_id,
        message_id,
        final_text: "豆包精神正常。".to_owned(),
        status: AgentTurnStatus::Completed,
        termination_reason: None,
    });
    let deltas: Vec<&str> = completed_events
        .iter()
        .filter_map(|event| match event {
            AiStreamEvent::AnswerDelta { text } => Some(text.as_str()),
            _ => None,
        })
        .collect();

    assert!(
        deltas.is_empty(),
        "completed event must not duplicate streamed answer_text"
    );
}

#[test]
fn projector_scrubs_embedded_json_dto_fields_from_mixed_model_output() {
    let message_id = Uuid::new_v4();
    let turn_id = AgentTurnId::new();
    let mut projector =
        AgentEventSseProjector::new(message_id, None, "梅录", false, VisibleOutputPlan::empty());

    let chunks = [
        "好的，这是梅录的档案信息：",
        "{\"answer_text\":\"梅录的档案信息如下：\\n\\n名字：梅录\",",
        "\"display_blocks\":[],\"follow_up_questions\":[],\"safety_notes\":[]}",
    ];

    let deltas: Vec<String> = chunks
        .into_iter()
        .flat_map(|text| {
            projector.project(AgentEvent::MessageDelta {
                turn_id,
                text: text.to_owned(),
            })
        })
        .filter_map(|event| match event {
            AiStreamEvent::AnswerDelta { text } => Some(text),
            _ => None,
        })
        .collect();
    let visible_text = deltas.concat();

    assert!(!visible_text.contains("answer_text"));
    assert!(!visible_text.contains("display_blocks"));
    assert!(!visible_text.contains("follow_up_questions"));
    assert!(!visible_text.contains("safety_notes"));
}

#[test]
fn projector_scrubs_cross_chunk_thinking_and_internal_context_before_sse_delta() {
    let message_id = Uuid::new_v4();
    let turn_id = AgentTurnId::new();
    let mut projector =
        AgentEventSseProjector::new(message_id, None, "豆包", false, VisibleOutputPlan::empty());

    let chunks = [
        "<think>先看内部推理",
        "</think>{\"memory_context\":{\"pet_id\":\"hidden\"},\"answer_text\":\"",
        "豆包今天精神稳定",
        "。\",\"provider_raw\":{\"choices\":[]}}",
    ];

    let deltas: Vec<String> = chunks
        .into_iter()
        .flat_map(|text| {
            projector.project(AgentEvent::MessageDelta {
                turn_id,
                text: text.to_owned(),
            })
        })
        .filter_map(|event| match event {
            AiStreamEvent::AnswerDelta { text } => Some(text),
            _ => None,
        })
        .collect();

    assert_eq!(deltas.concat(), "豆包今天精神稳定。");
}

#[test]
fn projector_scrubs_provider_raw_delta_reasoning_tool_planning_and_json_draft_before_sse_delta() {
    let message_id = Uuid::new_v4();
    let turn_id = AgentTurnId::new();
    let mut projector =
        AgentEventSseProjector::new(message_id, None, "豆包", false, VisibleOutputPlan::empty());

    let chunks = [
        "<reasoning>Provider internal plan: call load_pet_identity_context</reasoning>",
        "{\"tool_planning\":{\"tool_name\":\"load_pet_identity_context\",\"arguments\":{\"pet_id\":\"hidden\"}},",
        "\"json_draft\":{\"internal\":\"provider raw draft\"},\"answer_text\":\"",
        "豆包档案可先看精神、食欲和排便变化。",
        "\"}",
    ];

    let deltas: Vec<String> = chunks
        .into_iter()
        .flat_map(|text| {
            projector.project(AgentEvent::MessageDelta {
                turn_id,
                text: text.to_owned(),
            })
        })
        .filter_map(|event| match event {
            AiStreamEvent::AnswerDelta { text } => Some(text),
            _ => None,
        })
        .collect();
    let visible_text = deltas.concat();

    assert_eq!(visible_text, "豆包档案可先看精神、食欲和排便变化。");
    assert!(!visible_text.contains("Provider internal plan"));
    assert!(!visible_text.contains("tool_planning"));
    assert!(!visible_text.contains("json_draft"));
    assert!(!visible_text.contains("load_pet_identity_context"));
}

#[test]
fn projector_does_not_stream_dsml_tool_call_delta() {
    let message_id = Uuid::new_v4();
    let turn_id = AgentTurnId::new();
    let mut projector =
        AgentEventSseProjector::new(message_id, None, "梅录", false, VisibleOutputPlan::empty());

    let chunks = [
        "<| | DSML | | tool_calls>\n",
        "<| | DSML | | invoke name=\"date_calculator\">\n",
        "<| | DSML | | parameter name=\"operation\" string=\"true\">days_between</| | DSML | | parameter>\n",
        "<| | DSML | | parameter name=\"date1\" string=\"true\">2026-07-02</| | DSML | | parameter>\n",
        "<| | DSML | | parameter name=\"date2\" string=\"true\">2027-06-17</| | DSML | | parameter>\n",
        "</| | DSML | | invoke>\n",
        "</| | DSML | | tool_calls>",
    ];

    let deltas: Vec<String> = chunks
        .into_iter()
        .flat_map(|text| {
            projector.project(AgentEvent::MessageDelta {
                turn_id,
                text: text.to_owned(),
            })
        })
        .filter_map(|event| match event {
            AiStreamEvent::AnswerDelta { text } => Some(text),
            _ => None,
        })
        .collect();

    assert!(
        deltas.is_empty(),
        "DSML tool call blocks must remain internal: {deltas:?}"
    );
}
