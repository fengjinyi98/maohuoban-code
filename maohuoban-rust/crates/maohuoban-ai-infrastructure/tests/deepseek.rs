// deepseek DeepSeek 厂商 Provider 测试
// 核心职责：
// - 验证 DeepSeek Provider 独立封装厂商默认行为
// - 复用 OpenAI 兼容协议访问 DeepSeek Chat Completions

use futures_util::StreamExt;
use httpmock::MockServer;
use maohuoban_ai_application::ai::ports::LlmProvider;
use maohuoban_ai_domain::ai::{
    LlmChatRequest, LlmDiagnosticsCorrelation, LlmFinishReason, LlmMessage, LlmRole,
    LlmStreamEvent, LlmToolSchema,
};
use maohuoban_ai_infrastructure::provider::{DeepSeekConfig, DeepSeekLlmProvider};

fn sample_request() -> LlmChatRequest {
    LlmChatRequest {
        model: "primary".to_owned(),
        messages: vec![LlmMessage {
            role: LlmRole::User,
            content: "请用 json 回答毛球今天怎么样".to_owned(),
            reasoning_content: None,
            tool_call_id: None,
            tool_calls: Vec::new(),
        }],
        tools: vec![LlmToolSchema {
            name: "load_pet_identity_context".to_owned(),
            description: "加载宠物身份".to_owned(),
            parameters: serde_json::json!({"type": "object"}),
        }],
        tool_choice: Some("auto".to_owned()),
        temperature: 0.2,
        stream: false,
        max_output_tokens: None,
        response_format: None,
        diagnostics_correlation: LlmDiagnosticsCorrelation::default(),
    }
}

#[tokio::test]
async fn deepseek_provider_uses_openai_compatible_protocol_without_forcing_json_output() {
    let server = MockServer::start();
    let mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer deepseek-test-key")
            .body_contains("\"model\":\"deepseek-v4-flash\"");
        then.status(200)
            .header("content-type", "application/json")
            .json_body(serde_json::json!({
                "id": "chatcmpl-deepseek",
                "model": "deepseek-v4-flash",
                "choices": [{
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": "{\"answer_text\":\"毛球今天精神不错。\",\"display_blocks\":[{\"type\":\"paragraph\",\"text\":\"毛球今天精神不错。\"}]}"
                    },
                    "finish_reason": "stop"
                }],
                "usage": {
                    "prompt_tokens": 12,
                    "completion_tokens": 20,
                    "total_tokens": 32
                }
            }));
    });

    let provider = DeepSeekLlmProvider::new(DeepSeekConfig {
        base_url: server.base_url(),
        api_key: "deepseek-test-key".to_owned(),
        model: "deepseek-v4-flash".to_owned(),
        timeout_secs: 30,
        temperature: 0.2,
        max_output_tokens: None,
        response_format: None,
    });

    let response = provider
        .complete(&sample_request())
        .await
        .expect("deepseek complete");

    mock.assert();
    assert_eq!(response.model, "deepseek-v4-flash");
    assert_eq!(response.finish_reason, LlmFinishReason::Stop);
    assert!(response.message.content.contains("\"answer_text\""));
}

