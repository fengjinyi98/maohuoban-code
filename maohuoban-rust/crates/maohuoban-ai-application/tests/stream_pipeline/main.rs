// stream_pipeline 后端稳定 SSE 事件测试
// 核心职责：
// - 验证 fake provider delta 序列被转换为毛伙伴稳定 SSE 事件
// - 事件顺序固定: message_started -> delta* -> message_completed
// - 遵循 TDD：先写失败测试（red），再实现 stream pipeline（green）

use futures_util::StreamExt;
use maohuoban_ai_application::ai::ports::FakeLlmProvider;
use maohuoban_ai_application::ai::stream::{AiStreamPipeline, AiStreamRunContext};
use maohuoban_ai_domain::ai::{
    AiCitation, AiCitationSourceKind, AiFactEntry, AiFactPackage, AiFactStrength, AiStreamEvent,
    LlmChatRequest, LlmChatResponse, LlmDiagnosticsCorrelation, LlmFinishReason, LlmMessage,
    LlmRole, LlmStreamEvent, LlmUsage, PROVIDER_USER_VISIBLE_FAILURE_MESSAGE,
};
use uuid::Uuid;

fn fake_stream_events() -> Vec<LlmStreamEvent> {
    vec![
        LlmStreamEvent::Delta {
            content: "你好".to_owned(),
        },
        LlmStreamEvent::Delta {
            content: "，毛球".to_owned(),
        },
        LlmStreamEvent::Delta {
            content: "很好".to_owned(),
        },
        LlmStreamEvent::Finish {
            finish_reason: LlmFinishReason::Stop,
            usage: LlmUsage {
                input_tokens: 10,
                output_tokens: 5,
                total_tokens: 15,
            },
        },
    ]
}

fn dummy_request() -> LlmChatRequest {
    LlmChatRequest {
        model: "test".to_owned(),
        messages: vec![LlmMessage {
            role: LlmRole::User,
            content: "test".to_owned(),
            reasoning_content: None,
            tool_call_id: None,
            tool_calls: Vec::new(),
        }],
        tools: vec![],
        tool_choice: None,
        temperature: 0.2,
        stream: true,
        max_output_tokens: None,
        response_format: None,
        diagnostics_correlation: LlmDiagnosticsCorrelation::default(),
    }
}

#[tokio::test]
async fn stream_pipeline_emits_stable_events() {
    let provider = FakeLlmProvider::new(
        LlmChatResponse {
            message: LlmMessage {
                role: LlmRole::Assistant,
                content: "你好，毛球很好".to_owned(),
                reasoning_content: None,
                tool_call_id: None,
                tool_calls: Vec::new(),
            },
            tool_calls: vec![],
            usage: LlmUsage::default(),
            finish_reason: LlmFinishReason::Stop,
            provider: "fake".to_owned(),
            model: "test".to_owned(),
        },
        fake_stream_events(),
    );

    let pipeline = AiStreamPipeline::new(provider);
    let session_id = Uuid::new_v4();
    let message_id = Uuid::new_v4();

    let request = dummy_request();
    let mut stream = pipeline.run(request, session_id, message_id, "新对话".to_owned());

    let mut events = Vec::new();
    while let Some(event) = stream.next().await {
        events.push(event.expect("stream event"));
    }

    // 第一个事件是 message_started
    assert_eq!(events[0].event_name(), "message_started");
    match &events[0] {
        AiStreamEvent::MessageStarted {
            chat_session_id,
            message_id: msg_id,
            title,
            ..
        } => {
            assert_eq!(*chat_session_id, session_id);
            assert_eq!(*msg_id, message_id);
            assert_eq!(title, "新对话");
        }
        _ => panic!("expected message_started"),
    }

    // 中间是 delta 事件
    let deltas: Vec<&str> = events
        .iter()
        .filter_map(|e| match e {
            AiStreamEvent::Delta { text } => Some(text.as_str()),
            _ => None,
        })
        .collect();
    assert_eq!(deltas, vec!["你好", "，毛球", "很好"]);

    // 最后是 message_completed
    let last = events.last().expect("should have events");
    assert_eq!(last.event_name(), "message_completed");
    match last {
        AiStreamEvent::MessageCompleted {
            final_text,
            usage,
            finish_reason,
            ..
        } => {
            assert_eq!(final_text, "你好，毛球很好");
            assert_eq!(usage.total_tokens, 15);
            assert_eq!(finish_reason, &LlmFinishReason::Stop);
        }
        _ => panic!("expected message_completed"),
    }
}

#[tokio::test]
async fn stream_pipeline_emits_error_on_provider_failure() {
    use maohuoban_ai_application::ai::ports::DisabledLlmProvider;

    let provider = DisabledLlmProvider;
    let pipeline = AiStreamPipeline::new(provider);

    let request = dummy_request();
    let mut stream = pipeline.run(request, Uuid::new_v4(), Uuid::new_v4(), "test".to_owned());

    let mut events = Vec::new();
    while let Some(event) = stream.next().await {
        events.push(event);
    }

    assert!(!events.is_empty());
    assert!(matches!(
        events.first(),
        Some(Ok(AiStreamEvent::MessageStarted { .. }))
    ));
    assert!(matches!(
        events.get(1),
        Some(Ok(AiStreamEvent::Error {
            code,
            message,
            retryable: false,
            safe_fallback_text: Some(safe_fallback_text),
            ..
        })) if code == "ai.provider.not_configured"
            && message == PROVIDER_USER_VISIBLE_FAILURE_MESSAGE
            && safe_fallback_text == PROVIDER_USER_VISIBLE_FAILURE_MESSAGE
    ));
}

