use maohuoban_ai_domain::ai::{
    AgentEvent, AgentId, AgentToolStatus, AgentTurnId, AgentTurnStatus, AiConversationSurface,
    AiStreamEvent, LlmFinishReason, ModelLabel, ProviderErrorCategory,
};
use serde::Deserialize;
use uuid::Uuid;

const REPLAY_CASE_JSON: &str = include_str!(
    "../../../../docs/engineering/ai-agent-runtime/worktree-goals/eval-cases/replay_cases/provider_failure_turn.json"
);

#[allow(dead_code)]
#[path = "../src/Infrastructure/ai/router/chat/runtime_stream_projector.rs"]
mod runtime_stream_projector;

#[allow(dead_code)]
#[path = "../src/Infrastructure/ai/router/chat/runtime_stream_helpers.rs"]
mod runtime_stream_helpers;

use runtime_stream_helpers::safe_execution_trace_completed_for_tool;
use runtime_stream_projector::AgentEventSseProjector;

// ReplayFixture WT10 replay fixture 的 projector 输入
// 核心职责：
// - 读取 replay failure case 的 runtime event 序列
// - 固定 replay case 对应的 SSE projector 终态
#[derive(Debug, Deserialize)]
struct ReplayFixture {
    expected_terminal_state: String,
    event_sequence: Vec<String>,
    expected_replay_read: ExpectedReplayRead,
}

// ExpectedReplayRead replay fixture 中 projector 终态期望
// 核心职责：
// - 固定 replay 序列投影后的用户可见终态事件
#[derive(Debug, Deserialize)]
struct ExpectedReplayRead {
    projector_terminal_event: String,
}

#[test]
fn projector_terminal_event_matches_replay_fixture_contract() {
    let fixture: ReplayFixture = serde_json::from_str(REPLAY_CASE_JSON).expect("parse replay case");
    let message_id = Uuid::new_v4();
    let turn_id = AgentTurnId::new();
    let mut projector = AgentEventSseProjector::new(message_id, None, "毛球", false);

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
    let mut projector = AgentEventSseProjector::new(message_id, None, "豆包", false);

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
    let mut projector = AgentEventSseProjector::new(message_id, None, "梅录", false);

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
    let mut projector = AgentEventSseProjector::new(message_id, None, "豆包", false);

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
    let mut projector = AgentEventSseProjector::new(message_id, None, "豆包", false);

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
fn projector_emits_execution_trace_completed_before_answer_delta() {
    let message_id = Uuid::new_v4();
    let turn_id = AgentTurnId::new();
    let mut projector = AgentEventSseProjector::new(message_id, None, "豆包", false);

    let mut events = Vec::new();
    events.extend(projector.project(AgentEvent::ToolStarted {
        turn_id,
        tool_call_id: "call_1".to_owned(),
        tool_name: "load_pet_identity_context".to_owned(),
    }));
    events.extend(projector.project(AgentEvent::ToolFinished {
        turn_id,
        tool_call_id: "call_1".to_owned(),
        status: AgentToolStatus::Succeeded,
        citation_count: 1,
    }));
    events.extend(projector.project(AgentEvent::MessageDelta {
        turn_id,
        text: "豆包档案显示状态稳定。".to_owned(),
    }));
    events.extend(projector.project(AgentEvent::TurnFinished {
        turn_id,
        message_id,
        final_text: "豆包档案显示状态稳定。".to_owned(),
        status: AgentTurnStatus::Completed,
    }));

    let event_names: Vec<&str> = events.iter().map(AiStreamEvent::event_name).collect();
    assert_eq!(
        event_names,
        vec![
            "execution_trace_started",
            "execution_trace_completed",
            "answer_delta",
            "answer_completed"
        ]
    );
}

#[test]
fn safe_execution_trace_event_for_tool_does_not_expose_internal_tool_name() {
    let event = safe_execution_trace_completed_for_tool("load_pet_identity_context", "豆包", 2);

    assert_eq!(event.event_name(), "execution_trace_completed");
    let payload = serde_json::to_string(&event).expect("serialize safe execution trace");
    assert!(payload.contains("正在查看豆包档案"));
    assert!(!payload.contains("tool_name"));
    assert!(!payload.contains("tool_call"));
    assert!(!payload.contains("load_pet_identity_context"));
}

#[test]
fn projector_blocks_missing_identity_claim_when_identity_tool_not_called() {
    let message_id = Uuid::new_v4();
    let turn_id = AgentTurnId::new();
    let mut projector = AgentEventSseProjector::new(message_id, None, "梅录", true);

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
    });

    let completed = completed_events
        .iter()
        .find_map(|event| match event {
            AiStreamEvent::AnswerCompleted {
                final_text,
                finish_reason,
                verification,
                ..
            } => Some((final_text, finish_reason, verification)),
            _ => None,
        })
        .expect("blocked completion should emit answer_completed");

    assert_eq!(*completed.1, LlmFinishReason::ContentFilter);
    assert!(completed.2.is_blocked());
    assert!(!completed.0.contains("没有生日记录"));
}

fn replay_agent_event(event_name: &str, turn_id: AgentTurnId) -> AgentEvent {
    match event_name {
        "turn_started" => AgentEvent::TurnStarted {
            turn_id,
            chat_session_id: Uuid::new_v4(),
            agent_id: AgentId::main_pet_care_agent(),
            surface: AiConversationSurface::HomePrivate,
            engine_mode: "openai".to_owned(),
        },
        "model_call_started" => AgentEvent::ModelCallStarted {
            turn_id,
            model_label: ModelLabel::Primary,
            tool_count: 0,
            engine_mode: "openai".to_owned(),
        },
        "provider_error" => AgentEvent::ProviderError {
            turn_id,
            category: ProviderErrorCategory::NotConfigured,
            retryable: false,
            engine_mode: "openai".to_owned(),
        },
        "turn_failed" => AgentEvent::TurnFailed {
            turn_id,
            error_code: "ai.provider.not_configured".to_owned(),
            retryable: false,
            engine_mode: "openai".to_owned(),
        },
        event => panic!("unsupported replay fixture event {event}"),
    }
}
