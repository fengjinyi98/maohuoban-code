// chat_stream_runtime_tools Runtime 工具链路流式合同测试
// 核心职责：
// - 验证模型工具调用经 Tool Gateway 执行后回灌到二次模型
// - 验证工具进度在二次模型完成前通过 SSE 到达

use axum::http::StatusCode;
use futures_util::StreamExt;
use httpmock::{Mock, MockServer, prelude::HttpMockRequest};
use serde_json::{Value, json};
use std::time::Duration;
use tower::ServiceExt;

use super::{authorized_json_request, login_and_get_token, response_json, response_text};

/// Provider 返回工具调用时 `/api/v1/ai/chat/stream` 通过自有 Agent Runtime 执行工具并回灌
#[tokio::test]
async fn ai_chat_stream_executes_runtime_tool_call_and_followup_model() {
    let server = MockServer::start();
    let mut config = maohuoban_rust::BackendConfig::local_test();
    config.ai_llm_provider_config = maohuoban_ai_infrastructure::provider::OpenAiCompatibleConfig {
        base_url: server.base_url(),
        api_key: "contract-api-key".to_owned(),
        model: "contract-model".to_owned(),
        timeout_secs: 5,
        temperature: 0.2,
        max_output_tokens: None,
        response_format: None,
    }
    .into();
    let app = maohuoban_rust::test_support::spawn_auth_test_app_with_config(config).await;
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139021", "ios-ai-runtime-tool").await;
    let pet = create_pet(&app, &access_token, "毛球").await;
    let pet_id = pet["id"].as_str().expect("pet id");
    let (first_mock, second_mock) = install_runtime_tool_call_mocks(&server, pet_id);

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &access_token,
            json!({
                "message": "读取毛球档案后告诉我状态",
                "surface": "home_private",
                "selected_pet_id": pet_id
            }),
        ))
        .await
        .expect("send runtime tool chat stream request");

    assert_eq!(response.status(), StatusCode::OK);
    let text = response_text(response).await;

    first_mock.assert();
    second_mock.assert();
    assert!(
        text.contains("event: execution_trace_started")
            && text.contains("event: execution_trace_completed")
            && text.contains("正在查看毛球档案"),
        "SSE should contain runtime execution trace events, got: {text}"
    );
    let started_events = sse_event_data_all(&text, "execution_trace_started");
    assert!(
        started_events.iter().any(|event| {
            event["display_text"]
                .as_str()
                .is_some_and(|text| text.contains("正在查看毛球档案"))
        }),
        "SSE should contain runtime execution trace start text, got: {started_events:?}"
    );
    let completed_events = sse_event_data_all(&text, "execution_trace_completed");
    assert!(
        completed_events.iter().any(|event| {
            event["display_text"]
                .as_str()
                .is_some_and(|text| text.contains("正在查看毛球档案"))
                && event["status"] == "completed"
        }),
        "SSE should contain runtime execution trace completion text, got: {completed_events:?}"
    );
    assert!(
        !text.contains("runtime_tool") && !text.contains("load_pet_identity_context"),
        "SSE should not expose internal runtime tool names, got: {text}"
    );
    assert!(
        started_events
            .iter()
            .chain(completed_events.iter())
            .all(|event| event.get("tool_name").is_none()),
        "execution trace should not expose internal tool names"
    );
    assert!(
        completed_events
            .iter()
            .all(|event| event.get("tool_call_id").is_none()),
        "execution trace should not expose internal tool call ids"
    );
    assert!(
        text.contains("已读取毛球档案，当前可以继续观察精神和食欲。"),
        "SSE should contain followup model final text, got: {text}"
    );
    assert!(
        text.contains("event: answer_completed"),
        "SSE should contain answer_completed event, got: {text}"
    );
}

/// Runtime 工具进度在二次模型完成前通过 SSE 到达
#[tokio::test]
async fn ai_chat_stream_emits_runtime_tool_progress_before_followup_model_finishes() {
    let server = MockServer::start();
    let mut config = maohuoban_rust::BackendConfig::local_test();
    config.ai_llm_provider_config = maohuoban_ai_infrastructure::provider::OpenAiCompatibleConfig {
        base_url: server.base_url(),
        api_key: "contract-api-key".to_owned(),
        model: "contract-model".to_owned(),
        timeout_secs: 5,
        temperature: 0.2,
        max_output_tokens: None,
        response_format: None,
    }
    .into();
    let app = maohuoban_rust::test_support::spawn_auth_test_app_with_config(config).await;
    app.reset().await;
    let access_token =
        login_and_get_token(&app, "13800139022", "ios-ai-runtime-tool-progress").await;
    let pet = create_pet(&app, &access_token, "毛球").await;
    let pet_id = pet["id"].as_str().expect("pet id");
    let (first_mock, second_mock) = install_runtime_tool_call_mocks_with_followup_delay(
        &server,
        pet_id,
        Duration::from_secs(3),
    );

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &access_token,
            json!({
                "message": "读取毛球档案后告诉我状态",
                "surface": "home_private",
                "selected_pet_id": pet_id
            }),
        ))
        .await
        .expect("send runtime tool progress chat stream request");

    assert_eq!(response.status(), StatusCode::OK);
    let mut body_stream = response.into_body().into_data_stream();
    let partial_text = read_sse_until_contains(
        &mut body_stream,
        &[
            "event: execution_trace_started",
            "正在查看毛球档案",
            "event: execution_trace_completed",
            "\"status\":\"completed\"",
        ],
        Duration::from_millis(500),
    )
    .await;

    first_mock.assert();
    let started_events = sse_event_data_all(&partial_text, "execution_trace_started");
    assert!(
        started_events
            .iter()
            .any(|event| event["display_text"] == "正在查看毛球档案"),
        "SSE should stream runtime execution trace start before followup model finishes, got: {started_events:?}"
    );
    let completed_events = sse_event_data_all(&partial_text, "execution_trace_completed");
    assert!(
        completed_events.iter().any(|event| {
            event["display_text"] == "正在查看毛球档案" && event["status"] == "completed"
        }),
        "SSE should stream backend-provided execution trace completion text, got: {completed_events:?}"
    );
    let mut full_text = partial_text;
    while let Some(chunk) = body_stream.next().await {
        let chunk = chunk.expect("read remaining SSE chunk");
        full_text.push_str(&String::from_utf8_lossy(&chunk));
    }
    second_mock.assert();
    assert!(
        full_text.contains("已读取毛球档案，当前可以继续观察精神和食欲。"),
        "SSE should still complete with followup model answer, got: {full_text}"
    );
}

