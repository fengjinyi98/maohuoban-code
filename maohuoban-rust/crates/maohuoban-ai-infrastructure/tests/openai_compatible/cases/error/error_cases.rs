use std::time::Duration;

use httpmock::MockServer;
use maohuoban_ai_application::ai::ports::LlmProvider;
use maohuoban_ai_domain::ai::ProviderErrorCategory;
use maohuoban_ai_infrastructure::provider::{OpenAiCompatibleConfig, OpenAiCompatibleLlmProvider};
use serde_json::json;

use crate::support::{assert_provider_category, sample_request};

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
