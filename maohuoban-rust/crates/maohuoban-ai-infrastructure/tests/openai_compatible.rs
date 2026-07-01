// openai_compatible OpenAI 兼容 Provider 请求序列化测试
// 核心职责：
// - 验证内部 LlmChatRequest 被正确序列化为 OpenAI 兼容 HTTP 请求
// - 断言 path、headers、model、messages、tools、temperature、stream 字段
// - 确认日志不包含 API key
// - 遵循 TDD：先写失败测试（red），再实现 Provider（green）

use futures_util::StreamExt;
use httpmock::MockServer;
use maohuoban_ai_application::ai::ports::LlmProvider;
use maohuoban_ai_domain::ai::{
    AiError, LlmChatRequest, LlmFinishReason, LlmMessage, LlmRole, LlmStreamEvent, LlmToolCall,
    LlmToolSchema, ProviderErrorCategory,
};
use maohuoban_ai_infrastructure::provider::{OpenAiCompatibleConfig, OpenAiCompatibleLlmProvider};
use serde_json::json;
use std::time::Duration;

#[test]
fn provider_config_from_env_values_requires_base_url_key_and_model() {
    let missing = OpenAiCompatibleConfig::from_env_values(
        Some("https://llm.example.com"),
        None,
        Some("maohuoban-model"),
        None,
        None,
        None,
        None,
    );
    assert!(missing.is_none());

    let config = OpenAiCompatibleConfig::from_env_values(
        Some("https://llm.example.com"),
        Some("secret-key"),
        Some("maohuoban-model"),
        None,
        None,
        None,
        None,
    )
    .expect("config should be available");

    assert_eq!(config.base_url, "https://llm.example.com");
    assert_eq!(config.model, "maohuoban-model");
    assert_eq!(config.timeout_secs, 30);
    assert!((config.temperature - 0.2).abs() < f32::EPSILON);
    assert_eq!(config.max_output_tokens, None);
}

#[test]
fn provider_config_parses_optional_limits_and_redacts_debug_key() {
    let config = OpenAiCompatibleConfig::from_env_values(
        Some("https://llm.example.com"),
        Some("secret-key"),
        Some("maohuoban-model"),
        Some("12"),
        Some("0.4"),
        Some("2048"),
        None,
    )
    .expect("config should be available");

    assert_eq!(config.timeout_secs, 12);
    assert!((config.temperature - 0.4).abs() < f32::EPSILON);
    assert_eq!(config.max_output_tokens, Some(2048));

    let debug = format!("{config:?}");
    assert!(debug.contains("api_key: \"<redacted>\""));
    assert!(!debug.contains("secret-key"));
}

fn sample_request() -> LlmChatRequest {
    LlmChatRequest {
        model: "test-model".to_owned(),
        messages: vec![
            LlmMessage {
                role: LlmRole::System,
                content: "你是毛球助手".to_owned(),
                reasoning_content: None,
                tool_call_id: None,
                tool_calls: Vec::new(),
            },
            LlmMessage {
                role: LlmRole::User,
                content: "毛球怎么样了".to_owned(),
                reasoning_content: None,
                tool_call_id: None,
                tool_calls: Vec::new(),
            },
        ],
        tools: vec![LlmToolSchema {
            name: "load_pet_identity_context".to_owned(),
            description: "加载宠物身份".to_owned(),
            parameters: serde_json::json!({"type": "object"}),
        }],
        tool_choice: Some("auto".to_owned()),
        temperature: 0.2,
        stream: false,
        max_output_tokens: Some(1024),
        response_format: None,
        diagnostics_correlation: Default::default(),
    }
}

fn assert_provider_category(error: AiError, expected: ProviderErrorCategory) {
    match error {
        AiError::Provider(provider_error) => {
            assert_eq!(provider_error.category(), expected);
            assert_eq!(provider_error.is_retryable(), expected.is_retryable());
        }
        other => panic!("expected provider error category {expected:?}, got {other:?}"),
    }
}

#[tokio::test]
async fn non_stream_request_serializes_correctly() {
    let server = MockServer::start();
    let mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer test-api-key")
            .header("content-type", "application/json");
        then.status(200)
            .header("content-type", "application/json")
            .json_body(serde_json::json!({
                "id": "chatcmpl-1",
                "model": "test-model",
                "choices": [{
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": "毛球很好"
                    },
                    "finish_reason": "stop"
                }],
                "usage": {
                    "prompt_tokens": 10,
                    "completion_tokens": 5,
                    "total_tokens": 15
                }
            }));
    });

    let config = OpenAiCompatibleConfig {
        base_url: server.base_url(),
        api_key: "test-api-key".to_owned(),
        model: "test-model".to_owned(),
        timeout_secs: 30,
        temperature: 0.2,
        max_output_tokens: Some(1024),
        response_format: None,
    };
    let provider = OpenAiCompatibleLlmProvider::new(config);
    let mut request = sample_request();
    request.model = "primary".to_owned();
    request.max_output_tokens = None;

    let response = provider
        .complete(&request)
        .await
        .expect("complete should succeed");

    mock.assert();
    assert_eq!(response.message.content, "毛球很好");
    assert_eq!(response.finish_reason, LlmFinishReason::Stop);
    assert_eq!(response.usage.total_tokens, 15);
    assert_eq!(response.model, "test-model");
}

