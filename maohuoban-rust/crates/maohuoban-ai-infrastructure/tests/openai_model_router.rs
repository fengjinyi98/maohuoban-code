// openai_model_router OpenAI 兼容 Provider 模型路由测试
// 核心职责：
// - 验证请求中的模型 label 会解析为配置的 provider model
// - 验证未知 label 在发起 HTTP 调用前失败

use httpmock::MockServer;
use maohuoban_ai_application::ai::ports::LlmProvider;
use maohuoban_ai_domain::ai::{
    AiError, LlmChatRequest, LlmDiagnosticsCorrelation, LlmMessage, LlmRole, ProviderErrorCategory,
};
use maohuoban_ai_infrastructure::provider::{OpenAiCompatibleConfig, OpenAiCompatibleLlmProvider};

fn sample_request_with_model(model: &str) -> LlmChatRequest {
    LlmChatRequest {
        model: model.to_owned(),
        messages: vec![LlmMessage {
            role: LlmRole::User,
            content: "毛球怎么样了".to_owned(),
            reasoning_content: None,
            tool_call_id: None,
            tool_calls: Vec::new(),
        }],
        tools: vec![],
        tool_choice: None,
        temperature: 0.2,
        stream: false,
        max_output_tokens: None,
        response_format: None,
        diagnostics_correlation: LlmDiagnosticsCorrelation::default(),
    }
}

fn config(base_url: String) -> OpenAiCompatibleConfig {
    OpenAiCompatibleConfig {
        base_url,
        api_key: "test-api-key".to_owned(),
        model: "configured-primary-model".to_owned(),
        timeout_secs: 30,
        temperature: 0.2,
        max_output_tokens: None,
        response_format: None,
    }
}

fn assert_provider_category(error: AiError, expected: ProviderErrorCategory) {
    match error {
        AiError::Provider(provider_error) => {
            assert_eq!(provider_error.category(), expected);
        }
        other => panic!("expected provider error category {expected:?}, got {other:?}"),
    }
}

#[tokio::test]
async fn request_model_label_routes_to_configured_provider_model() {
    let server = MockServer::start();
    let mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .json_body_partial(r#"{"model":"configured-primary-model"}"#);
        then.status(200)
            .header("content-type", "application/json")
            .json_body(serde_json::json!({
                "id": "chatcmpl-1",
                "model": "configured-primary-model",
                "choices": [{
                    "index": 0,
                    "message": {"role": "assistant", "content": "ok"},
                    "finish_reason": "stop"
                }],
                "usage": {"prompt_tokens": 1, "completion_tokens": 1, "total_tokens": 2}
            }));
    });

    let provider = OpenAiCompatibleLlmProvider::new(config(server.base_url()));

    let _ = provider
        .complete(&sample_request_with_model("primary"))
        .await
        .expect("complete should succeed");

    mock.assert();
}

#[tokio::test]
async fn unknown_request_model_label_returns_not_configured_before_http_call() {
    let server = MockServer::start();
    let mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions");
        then.status(200);
    });
    let provider = OpenAiCompatibleLlmProvider::new(config(server.base_url()));

    let result = provider
        .complete(&sample_request_with_model("experimental"))
        .await;

    assert!(result.is_err());
    assert_provider_category(result.unwrap_err(), ProviderErrorCategory::NotConfigured);
    mock.assert_hits(0);
}
