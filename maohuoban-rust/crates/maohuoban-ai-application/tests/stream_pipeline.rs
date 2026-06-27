// stream_pipeline 后端稳定 SSE 事件测试
// 核心职责：
// - 验证 fake provider delta 序列被转换为毛伙伴稳定 SSE 事件
// - 事件顺序固定: message_started -> delta* -> message_completed
// - 遵循 TDD：先写失败测试（red），再实现 stream pipeline（green）

use futures_util::StreamExt;
use maohuoban_ai_application::ai::ports::FakeLlmProvider;
use maohuoban_ai_application::ai::stream::AiStreamPipeline;
use maohuoban_ai_domain::ai::{
    AiStreamEvent, LlmChatRequest, LlmChatResponse, LlmFinishReason, LlmMessage, LlmRole,
    LlmStreamEvent, LlmUsage,
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
            tool_call_id: None,
        }],
        tools: vec![],
        tool_choice: None,
        temperature: 0.2,
        stream: true,
        max_output_tokens: None,
        response_format: None,
    }
}

#[tokio::test]
async fn stream_pipeline_emits_stable_events() {
    let provider = FakeLlmProvider::new(
        LlmChatResponse {
            message: LlmMessage {
                role: LlmRole::Assistant,
                content: "你好，毛球很好".to_owned(),
                tool_call_id: None,
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

    // 应该有 message_started + error
    assert!(!events.is_empty());
    let has_error = events
        .iter()
        .any(|e| matches!(e, Ok(AiStreamEvent::Error { .. })));
    assert!(has_error, "should emit error event");
}

#[tokio::test]
async fn stream_pipeline_preserves_event_order() {
    let provider = FakeLlmProvider::new(
        LlmChatResponse {
            message: LlmMessage {
                role: LlmRole::Assistant,
                content: "AB".to_owned(),
                tool_call_id: None,
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