async fn create_pet(
    app: &maohuoban_rust::test_support::AuthTestApp,
    access_token: &str,
    name: &str,
) -> Value {
    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/pets",
            access_token,
            json!({
                "name": name,
                "species": "cat",
                "breed": "英短",
                "sex": "male",
                "birthday": "2024-01-01",
                "arrival_date": "2024-03-01"
            }),
        ))
        .await
        .expect("create pet");

    assert_eq!(response.status(), StatusCode::CREATED);
    response_json(response).await["data"].clone()
}

fn sse_event_data_all(text: &str, event_name: &str) -> Vec<Value> {
    let mut values = Vec::new();
    let mut lines = text.lines();
    while let Some(line) = lines.next() {
        if line.trim() == format!("event: {event_name}") {
            for data_line in lines.by_ref() {
                if let Some(data) = data_line.strip_prefix("data: ") {
                    values.push(serde_json::from_str(data).expect("parse sse data"));
                    break;
                }
            }
        }
    }
    values
}

/// `read_sse_until_contains` 逐块读取 SSE 直到命中目标片段
/// 核心职责：
/// - 验证 SSE 事件在 body 未完成前可被消费
/// - 为工具进度实时性测试保留已读取文本
async fn read_sse_until_contains(
    body_stream: &mut axum::body::BodyDataStream,
    expected_fragments: &[&str],
    timeout: Duration,
) -> String {
    tokio::time::timeout(timeout, async {
        let mut text = String::new();
        while !expected_fragments
            .iter()
            .all(|fragment| text.contains(fragment))
        {
            let chunk = body_stream
                .next()
                .await
                .expect("SSE stream should continue before expected fragments")
                .expect("read SSE chunk");
            text.push_str(&String::from_utf8_lossy(&chunk));
        }
        text
    })
    .await
    .expect("SSE should emit expected fragments before timeout")
}

fn install_runtime_tool_call_mocks<'a>(
    server: &'a MockServer,
    pet_id: &str,
) -> (Mock<'a>, Mock<'a>) {
    install_runtime_tool_call_mocks_with_followup_delay(server, pet_id, Duration::ZERO)
}

fn install_runtime_tool_call_mocks_with_followup_delay<'a>(
    server: &'a MockServer,
    pet_id: &str,
    followup_delay: Duration,
) -> (Mock<'a>, Mock<'a>) {
    let first_body = runtime_tool_call_response_body(pet_id);
    let first_mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .matches(runtime_first_model_request)
            .body_contains("\"stream\":true")
            .body_contains("\"tools\"")
            .body_contains("load_pet_identity_context");
        then.status(200)
            .header("content-type", "text/event-stream")
            .body(first_body);
    });
    let second_mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .matches(runtime_followup_model_request)
            .body_contains("\"stream\":true")
            .body_contains("\"role\":\"tool\"")
            .body_contains("\"tool_call_id\":\"call_1\"");
        then.status(200)
            .delay(followup_delay)
            .header("content-type", "text/event-stream")
            .body(runtime_tool_followup_response_body());
    });
    (first_mock, second_mock)
}

fn runtime_tool_call_response_body(pet_id: &str) -> String {
    let arguments = serde_json::json!({ "pet_id": pet_id }).to_string();
    format!(
        "data: {{\"choices\":[{{\"delta\":{{\"tool_calls\":[{{\"id\":\"call_1\",\"function\":{{\"name\":\"load_pet_identity_context\",\"arguments\":{arguments:?}}}}}]}}}}]}}\n\n\
         data: {{\"choices\":[{{\"finish_reason\":\"tool_calls\"}}],\"usage\":{{\"prompt_tokens\":8,\"completion_tokens\":2,\"total_tokens\":10}}}}\n\n\
         data: [DONE]\n\n"
    )
}

fn runtime_tool_followup_response_body() -> &'static str {
    "data: {\"choices\":[{\"delta\":{\"content\":\"已读取毛球档案，当前可以继续观察精神和食欲。\"}}]}\n\n\
     data: {\"choices\":[{\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":12,\"completion_tokens\":8,\"total_tokens\":20}}\n\n\
     data: [DONE]\n\n"
}

fn runtime_first_model_request(req: &HttpMockRequest) -> bool {
    let body = request_body(req);
    body.contains("\"tools\"")
        && body.contains("load_pet_identity_context")
        && !body.contains("\"role\":\"tool\"")
}

fn runtime_followup_model_request(req: &HttpMockRequest) -> bool {
    let body = request_body(req);
    body.contains("\"role\":\"tool\"") && body.contains("\"tool_call_id\":\"call_1\"")
}

fn request_body(req: &HttpMockRequest) -> String {
    req.body
        .as_ref()
        .map(|body| String::from_utf8_lossy(body).into_owned())
        .unwrap_or_default()
}
