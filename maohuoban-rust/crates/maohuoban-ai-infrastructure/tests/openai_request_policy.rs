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
use maohuoban_ai_domain::ai::{LlmChatRequest, LlmMessage, LlmRole};
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
        diagnostics_correlation: Default::default(),
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
