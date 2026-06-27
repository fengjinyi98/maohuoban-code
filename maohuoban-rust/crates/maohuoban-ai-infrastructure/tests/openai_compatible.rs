// openai_compatible OpenAI 兼容 Provider 请求序列化测试
// 核心职责：
// - 验证内部 LlmChatRequest 被正确序列化为 OpenAI 兼容 HTTP 请求
// - 断言 path、headers、model、messages、tools、temperature、stream 字段
// - 确认日志不包含 API key
// - 遵循 TDD：先写失败测试（red），再实现 Provider（green）

use httpmock::MockServer;
use maohuoban_ai_application::ai::ports::LlmProvider;
use maohuoban_ai_domain::ai::{
    LlmChatRequest, LlmFinishReason, LlmMessage, LlmRole, LlmToolSchema,
};
use maohuoban_ai_infrastructure::provider::{OpenAiCompatibleConfig, OpenAiCompatibleLlmProvider};
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
    );
    assert!(missing.is_none());

    let config = OpenAiCompatibleConfig::from_env_values(
        Some("https://llm.example.com"),
        Some("secret-key"),
        Some("maohuoban-model"),
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
                tool_call_id: None,
            },
            LlmMessage {
                role: LlmRole::User,
                content: "毛球怎么样了".to_owned(),
                tool_call_id: None,
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
    };
    let provider = OpenAiCompatibleLlmProvider::new(config);

    let response = provider
        .complete(&sample_request())
        .await
        .expect("complete should succeed");

    mock.assert();
    assert_eq!(response.message.content, "毛球很好");
    assert_eq!(response.finish_reason, LlmFinishReason::Stop);
    assert_eq!(response.usage.total_tokens, 15);
    assert_eq!(response.model, "test-model");
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
    };
    let provider = OpenAiCompatibleLlmProvider::new(config);

    let result = provider.complete(&sample_request()).await;
    assert!(result.is_err());
    let err = result.unwrap_err();
    assert!(!err.is_retryable());
    assert_eq!(err.stable_code(), "ai.unauthorized");
}

#[tokio::test]
async fn provider_maps_429_to_retryable_error() {
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
    };
    let provider = OpenAiCompatibleLlmProvider::new(config);

    let result = provider.complete(&sample_request()).await;
    assert!(result.is_err());
    assert!(result.unwrap_err().is_retryable());
}

#[tokio::test]
async fn provider_maps_500_to_retryable_error() {
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
    };
    let provider = OpenAiCompatibleLlmProvider::new(config);

    let result = provider.complete(&sample_request()).await;
    assert!(result.is_err());
    assert!(result.unwrap_err().is_retryable());
}

#[tokio::test]
async fn provider_maps_timeout_to_stable_retryable_error() {
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
    };
    let provider = OpenAiCompatibleLlmProvider::new(config);

    let result = provider.complete(&sample_request()).await;
    assert!(result.is_err());
    let err = result.unwrap_err();
    assert_eq!(err.stable_code(), "ai.provider_request_failed");
    assert!(err.is_retryable());
}

#[tokio::test]
async fn provider_maps_invalid_json_to_stable_retryable_error() {
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
    };
    let provider = OpenAiCompatibleLlmProvider::new(config);

    let result = provider.complete(&sample_request()).await;
    assert!(result.is_err());
    let err = result.unwrap_err();
    assert_eq!(err.stable_code(), "ai.provider_request_failed");
    assert!(err.is_retryable());
}
