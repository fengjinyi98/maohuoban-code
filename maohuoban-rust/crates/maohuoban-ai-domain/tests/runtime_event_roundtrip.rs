// runtime_event_roundtrip Runtime 内部事件契约测试
// 核心职责：
// - 验证 WT01 冻结 AgentEvent 事件名和 serde roundtrip
// - 确保 Runtime 内部事件不依赖 HTTP/SSE 外部协议

use maohuoban_ai_domain::ai::{
    AgentEvent, AgentId, AgentToolStatus, AgentTurnId, AgentTurnStatus, AiConversationSurface,
    InternalTurnEvent, LlmFinishReason, LlmUsage, LoopStep, ModelLabel, ProviderErrorCategory,
    UserVisibleTurnEvent,
};
use uuid::Uuid;

fn turn_id() -> AgentTurnId {
    AgentTurnId::from_uuid(Uuid::parse_str("018f4f21-9f44-7a62-a14d-4e7465726e31").unwrap())
}

#[test]
fn turn_event_boundary_separates_internal_and_user_visible_events() {
    let turn_id = turn_id();
    let internal_events = vec![
        InternalTurnEvent::ModelDelta {
            turn_id,
            text: "{\"answer_text\":\"毛球状态稳定\",\"memory_context\":{\"secret\":true}}"
                .to_owned(),
        },
        InternalTurnEvent::ToolPlanning {
            turn_id,
            tool_call_id: "call_1".to_owned(),
            tool_name: "load_pet_identity_context".to_owned(),
            arguments: "{\"pet_id\":\"internal\"}".to_owned(),
        },
        InternalTurnEvent::ProviderJsonDraft {
            turn_id,
            text: "{\"provider\":\"deepseek\",\"choices\":[]}".to_owned(),
        },
    ];

    assert_eq!(
        internal_events
            .iter()
            .map(InternalTurnEvent::event_name)
            .collect::<Vec<_>>(),
        vec!["model_delta", "tool_planning", "provider_json_draft"]
    );

    let visible_events = vec![
        UserVisibleTurnEvent::ExecutionTraceStarted {
            turn_id,
            display_text: "正在查看毛球档案".to_owned(),
        },
        UserVisibleTurnEvent::AnswerDelta {
            turn_id,
            text: "毛球状态稳定".to_owned(),
        },
    ];

    assert_eq!(
        visible_events
            .iter()
            .map(UserVisibleTurnEvent::event_name)
            .collect::<Vec<_>>(),
        vec!["execution_trace_started", "answer_delta"]
    );

    for event in internal_events {
        let encoded = serde_json::to_string(&event).expect("serialize internal event");
        let decoded: InternalTurnEvent =
            serde_json::from_str(&encoded).expect("deserialize internal event");
        assert_eq!(decoded, event);
    }

    for event in visible_events {
        let encoded = serde_json::to_string(&event).expect("serialize visible event");
        let decoded: UserVisibleTurnEvent =
            serde_json::from_str(&encoded).expect("deserialize visible event");
        assert_eq!(decoded, event);
    }
}

#[test]
fn runtime_loop_step_roundtrip_covers_message_delta() {
    let step = LoopStep::MessageDelta {
        text: "第一段增量".to_owned(),
    };

    let encoded = serde_json::to_string(&step).expect("serialize loop step");
    assert!(encoded.contains("message_delta"));
    assert_eq!(step.step_name(), "message_delta");
    let decoded: LoopStep = serde_json::from_str(&encoded).expect("deserialize loop step");
    assert_eq!(decoded, step);
}

#[test]
fn runtime_loop_step_roundtrip_covers_clarify_user() {
    let step = LoopStep::ClarifyUser {
        reason: "用户描述缺少可行动观察信息".to_owned(),
        suggested_actions: vec![
            "补充症状持续时间".to_owned(),
            "补充精神和食欲状态".to_owned(),
        ],
    };

    let encoded = serde_json::to_string(&step).expect("serialize clarify step");
    assert!(encoded.contains("clarify_user"));
    assert_eq!(step.step_name(), "clarify_user");
    let decoded: LoopStep = serde_json::from_str(&encoded).expect("deserialize clarify step");
    assert_eq!(decoded, step);
}

#[test]
fn runtime_loop_step_roundtrip_preserves_failed_done_error_code() {
    let step = LoopStep::Done {
        message_id: Uuid::new_v4(),
        final_text: String::new(),
        status: AgentTurnStatus::Failed,
        error_code: Some("ai.output_guard.unrepaired".to_owned()),
    };

    let encoded = serde_json::to_string(&step).expect("serialize done step");
    assert!(encoded.contains("ai.output_guard.unrepaired"));
    assert_eq!(step.step_name(), "done");
    let decoded: LoopStep = serde_json::from_str(&encoded).expect("deserialize done step");
    assert_eq!(decoded, step);
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
            engine_mode: "self_hosted".to_owned(),
        },
        AgentEvent::ModelCallStarted {
            turn_id: turn_id(),
            model_label: ModelLabel::Primary,
            tool_count: 2,
            engine_mode: "self_hosted".to_owned(),
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
            fact_package: None,
        },
        AgentEvent::ProviderError {
            turn_id: turn_id(),
            category: ProviderErrorCategory::NotConfigured,
            retryable: false,
            engine_mode: "self_hosted".to_owned(),
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
            engine_mode: "self_hosted".to_owned(),
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
