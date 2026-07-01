// deepseek DeepSeek 厂商 Provider 测试
// 核心职责：
// - 验证 DeepSeek Provider 独立封装厂商默认行为
// - 复用 OpenAI 兼容协议访问 DeepSeek Chat Completions

use std::io::{Read, Write};
use std::net::TcpListener;
use std::sync::mpsc;
use std::time::Duration;

use futures_util::StreamExt;
use httpmock::MockServer;
use maohuoban_ai_application::ai::ports::LlmProvider;
use maohuoban_ai_domain::ai::{
    LlmChatRequest, LlmDiagnosticsCorrelation, LlmFinishReason, LlmMessage, LlmRole,
    LlmStreamEvent, LlmToolCall, LlmToolSchema,
};
use maohuoban_ai_infrastructure::provider::{DeepSeekConfig, DeepSeekLlmProvider};
use serde_json::{Value, json};

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

fn sample_deepseek_provider(base_url: String, model: &str) -> DeepSeekLlmProvider {
    DeepSeekLlmProvider::new(DeepSeekConfig {
        base_url,
        api_key: "deepseek-test-key".to_owned(),
        model: model.to_owned(),
        timeout_secs: 30,
        temperature: 0.2,
        max_output_tokens: None,
        response_format: None,
    })
}

fn spawn_body_capture_server() -> (String, mpsc::Receiver<String>) {
    let listener = TcpListener::bind("127.0.0.1:0").expect("bind test server");
    let addr = listener.local_addr().expect("local addr");
    let (body_tx, body_rx) = mpsc::channel();

    std::thread::spawn(move || {
        let (mut stream, _) = listener.accept().expect("accept request");
        let body = read_http_body(&mut stream);
        body_tx.send(body).expect("send captured body");
        let response_body = json!({
            "id": "chatcmpl-deepseek-capture",
            "model": "deepseek-v4-flash",
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
        .find_map(|line| {
            line.strip_prefix("content-length: ")
                .or_else(|| line.strip_prefix("Content-Length: "))
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

fn captured_json(body_rx: &mpsc::Receiver<String>) -> Value {
    let body = body_rx
        .recv_timeout(Duration::from_secs(1))
        .expect("captured request body");
    serde_json::from_str(&body).expect("captured body json")
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

#[tokio::test]
async fn deepseek_v4_request_applies_internal_thinking_policy_and_replay_padding() {
    let (base_url, body_rx) = spawn_body_capture_server();
    let provider = sample_deepseek_provider(base_url, "deepseek-v4-flash");
    let mut request = sample_request();
    request.model = "primary".to_owned();
    request.tools.clear();
    request.tool_choice = None;
    request.messages.push(LlmMessage {
        role: LlmRole::Assistant,
        content: String::new(),
        reasoning_content: None,
        tool_call_id: None,
        tool_calls: vec![LlmToolCall {
            id: "call_1".to_owned(),
            name: "load_pet_identity_context".to_owned(),
            arguments: "{}".to_owned(),
        }],
    });
    request.messages.push(LlmMessage {
        role: LlmRole::Tool,
        content: "{\"facts\":[]}".to_owned(),
        reasoning_content: None,
        tool_call_id: Some("call_1".to_owned()),
        tool_calls: Vec::new(),
    });

    provider
        .complete(&request)
        .await
        .expect("deepseek complete");

    let body = captured_json(&body_rx);
    assert_eq!(body["thinking"], json!({"type": "enabled"}));
    assert_eq!(body["reasoning_effort"], "high");
    assert!(
        body.get("tools").is_none(),
        "follow-up should not resend tools"
    );
    let assistant = &body["messages"][1];
    assert_eq!(assistant["role"], "assistant");
    assert_eq!(assistant["reasoning_content"], "");
    assert_eq!(assistant["tool_calls"][0]["id"], "call_1");
    assert_eq!(
        assistant["tool_calls"][0]["function"]["name"],
        "load_pet_identity_context"
    );
}

#[tokio::test]
async fn deepseek_chat_request_keeps_non_thinking_wire_shape() {
    let (base_url, body_rx) = spawn_body_capture_server();
    let provider = sample_deepseek_provider(base_url, "deepseek-chat");
    let mut request = sample_request();
    request.model = "primary".to_owned();

    provider
        .complete(&request)
        .await
        .expect("deepseek complete");

    let body = captured_json(&body_rx);
    assert!(body.get("thinking").is_none());
    assert!(body.get("reasoning_effort").is_none());
}

#[tokio::test]
async fn deepseek_request_normalizes_union_tool_schema() {
    let (base_url, body_rx) = spawn_body_capture_server();
    let provider = sample_deepseek_provider(base_url, "deepseek-v4-flash");
    let mut request = sample_request();
    request.model = "primary".to_owned();
    request.tools = vec![LlmToolSchema {
        name: "load_pet_identity_context".to_owned(),
        description: "加载宠物身份".to_owned(),
        parameters: json!({
            "type": "object",
            "properties": {
                "date": {
                    "description": "档案日期",
                    "anyOf": [{"type": "string"}, {"type": "integer"}]
                },
                "period": {
                    "oneOf": [{"type": "string"}, {"type": "null"}]
                },
                "mode": {
                    "anyOf": [
                        {"const": "basic", "type": "string"},
                        {"const": "full", "type": "string"}
                    ]
                }
            },
            "required": ["date"]
        }),
    }];

    provider
        .complete(&request)
        .await
        .expect("deepseek complete");

    let body = captured_json(&body_rx);
    let parameters = &body["tools"][0]["function"]["parameters"];
    assert_eq!(
        parameters,
        &json!({
            "type": "object",
            "properties": {
                "date": {
                    "description": "档案日期",
                    "type": "string"
                },
                "period": {
                    "type": "string",
                    "nullable": true
                },
                "mode": {
                    "type": "string",
                    "enum": ["basic", "full"]
                }
            },
            "required": ["date"]
        })
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
