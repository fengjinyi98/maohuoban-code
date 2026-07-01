// openai_request_policy OpenAI 兼容请求策略测试
// 核心职责：
// - 验证 Provider 尊重 Runtime 请求级参数
// - 避免厂商配置覆盖本轮模型调用策略

use std::io::{Read, Write};
use std::net::TcpListener;
use std::sync::mpsc;
use std::time::Duration;

use httpmock::MockServer;
use maohuoban_ai_application::ai::ports::LlmProvider;
use maohuoban_ai_domain::ai::{LlmChatRequest, LlmDiagnosticsCorrelation, LlmMessage, LlmRole};
use maohuoban_ai_infrastructure::provider::{OpenAiCompatibleConfig, OpenAiCompatibleLlmProvider};

fn request_with_temperature(temperature: f32) -> LlmChatRequest {
    LlmChatRequest {
        model: "primary".to_owned(),
        messages: vec![LlmMessage {
            role: LlmRole::User,
            content: "毛球怎么样了".to_owned(),
            reasoning_content: None,
            tool_call_id: None,
            tool_calls: Vec::new(),
        }],
        tools: Vec::new(),
        tool_choice: None,
        temperature,
        stream: false,
        max_output_tokens: None,
        response_format: None,
        diagnostics_correlation: LlmDiagnosticsCorrelation::default(),
    }
}

#[tokio::test]
async fn provider_uses_request_temperature_instead_of_provider_default() {
    let server = MockServer::start();
    let mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .json_body_partial(r#"{"temperature":0.5}"#);
        then.status(200)
            .header("content-type", "application/json")
            .json_body(serde_json::json!({
                "id": "chatcmpl-temperature",
                "model": "configured-primary-model",
                "choices": [{
                    "index": 0,
                    "message": {"role": "assistant", "content": "ok"},
                    "finish_reason": "stop"
                }],
                "usage": {"prompt_tokens": 1, "completion_tokens": 1, "total_tokens": 2}
            }));
    });

    let provider = OpenAiCompatibleLlmProvider::new(OpenAiCompatibleConfig {
        base_url: server.base_url(),
        api_key: "test-api-key".to_owned(),
        model: "configured-primary-model".to_owned(),
        timeout_secs: 30,
        temperature: 0.1,
        max_output_tokens: None,
        response_format: None,
    });

    provider
        .complete(&request_with_temperature(0.5))
        .await
        .expect("complete should succeed");

    mock.assert();
}

#[tokio::test]
async fn provider_does_not_apply_configured_json_or_token_defaults_without_request_policy() {
    let (base_url, body_rx) = spawn_body_capture_server();
    let provider = OpenAiCompatibleLlmProvider::new(OpenAiCompatibleConfig {
        base_url,
        api_key: "test-api-key".to_owned(),
        model: "configured-primary-model".to_owned(),
        timeout_secs: 30,
        temperature: 0.1,
        max_output_tokens: Some(2048),
        response_format: Some(serde_json::json!({ "type": "json_object" })),
    });

    provider
        .complete(&request_with_temperature(0.5))
        .await
        .expect("complete should succeed");

    let body = body_rx
        .recv_timeout(Duration::from_secs(1))
        .expect("captured request body");
    assert!(!body.contains("response_format"));
    assert!(!body.contains("max_tokens"));
}

fn spawn_body_capture_server() -> (String, mpsc::Receiver<String>) {
    let listener = TcpListener::bind("127.0.0.1:0").expect("bind test server");
    let addr = listener.local_addr().expect("local addr");
    let (body_tx, body_rx) = mpsc::channel();

    std::thread::spawn(move || {
        let (mut stream, _) = listener.accept().expect("accept request");
        let body = read_http_body(&mut stream);
        body_tx.send(body).expect("send captured body");
        let response_body = serde_json::json!({
            "id": "chatcmpl-policy",
            "model": "configured-primary-model",
            "choices": [{
                "index": 0,
                "message": {"role": "assistant", "content": "ok"},
                "finish_reason": "stop"
            }],
            "usage": {"prompt_tokens": 1, "completion_tokens": 1, "total_tokens": 2}
        })
        .to_string();
        let response = format!(
            "HTTP/1.1 200 OK\r\ncontent-type: application/json\r\ncontent-length: {}\r\n\r\n{}",
            response_body.len(),
            response_body
        );
        stream
            .write_all(response.as_bytes())
            .expect("write response");
    });

    (format!("http://{addr}"), body_rx)
}

