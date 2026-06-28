// runtime_event_roundtrip Runtime 内部事件契约测试
// 核心职责：
// - 验证 WT01 冻结 AgentEvent 事件名和 serde roundtrip
// - 确保 Runtime 内部事件不依赖 HTTP/SSE 外部协议

use maohuoban_ai_domain::ai::{
    AgentEvent, AgentId, AgentToolStatus, AgentTurnId, AgentTurnStatus, AiConversationSurface,
    LlmFinishReason, LlmUsage, ModelLabel, ProviderErrorCategory,
};
use uuid::Uuid;

fn turn_id() -> AgentTurnId {
    AgentTurnId::from_uuid(Uuid::parse_str("018f4f21-9f44-7a62-a14d-4e7465726e31").unwrap())
}

#[test]
fn runtime_event_roundtrip_preserves_frozen_event_names() {
    let chat_session_id = Uuid::new_v4();
    let message_id = Uuid::new_v4();
    let events = vec![
        AgentEvent::TurnStarted {
            turn_id: turn_id(),
            chat_session_id,
            agent_id: AgentId::main_pet_care_agent(),
            surface: AiConversationSurface::HomePrivate,
        },
        AgentEvent::ModelCallStarted {
            turn_id: turn_id(),
            model_label: ModelLabel::Primary,
            tool_count: 2,
        },
        AgentEvent::ToolStarted {
            turn_id: turn_id(),
            tool_call_id: "call_1".to_owned(),
            tool_name: "load_pet_identity_context".to_owned(),
        },
        AgentEvent::MessageDelta {
            turn_id: turn_id(),
            text: "毛球今天精神不错".to_owned(),
        },
        AgentEvent::TurnFinished {
            turn_id: turn_id(),
            message_id,
            final_text: "毛球今天精神不错".to_owned(),
            status: AgentTurnStatus::Completed,
        },
    ];

    let names: Vec<&'static str> = events.iter().map(AgentEvent::event_name).collect();
    assert_eq!(
        names,
        vec![
            "turn_started",
            "model_call_started",
            "tool_started",
            "message_delta",
            "turn_finished"
        ]
    );

    for event in events {
        let encoded = serde_json::to_string(&event).expect("serialize runtime event");
        assert!(encoded.contains(event.event_name()));
        let decoded: AgentEvent =
            serde_json::from_str(&encoded).expect("deserialize runtime event");
        assert_eq!(decoded, event);
    }
}

#[test]
fn runtime_event_roundtrip_covers_tool_finished_and_provider_error() {
    let events = vec![
        AgentEvent::ToolFinished {
            turn_id: turn_id(),
            tool_call_id: "call_1".to_owned(),
            status: AgentToolStatus::Succeeded,
            citation_count: 1,
        },
        AgentEvent::ProviderError {
            turn_id: turn_id(),
            category: ProviderErrorCategory::NotConfigured,
            retryable: false,
        },
        AgentEvent::ModelCallFinished {
            turn_id: turn_id(),
            finish_reason: LlmFinishReason::Stop,
            usage: LlmUsage {
                input_tokens: 12,
                output_tokens: 7,
                total_tokens: 19,
            },
            provider: "openai_compatible".to_owned(),
            model: "contract-model".to_owned(),
        },
    ];

    let names: Vec<&'static str> = events.iter().map(AgentEvent::event_name).collect();
    assert_eq!(
        names,
        vec!["tool_finished", "provider_error", "model_call_finished"]
    );

    for event in events {
        let encoded = serde_json::to_string(&event).expect("serialize runtime event");
        let decoded: AgentEvent =
            serde_json::from_str(&encoded).expect("deserialize runtime event");
        assert_eq!(decoded, event);
    }
}