#[tokio::test]
async fn stream_pipeline_preserves_event_order() {
    let provider = FakeLlmProvider::new(
        LlmChatResponse {
            message: LlmMessage {
                role: LlmRole::Assistant,
                content: "AB".to_owned(),
                reasoning_content: None,
                tool_call_id: None,
                tool_calls: Vec::new(),
            },
            tool_calls: vec![],
            usage: LlmUsage::default(),
            finish_reason: LlmFinishReason::Stop,
            provider: "fake".to_owned(),
            model: "test".to_owned(),
        },
        vec![
            LlmStreamEvent::Delta {
                content: "A".to_owned(),
            },
            LlmStreamEvent::Delta {
                content: "B".to_owned(),
            },
            LlmStreamEvent::Finish {
                finish_reason: LlmFinishReason::Stop,
                usage: LlmUsage::default(),
            },
        ],
    );

    let pipeline = AiStreamPipeline::new(provider);
    let request = dummy_request();
    let mut stream = pipeline.run(request, Uuid::new_v4(), Uuid::new_v4(), "test".to_owned());

    let mut names = Vec::new();
    while let Some(event) = stream.next().await {
        let event = event.expect("event");
        names.push(event.event_name());
    }

    // 顺序: message_started, delta, delta, message_completed
    assert_eq!(
        names,
        vec!["message_started", "delta", "delta", "message_completed"]
    );
}

#[tokio::test]
async fn stream_pipeline_uses_answer_text_from_json_output() {
    let json_output = serde_json::json!({
        "answer_text": "毛球今天精神不错，可以继续观察饮食和排便。",
        "display_blocks": [
            {
                "type": "paragraph",
                "text": "毛球今天精神不错，可以继续观察饮食和排便。"
            }
        ],
        "follow_up_questions": [],
        "safety_notes": []
    })
    .to_string();
    let provider = FakeLlmProvider::new(
        LlmChatResponse {
            message: LlmMessage {
                role: LlmRole::Assistant,
                content: json_output.clone(),
                reasoning_content: None,
                tool_call_id: None,
                tool_calls: Vec::new(),
            },
            tool_calls: vec![],
            usage: LlmUsage::default(),
            finish_reason: LlmFinishReason::Stop,
            provider: "fake".to_owned(),
            model: "test".to_owned(),
        },
        vec![
            LlmStreamEvent::Delta {
                content: json_output,
            },
            LlmStreamEvent::Finish {
                finish_reason: LlmFinishReason::Stop,
                usage: LlmUsage::default(),
            },
        ],
    );

    let pipeline = AiStreamPipeline::new(provider);
    let mut stream = pipeline.run(
        dummy_request(),
        Uuid::new_v4(),
        Uuid::new_v4(),
        "test".to_owned(),
    );

    let mut events = Vec::new();
    while let Some(event) = stream.next().await {
        events.push(event.expect("event"));
    }

    let deltas: Vec<&str> = events
        .iter()
        .filter_map(|event| match event {
            AiStreamEvent::Delta { text } => Some(text.as_str()),
            _ => None,
        })
        .collect();
    assert_eq!(deltas, vec!["毛球今天精神不错，可以继续观察饮食和排便。"]);

    let completed_text = events.iter().find_map(|event| match event {
        AiStreamEvent::MessageCompleted { final_text, .. } => Some(final_text.as_str()),
        _ => None,
    });
    assert_eq!(
        completed_text,
        Some("毛球今天精神不错，可以继续观察饮食和排便。")
    );
}