fn read_http_body(stream: &mut std::net::TcpStream) -> String {
    let mut buffer = Vec::new();
    let mut chunk = [0_u8; 1024];
    let header_end = loop {
        let read = stream.read(&mut chunk).expect("read request");
        assert!(read > 0, "request closed before headers");
        buffer.extend_from_slice(&chunk[..read]);
        if let Some(index) = find_bytes(&buffer, b"\r\n\r\n") {
            break index + 4;
        }
    };

    let headers = String::from_utf8_lossy(&buffer[..header_end]);
    let content_length = headers
        .lines()
        .find_map(|line| line.strip_prefix("content-length: "))
        .or_else(|| {
            headers
                .lines()
                .find_map(|line| line.strip_prefix("Content-Length: "))
        })
        .and_then(|value| value.parse::<usize>().ok())
        .expect("content-length header");

    while buffer.len() < header_end + content_length {
        let read = stream.read(&mut chunk).expect("read body");
        assert!(read > 0, "request closed before body");
        buffer.extend_from_slice(&chunk[..read]);
    }

    String::from_utf8(buffer[header_end..header_end + content_length].to_vec()).expect("body utf8")
}

fn find_bytes(haystack: &[u8], needle: &[u8]) -> Option<usize> {
    haystack
        .windows(needle.len())
        .position(|window| window == needle)
}

// ── ProviderCapability 与 RequestPolicy 合同测试 ──

use maohuoban_ai_application::ai::provider_capability::{ProviderProfile, ProviderRequestPolicy};
use maohuoban_ai_domain::ai::ProviderCapability;

#[test]
fn openai_compatible_capability_declares_full_feature_set() {
    let cap = ProviderCapability::openai_compatible("test-model");
    assert_eq!(cap.provider_name, "openai_compatible");
    assert!(cap.supports_stream);
    assert!(cap.supports_reasoning_content);
    assert!(cap.supports_tool_calls);
    assert!(cap.supports_parallel_tool_calls);
    assert!(cap.supports_response_format);
    assert!(cap.supports_json_output);
    assert!(cap.supports_system_prompt);
    assert_eq!(cap.context_window, 128_000);
}

#[test]
fn deepseek_capability_declares_known_differences() {
    let cap = ProviderCapability::deepseek("deepseek-v4-flash");
    assert_eq!(cap.provider_name, "deepseek");
    assert!(cap.supports_stream);
    assert!(cap.supports_reasoning_content);
    assert!(cap.supports_tool_calls);
    // DeepSeek 已知差异
    assert!(!cap.supports_parallel_tool_calls);
    assert!(!cap.supports_json_output);
    // response_format 标记支持但需策略保护
    assert!(cap.supports_response_format);
}

#[test]
fn openai_compatible_profile_binds_capability() {
    let profile = ProviderProfile::openai_compatible("gpt-5");
    assert_eq!(profile.provider_name(), "openai_compatible");
    assert!(profile.capability.supports_json_output);
}

#[test]
fn deepseek_profile_binds_capability() {
    let profile = ProviderProfile::deepseek("deepseek-v4-flash");
    assert_eq!(profile.provider_name(), "deepseek");
    assert!(!profile.capability.supports_json_output);
}

#[test]
fn request_policy_gates_response_format_by_capability() {
    let cap = ProviderCapability::openai_compatible("m");

    // 请求不携带 response_format → 不发送
    let req = request_with_temperature(0.2);
    assert!(!ProviderRequestPolicy::should_send_response_format(
        &cap, &req
    ));

    // 请求携带 response_format + capability 支持 → 发送
    let mut req = request_with_temperature(0.2);
    req.response_format = Some(serde_json::json!({"type": "json_object"}));
    assert!(ProviderRequestPolicy::should_send_response_format(
        &cap, &req
    ));
}

