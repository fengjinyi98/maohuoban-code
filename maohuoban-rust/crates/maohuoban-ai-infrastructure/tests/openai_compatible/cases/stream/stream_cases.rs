use futures_util::StreamExt;
use httpmock::MockServer;
use maohuoban_ai_application::ai::ports::LlmProvider;
use maohuoban_ai_domain::ai::{AiError, LlmStreamEvent, ProviderErrorCategory};
use maohuoban_ai_infrastructure::provider::{OpenAiCompatibleConfig, OpenAiCompatibleLlmProvider};

use crate::support::{assert_provider_category, sample_request};

#[tokio::test]
async fn stream_maps_invalid_sse_to_invalid_response_category() {
    let server = MockServer::start();
    server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions");
        then.status(200)
            .header("content-type", "text/event-stream")
            .body("data: not-json\n\n");
    });

    let config = OpenAiCompatibleConfig {
        base_url: server.base_url(),
        api_key: "test-key".to_owned(),
        model: "test-model".to_owned(),
        timeout_secs: 30,
        temperature: 0.2,
        max_output_tokens: None,
        response_format: None,
    };
    let provider = OpenAiCompatibleLlmProvider::new(config);

    let events: Vec<_> = provider.stream(&sample_request()).collect().await;
    assert_eq!(events.len(), 1);
    let error = events
        .into_iter()
        .next()
        .expect("event should exist")
        .unwrap_err();
    assert_provider_category(error, ProviderErrorCategory::InvalidResponse);
}

#[tokio::test]
async fn stream_maps_missing_done_marker_to_stream_interrupted_category() {
    let server = MockServer::start();
    server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions");
        then.status(200)
            .header("content-type", "text/event-stream")
            .body("data: {\"choices\":[{\"delta\":{\"content\":\"partial\"}}]}\n\n");
    });

    let config = OpenAiCompatibleConfig {
        base_url: server.base_url(),
        api_key: "test-key".to_owned(),
        model: "test-model".to_owned(),
        timeout_secs: 30,
        temperature: 0.2,
        max_output_tokens: None,
        response_format: None,
    };
    let provider = OpenAiCompatibleLlmProvider::new(config);

    let events: Vec<_> = provider.stream(&sample_request()).collect().await;
    assert!(matches!(
        events.first(),
        Some(Ok(LlmStreamEvent::Delta { content })) if content == "partial"
    ));
    let error = events
        .last()
        .expect("stream should report interruption")
        .as_ref()
        .unwrap_err();
    assert_eq!(
        error.is_retryable(),
        ProviderErrorCategory::StreamInterrupted.is_retryable()
    );
    match error {
        AiError::Provider(provider_error) => {
            assert_eq!(
                provider_error.category(),
                ProviderErrorCategory::StreamInterrupted
            );
        }
        other => panic!("expected stream interrupted provider error, got {other:?}"),
    }
}

// ── 新增错误分类可达性测试 ──