#[tokio::test]
async fn non_stream_request_applies_request_json_response_format_and_token_limit() {
    let server = MockServer::start();
    let mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer test-api-key")
            .body_contains("\"response_format\":{\"type\":\"json_object\"}")
            .body_contains("\"max_tokens\":4096");
        then.status(200)
            .header("content-type", "application/json")
            .json_body(json!({
                "id": "chatcmpl-json",
                "model": "deepseek-v4-flash",
                "choices": [{
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": "{\"answer_text\":\"毛球可以先观察精神和食欲。\",\"display_blocks\":[{\"type\":\"paragraph\",\"text\":\"毛球可以先观察精神和食欲。\"}]}"
                    },
                    "finish_reason": "stop"
                }],
                "usage": {
                    "prompt_tokens": 10,
                    "completion_tokens": 20,
                    "total_tokens": 30
                }
            }));
    });

    let config = OpenAiCompatibleConfig {
        base_url: server.base_url(),
        api_key: "test-api-key".to_owned(),
        model: "deepseek-v4-flash".to_owned(),
        timeout_secs: 30,
        temperature: 0.2,
        max_output_tokens: Some(4096),
        response_format: Some(json!({ "type": "json_object" })),
    };
    let provider = OpenAiCompatibleLlmProvider::new(config);
    let mut request = sample_request();
    request.model = "primary".to_owned();
    request.max_output_tokens = Some(4096);
    request.response_format = Some(json!({ "type": "json_object" }));

    let response = provider
        .complete(&request)
        .await
        .expect("complete should succeed");

    mock.assert();
    assert!(response.message.content.contains("\"answer_text\""));
    assert_eq!(response.model, "deepseek-v4-flash");
}

#[tokio::test]
async fn non_stream_request_serializes_assistant_tool_calls_for_followup() {
    let server = MockServer::start();
    let mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .body_contains("\"tool_calls\"")
            .body_contains("\"id\":\"call_1\"")
            .body_contains("\"type\":\"function\"")
            .body_contains("\"function\"")
            .body_contains("\"name\":\"load_pet_identity_context\"")
            .body_contains("\"reasoning_content\":\"需要先读档案\"")
            .body_contains(
                "\"arguments\":\"{\\\"pet_id\\\":\\\"11111111-1111-1111-1111-111111111111\\\"}\"",
            )
            .body_contains("\"tool_call_id\":\"call_1\"");
        then.status(200)
            .header("content-type", "application/json")
            .json_body(json!({
                "id": "chatcmpl-followup",
                "model": "test-model",
                "choices": [{
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": "已查看档案。"
                    },
                    "finish_reason": "stop"
                }],
                "usage": {
                    "prompt_tokens": 20,
                    "completion_tokens": 5,
                    "total_tokens": 25
                }
            }));
    });

    let config = OpenAiCompatibleConfig {
        base_url: server.base_url(),
        api_key: "test-api-key".to_owned(),
        model: "test-model".to_owned(),
        timeout_secs: 30,
        temperature: 0.2,
        max_output_tokens: None,
        response_format: None,
    };
    let provider = OpenAiCompatibleLlmProvider::new(config);
    let mut request = sample_request();
    request.messages.push(LlmMessage {
        role: LlmRole::Assistant,
        content: String::new(),
        reasoning_content: Some("需要先读档案".to_owned()),
        tool_call_id: None,
        tool_calls: vec![LlmToolCall {
            id: "call_1".to_owned(),
            name: "load_pet_identity_context".to_owned(),
            arguments: json!({
                "pet_id": "11111111-1111-1111-1111-111111111111"
            })
            .to_string(),
        }],
    });
    request.messages.push(LlmMessage {
        role: LlmRole::Tool,
        content: "{\"facts\":[]}".to_owned(),
        reasoning_content: None,
        tool_call_id: Some("call_1".to_owned()),
        tool_calls: Vec::new(),
    });

    let response = provider
        .complete(&request)
        .await
        .expect("complete should succeed");

    mock.assert();
    assert_eq!(response.message.content, "已查看档案。");
}

#[tokio::test]
async fn provider_normalizes_base_url_without_v1() {
    let server = MockServer::start();
    let mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions");
        then.status(200).json_body(serde_json::json!({
            "id": "chatcmpl-1",
            "model": "test-model",
            "choices": [{
                "index": 0,
                "message": {"role": "assistant", "content": "ok"},
                "finish_reason": "stop"
            }],
            "usage": {"prompt_tokens": 1, "completion_tokens": 1, "total_tokens": 2}
        }));
    });

    // base_url 以 /v1 结尾，Provider 不应重复追加
    let config = OpenAiCompatibleConfig {
        base_url: format!("{}/v1", server.base_url()),
        api_key: "test-api-key".to_owned(),
        model: "test-model".to_owned(),
        timeout_secs: 30,
        temperature: 0.2,
        max_output_tokens: None,
        response_format: None,
    };
    let provider = OpenAiCompatibleLlmProvider::new(config);

    let _ = provider
        .complete(&sample_request())
        .await
        .expect("complete should succeed");

    mock.assert();
}