#[tokio::test]
async fn stream_pipeline_filters_citations_to_facts_used_in_answer() {
    let feeding_event_id = Uuid::new_v4();
    let mut package = AiFactPackage::empty();
    package.facts.push(AiFactEntry {
        key: "diet.recent_feeding".to_owned(),
        value: "未知食品 @ 2026-06-25T00:21:00Z".to_owned(),
        strength: AiFactStrength::Strong,
        citation_id: Some(feeding_event_id),
    });
    package.citations.push(AiCitation {
        source_kind: AiCitationSourceKind::PetEvent,
        source_id: feeding_event_id,
        label: "最近喂食: 未知食品".to_owned(),
    });

    let provider = FakeLlmProvider::new(
        LlmChatResponse {
            message: LlmMessage {
                role: LlmRole::Assistant,
                content: "目前记录中没有疫苗接种信息。".to_owned(),
                reasoning_content: None,
                tool_call_id: None,
                tool_calls: Vec::new(),
            },
            tool_calls: vec![],
            usage: LlmUsage::default(),
            finish_reason: LlmFinishReason::Stop,
            provider: "fake".to_owned(),
            model: "test".to_owned(),
        },
        vec![
            LlmStreamEvent::Delta {
                content: "目前记录中没有疫苗接种信息。".to_owned(),
            },
            LlmStreamEvent::Finish {
                finish_reason: LlmFinishReason::Stop,
                usage: LlmUsage::default(),
            },
        ],
    );
    let pipeline = AiStreamPipeline::new(provider);
    let mut stream = pipeline.run_with_context(
        dummy_request(),
        AiStreamRunContext {
            chat_session_id: Uuid::new_v4(),
            message_id: Uuid::new_v4(),
            title: "test".to_owned(),
            target_pet: None,
            initial_events: Vec::new(),
            fact_package: Some(package),
        },
    );

    let mut events = Vec::new();
    while let Some(event) = stream.next().await {
        events.push(event.expect("event"));
    }

    assert!(
        events
            .iter()
            .all(|event| !matches!(event, AiStreamEvent::Citation { .. })),
        "unused diet citation should not be emitted for a vaccine answer"
    );
    let completed_citations = events.iter().find_map(|event| match event {
        AiStreamEvent::MessageCompleted { citations, .. } => Some(citations),
        _ => None,
    });
    assert_eq!(completed_citations.map(Vec::len), Some(0));
}

#[tokio::test]
async fn stream_pipeline_keeps_citation_when_answer_uses_fact_value() {
    let feeding_event_id = Uuid::new_v4();
    let mut package = AiFactPackage::empty();
    package.facts.push(AiFactEntry {
        key: "diet.recent_feeding".to_owned(),
        value: "未知食品 @ 2026-06-25T00:21:00Z".to_owned(),
        strength: AiFactStrength::Strong,
        citation_id: Some(feeding_event_id),
    });
    package.citations.push(AiCitation {
        source_kind: AiCitationSourceKind::PetEvent,
        source_id: feeding_event_id,
        label: "最近喂食: 未知食品".to_owned(),
    });

    let provider = FakeLlmProvider::new(
        LlmChatResponse {
            message: LlmMessage {
                role: LlmRole::Assistant,
                content: "最近一次喂食记录显示为未知食品。".to_owned(),
                reasoning_content: None,
                tool_call_id: None,
                tool_calls: Vec::new(),
            },
            tool_calls: vec![],
            usage: LlmUsage::default(),
            finish_reason: LlmFinishReason::Stop,
            provider: "fake".to_owned(),
            model: "test".to_owned(),
        },
        vec![
            LlmStreamEvent::Delta {
                content: "最近一次喂食记录显示为未知食品。".to_owned(),
            },
            LlmStreamEvent::Finish {
                finish_reason: LlmFinishReason::Stop,
                usage: LlmUsage::default(),
            },
        ],
    );
    let pipeline = AiStreamPipeline::new(provider);
    let mut stream = pipeline.run_with_context(
        dummy_request(),
        AiStreamRunContext {
            chat_session_id: Uuid::new_v4(),
            message_id: Uuid::new_v4(),
            title: "test".to_owned(),
            target_pet: None,
            initial_events: Vec::new(),
            fact_package: Some(package),
        },
    );

    let mut events = Vec::new();
    while let Some(event) = stream.next().await {
        events.push(event.expect("event"));
    }

    let emitted_citation_count = events
        .iter()
        .filter(|event| matches!(event, AiStreamEvent::Citation { .. }))
        .count();
    assert_eq!(emitted_citation_count, 1);
    let completed_citations = events.iter().find_map(|event| match event {
        AiStreamEvent::MessageCompleted { citations, .. } => Some(citations),
        _ => None,
    });
    assert_eq!(completed_citations.map(Vec::len), Some(1));
}

#[tokio::test]
async fn complete_with_context_uses_answer_text_from_json_output() {
    let json_output = serde_json::json!({
        "answer_text": "毛球当前记录显示精神稳定。",
        "display_blocks": [
            {
                "type": "paragraph",
                "text": "毛球当前记录显示精神稳定。"
            }
        ],
        "follow_up_questions": [],
        "safety_notes": []
    })
    .to_string();
    let provider = FakeLlmProvider::new(
        LlmChatResponse {
            message: LlmMessage {
                role: LlmRole::Assistant,
                content: json_output,
                reasoning_content: None,
                tool_call_id: None,
                tool_calls: Vec::new(),
            },
            tool_calls: vec![],
            usage: LlmUsage::default(),
            finish_reason: LlmFinishReason::Stop,
            provider: "fake".to_owned(),
            model: "test".to_owned(),
        },
        Vec::new(),
    );
    let pipeline = AiStreamPipeline::new(provider);

    let result = pipeline
        .complete_with_context(
            dummy_request(),
            AiStreamRunContext {
                chat_session_id: Uuid::new_v4(),
                message_id: Uuid::new_v4(),
                title: "test".to_owned(),
                target_pet: None,
                initial_events: Vec::new(),
                fact_package: None,
            },
        )
        .await
        .expect("complete");

    assert_eq!(result.final_text, "毛球当前记录显示精神稳定。");
}
