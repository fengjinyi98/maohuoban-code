use maohuoban_ai_application::ai::ports::LlmProvider;
use maohuoban_ai_domain::ai::ProviderErrorCategory;
use maohuoban_ai_infrastructure::provider::{OpenAiCompatibleConfig, OpenAiCompatibleLlmProvider};

use crate::support::{assert_provider_category, sample_request, spawn_body_capture_server};

#[tokio::test]
async fn provider_maps_connection_refused_to_provider_request_failed() {
    // 使用无效端口触发连接拒绝 → ProviderRequestFailed
    let config = OpenAiCompatibleConfig {
        base_url: "http://127.0.0.1:1".to_owned(),
        api_key: "test-key".to_owned(),
        model: "test-model".to_owned(),
        timeout_secs: 2,
        temperature: 0.2,
        max_output_tokens: None,
        response_format: None,
    };
    let provider = OpenAiCompatibleLlmProvider::new(config);

    let result = provider.complete(&sample_request()).await;
    assert!(result.is_err());
    assert_provider_category(
        result.unwrap_err(),
        ProviderErrorCategory::ProviderRequestFailed,
    );
}

// ── supports_json_output 生产裁剪验证 ──

#[tokio::test]
async fn deepseek_body_strips_json_object_response_format() {
    // 验证 DeepSeek (supports_json_output=false) 不会发送 json_object response_format
    let (base_url, body_rx) = spawn_body_capture_server();
    let profile = maohuoban_ai_application::ai::provider_capability::ProviderProfile::deepseek(
        "deepseek-v4-flash",
    );
    let config = OpenAiCompatibleConfig {
        base_url,
        api_key: "test-key".to_owned(),
        model: "deepseek-v4-flash".to_owned(),
        timeout_secs: 30,
        temperature: 0.2,
        max_output_tokens: None,
        response_format: None,
    };
    let provider = OpenAiCompatibleLlmProvider::new_with_profile(config, profile);

    let mut request = sample_request();
    request.model = "primary".to_owned();
    request.response_format = Some(serde_json::json!({"type": "json_object"}));

    provider
        .complete(&request)
        .await
        .expect("complete should succeed");

    let body = body_rx
        .recv_timeout(std::time::Duration::from_secs(1))
        .expect("captured request body");
    assert!(
        !body.contains("json_object"),
        "DeepSeek must strip json_object response_format, got: {body}"
    );
}
