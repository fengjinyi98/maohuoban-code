use maohuoban_ai_domain::ai::{
    AgentEvent, AgentToolStatus, AgentTurnId, AgentTurnStatus, AiStreamEvent,
};
use uuid::Uuid;

use crate::runtime_stream_helpers::safe_execution_trace_completed_for_tool;
use crate::runtime_stream_projector::AgentEventSseProjector;
use crate::visible_output_plan::VisibleOutputPlan;

#[test]
fn projector_emits_execution_trace_completed_before_answer_delta() {
    let message_id = Uuid::new_v4();
    let turn_id = AgentTurnId::new();
    let mut projector =
        AgentEventSseProjector::new(message_id, None, "豆包", false, VisibleOutputPlan::empty());

    let mut events = Vec::new();
    events.extend(projector.project(AgentEvent::ToolStarted {
        turn_id,
        tool_call_id: "call_1".to_owned(),
        tool_name: "load_pet_current_diet_context".to_owned(),
    }));
    events.extend(projector.project(AgentEvent::ToolFinished {
        turn_id,
        tool_call_id: "call_1".to_owned(),
        status: AgentToolStatus::Succeeded,
        citation_count: 1,
        fact_package: None,
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
        termination_reason: None,
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
    assert!(payload.contains("正在整理豆包的宠物档案"));
    assert!(!payload.contains("tool_name"));
    assert!(!payload.contains("tool_call"));
    assert!(!payload.contains("load_pet_identity_context"));
}