#[tokio::test]
async fn provider_maps_401_to_stable_error() {
    let server = MockServer::start();
    server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions");
        then.status(401).json_body(serde_json::json!({
            "error": {"message": "invalid api key"}
        }));
    });

    let config = OpenAiCompatibleConfig {
        base_url: server.base_url(),
        api_key: "bad-key".to_owned(),
        model: "test-model".to_owned(),
        timeout_secs: 30,
        temperature: 0.2,
        max_output_tokens: None,
        response_format: None,
    };
    let provider = OpenAiCompatibleLlmProvider::new(config);

    let result = provider.complete(&sample_request()).await;
    assert!(result.is_err());
    assert_provider_category(result.unwrap_err(), ProviderErrorCategory::NotConfigured);
}

#[tokio::test]
async fn provider_maps_429_to_rate_limited_category() {
    let server = MockServer::start();
    server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions");
        then.status(429).json_body(serde_json::json!({
            "error": {"message": "rate limited"}
        }));
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

    let result = provider.complete(&sample_request()).await;
    assert!(result.is_err());
    assert_provider_category(result.unwrap_err(), ProviderErrorCategory::RateLimited);
}

#[tokio::test]
async fn provider_maps_500_to_upstream_category() {
    let server = MockServer::start();
    server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions");
        then.status(500).json_body(serde_json::json!({
            "error": {"message": "internal error"}
        }));
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

    let result = provider.complete(&sample_request()).await;
    assert!(result.is_err());
    assert_provider_category(result.unwrap_err(), ProviderErrorCategory::Upstream);
}

#[tokio::test]
async fn provider_maps_timeout_to_timeout_category() {
    let server = MockServer::start();
    server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions");
        then.status(200)
            .delay(Duration::from_secs(2))
            .json_body(serde_json::json!({
                "id": "chatcmpl-1",
                "model": "test-model",
                "choices": [{
                    "index": 0,
                    "message": {"role": "assistant", "content": "ok"},
                    "finish_reason": "stop"
                }],
                "usage": {"prompt_tokens": 1, "completion_tokens": 1, "total_tokens": 2}
            }));
    });

    let config = OpenAiCompatibleConfig {
        base_url: server.base_url(),
        api_key: "test-key".to_owned(),
        model: "test-model".to_owned(),
        timeout_secs: 1,
        temperature: 0.2,
        max_output_tokens: None,
        response_format: None,
    };
    let provider = OpenAiCompatibleLlmProvider::new(config);

    let result = provider.complete(&sample_request()).await;
    assert!(result.is_err());
    assert_provider_category(result.unwrap_err(), ProviderErrorCategory::Timeout);
}

#[tokio::test]
async fn provider_maps_invalid_json_to_invalid_response_category() {
    let server = MockServer::start();
    server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions");
        then.status(200)
            .header("content-type", "application/json")
            .body("not-json");
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

    let result = provider.complete(&sample_request()).await;
    assert!(result.is_err());
    assert_provider_category(result.unwrap_err(), ProviderErrorCategory::InvalidResponse);
}

#[tokio::test]
async fn provider_maps_empty_content_without_tool_calls_to_invalid_response() {
    let server = MockServer::start();
    server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions");
        then.status(200)
            .header("content-type", "application/json")
            .json_body(json!({
                "id": "chatcmpl-empty",
                "model": "deepseek-v4-flash",
                "choices": [{
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": ""
                    },
                    "finish_reason": "length"
                }],
                "usage": {
                    "prompt_tokens": 44,
                    "completion_tokens": 64,
                    "total_tokens": 108
                }
            }));
    });

    let config = OpenAiCompatibleConfig {
        base_url: server.base_url(),
        api_key: "test-key".to_owned(),
        model: "deepseek-v4-flash".to_owned(),
        timeout_secs: 30,
        temperature: 0.2,
        max_output_tokens: Some(4096),
        response_format: Some(json!({ "type": "json_object" })),
    };
    let provider = OpenAiCompatibleLlmProvider::new(config);
    let mut request = sample_request();
    request.model = "primary".to_owned();

    let result = provider.complete(&request).await;
    assert!(result.is_err());
    assert_provider_category(result.unwrap_err(), ProviderErrorCategory::InvalidResponse);
}

#[tokio::test]
async fn openai_compatible_maps_provider_errors() {
    let server = MockServer::start();
    server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions");
        then.status(429).json_body(serde_json::json!({
            "error": {"message": "rate limited"}
        }));
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

    let result = provider.complete(&sample_request()).await;
    assert!(result.is_err());
    assert_provider_category(result.unwrap_err(), ProviderErrorCategory::RateLimited);
}

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
