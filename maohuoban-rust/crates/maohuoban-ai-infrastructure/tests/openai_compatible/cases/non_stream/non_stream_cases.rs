use httpmock::MockServer;
use maohuoban_ai_application::ai::ports::LlmProvider;
use maohuoban_ai_domain::ai::{LlmFinishReason, LlmMessage, LlmRole, LlmToolCall};
use maohuoban_ai_infrastructure::provider::{OpenAiCompatibleConfig, OpenAiCompatibleLlmProvider};
use serde_json::json;

use crate::support::sample_request;

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