#[tokio::test]
async fn deepseek_provider_streams_openai_compatible_tool_calls_without_json_output() {
    let server = MockServer::start();
    let mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer deepseek-test-key")
            .body_contains("\"model\":\"deepseek-v4-flash\"")
            .body_contains("\"stream\":true")
            .body_contains("\"tools\"")
            .body_contains("load_pet_identity_context");
        then.status(200)
            .header("content-type", "text/event-stream")
            .body(
                "data: {\"choices\":[{\"delta\":{\"reasoning_content\":\"需要先读取宠物档案\"}}]}\n\n\
                 data: {\"choices\":[{\"delta\":{\"tool_calls\":[{\"index\":0,\"id\":\"call_deepseek_1\",\"type\":\"function\",\"function\":{\"name\":\"load_pet_identity_context\",\"arguments\":\"\"}}]}}]}\n\n\
                 data: {\"choices\":[{\"delta\":{\"tool_calls\":[{\"index\":0,\"function\":{\"arguments\":\"{\\\"pet_id\\\":\\\"11111111-1111-1111-1111-111111111111\\\"}\"}}]}}]}\n\n\
                 data: {\"choices\":[{\"delta\":{},\"finish_reason\":\"tool_calls\"}],\"usage\":{\"prompt_tokens\":12,\"completion_tokens\":5,\"total_tokens\":17}}\n\n\
                 data: [DONE]\n\n",
            );
    });

    let provider = DeepSeekLlmProvider::new(DeepSeekConfig {
        base_url: server.base_url(),
        api_key: "deepseek-test-key".to_owned(),
        model: "deepseek-v4-flash".to_owned(),
        timeout_secs: 30,
        temperature: 0.2,
        max_output_tokens: None,
        response_format: None,
    });

    let events: Vec<_> = provider.stream(&sample_request()).collect().await;

    mock.assert();
    let tool_call = events.iter().find_map(|event| match event {
        Ok(LlmStreamEvent::ToolCall { tool_call }) => Some(tool_call),
        _ => None,
    });
    let reasoning = events.iter().find_map(|event| match event {
        Ok(LlmStreamEvent::ReasoningDelta { content }) => Some(content.as_str()),
        _ => None,
    });
    let finish = events.iter().find_map(|event| match event {
        Ok(LlmStreamEvent::Finish {
            finish_reason,
            usage,
        }) => Some((*finish_reason, *usage)),
        _ => None,
    });

    let tool_call = tool_call.expect("deepseek stream should produce tool call");
    assert_eq!(reasoning, Some("需要先读取宠物档案"));
    assert_eq!(tool_call.id, "call_deepseek_1");
    assert_eq!(tool_call.name, "load_pet_identity_context");
    assert_eq!(
        tool_call.arguments,
        "{\"pet_id\":\"11111111-1111-1111-1111-111111111111\"}"
    );
    assert_eq!(
        finish,
        Some((
            LlmFinishReason::ToolCalls,
            maohuoban_ai_domain::ai::LlmUsage {
                input_tokens: 12,
                output_tokens: 5,
                total_tokens: 17,
            }
        ))
    );
}

#[test]
fn deepseek_config_does_not_inject_json_output_or_token_limit() {
    let config = DeepSeekConfig {
        base_url: "https://api.deepseek.com".to_owned(),
        api_key: "deepseek-test-key".to_owned(),
        model: "deepseek-v4-flash".to_owned(),
        timeout_secs: 30,
        temperature: 0.2,
        max_output_tokens: None,
        response_format: None,
    }
    .into_openai_compatible_config();

    assert_eq!(config.max_output_tokens, None);
    assert_eq!(config.response_format, None);
}

// ── DeepSeek ProviderCapability 合同验证 ──

#[test]
fn deepseek_provider_uses_correct_capability_profile() {
    use maohuoban_ai_domain::ai::ProviderCapability;

    let cap = ProviderCapability::deepseek("deepseek-v4-flash");
    assert_eq!(cap.provider_name, "deepseek");
    assert_eq!(cap.model_route, "deepseek-v4-flash");
    assert_eq!(cap.context_window, 128_000);
    assert!(cap.supports_stream);
    assert!(cap.supports_reasoning_content);
    assert!(cap.supports_tool_calls);
    // DeepSeek 能力差异
    assert!(!cap.supports_parallel_tool_calls);
    assert!(!cap.supports_json_output);
    assert!(cap.supports_response_format);
    assert!(cap.supports_system_prompt);
}

#[test]
fn deepseek_request_policy_respects_capability() {
    use maohuoban_ai_application::ai::provider_capability::ProviderRequestPolicy;
    use maohuoban_ai_domain::ai::{
        LlmChatRequest, LlmDiagnosticsCorrelation, LlmMessage, LlmRole, ProviderCapability,
    };

    let cap = ProviderCapability::deepseek("deepseek-v4-flash");
    let req = LlmChatRequest {
        model: "primary".into(),
        messages: vec![LlmMessage {
            role: LlmRole::User,
            content: "test".into(),
            reasoning_content: None,
            tool_call_id: None,
            tool_calls: vec![],
        }],
        tools: vec![],
        tool_choice: None,
        temperature: 0.2,
        stream: false,
        max_output_tokens: None,
        response_format: Some(serde_json::json!({"type": "json_object"})),
        diagnostics_correlation: LlmDiagnosticsCorrelation::default(),
    };

    // DeepSeek 不支持 JSON 输出
    assert!(!ProviderRequestPolicy::should_send_json_output(&cap, &req));
    // 但 response_format 字段可以发送（标记支持但策略保护）
    assert!(ProviderRequestPolicy::should_send_response_format(
        &cap, &req
    ));
    // 不支持并行工具调用
    assert!(!ProviderRequestPolicy::should_send_parallel_tool_calls(
        &cap
    ));
}