#[test]
fn request_policy_gates_json_output_by_capability() {
    let openai_cap = ProviderCapability::openai_compatible("m");
    let deepseek_cap = ProviderCapability::deepseek("m");

    let mut req = request_with_temperature(0.2);
    req.response_format = Some(serde_json::json!({"type": "json_object"}));

    // OpenAI 兼容支持 JSON 输出
    assert!(ProviderRequestPolicy::should_send_json_output(
        &openai_cap,
        &req
    ));
    // DeepSeek 不支持 JSON 输出
    assert!(!ProviderRequestPolicy::should_send_json_output(
        &deepseek_cap,
        &req
    ));
}

#[test]
fn request_policy_gates_tools_and_tool_choice_by_capability() {
    let cap = ProviderCapability::openai_compatible("m");

    let mut req = request_with_temperature(0.2);
    req.tools = vec![maohuoban_ai_domain::ai::LlmToolSchema {
        name: "test_tool".into(),
        description: "test".into(),
        parameters: serde_json::json!({}),
    }];
    req.tool_choice = Some("auto".into());

    assert!(ProviderRequestPolicy::should_send_tools(&cap, &req));
    assert!(ProviderRequestPolicy::should_send_tool_choice(&cap, &req));
    assert!(ProviderRequestPolicy::should_send_parallel_tool_calls(&cap));
}

#[test]
fn request_policy_gates_reasoning_content() {
    assert!(ProviderRequestPolicy::should_send_reasoning_content(
        &ProviderCapability::openai_compatible("m")
    ));
    assert!(ProviderRequestPolicy::should_send_reasoning_content(
        &ProviderCapability::deepseek("m")
    ));
}

#[test]
fn deepseek_policy_denies_parallel_tool_calls() {
    let deepseek_cap = ProviderCapability::deepseek("m");
    assert!(!ProviderRequestPolicy::should_send_parallel_tool_calls(
        &deepseek_cap
    ));
}

// ── 错误分类映射合同测试 ──

use maohuoban_ai_domain::ai::ProviderErrorCategory;

#[test]
fn error_category_mapping_covers_all_eight_categories() {
    let categories = [
        ProviderErrorCategory::NotConfigured,
        ProviderErrorCategory::Timeout,
        ProviderErrorCategory::RateLimited,
        ProviderErrorCategory::Upstream,
        ProviderErrorCategory::InvalidResponse,
        ProviderErrorCategory::StreamInterrupted,
        ProviderErrorCategory::ProviderRequestFailed,
        ProviderErrorCategory::ProviderStreamError,
    ];
    for cat in categories {
        let name = cat.as_str();
        assert!(!name.is_empty());
        // 验证每种分类都有明确的 snake_case 名
        match cat {
            ProviderErrorCategory::NotConfigured => assert_eq!(name, "not_configured"),
            ProviderErrorCategory::Timeout => assert_eq!(name, "timeout"),
            ProviderErrorCategory::RateLimited => assert_eq!(name, "rate_limited"),
            ProviderErrorCategory::Upstream => assert_eq!(name, "upstream"),
            ProviderErrorCategory::StreamInterrupted => assert_eq!(name, "stream_interrupted"),
            ProviderErrorCategory::InvalidResponse => assert_eq!(name, "invalid_response"),
            ProviderErrorCategory::ProviderRequestFailed => {
                assert_eq!(name, "provider_request_failed");
            }
            ProviderErrorCategory::ProviderStreamError => {
                assert_eq!(name, "provider_stream_error");
            }
        }
    }
}

#[test]
fn retryable_categories_include_transient_failures() {
    // 瞬时故障可重试
    assert!(ProviderErrorCategory::Timeout.is_retryable());
    assert!(ProviderErrorCategory::RateLimited.is_retryable());
    assert!(ProviderErrorCategory::Upstream.is_retryable());
    assert!(ProviderErrorCategory::StreamInterrupted.is_retryable());
    assert!(ProviderErrorCategory::ProviderRequestFailed.is_retryable());
    assert!(ProviderErrorCategory::ProviderStreamError.is_retryable());
}

#[test]
fn non_retryable_categories_are_deterministic() {
    // 确定性失败不应重试
    assert!(!ProviderErrorCategory::NotConfigured.is_retryable());
    assert!(!ProviderErrorCategory::InvalidResponse.is_retryable());
}
