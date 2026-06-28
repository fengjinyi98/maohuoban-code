use axum::http::StatusCode;
use httpmock::{Mock, MockServer, prelude::HttpMockRequest};
use maohuoban_diagnostics::{
    CapturePolicy, CleanupPolicy, Diagnostics, DiagnosticsConfig, EventKind, FileSegmentStore,
    PrivacyPolicy,
};
use serde_json::Value;
use serde_json::json;
use tower::ServiceExt;

use super::{
    authorized_json_request, json_request, login_and_get_token, response_json, response_text,
};

fn diagnostics_test_lock() -> std::sync::Arc<tokio::sync::Mutex<()>> {
    use std::sync::{Arc, OnceLock};
    use tokio::sync::Mutex;

    static LOCK: OnceLock<Arc<Mutex<()>>> = OnceLock::new();
    LOCK.get_or_init(|| Arc::new(Mutex::new(()))).clone()
}

/// 未登录访问 /api/v1/ai/chat/stream 返回 401
#[tokio::test]
async fn ai_chat_stream_unauthorized_without_token() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;

    let response = app
        .router()
        .clone()
        .oneshot(json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            json!({
                "message": "毛球今天怎么样",
                "surface": "home_private"
            }),
        ))
        .await
        .expect("send chat stream request");

    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
    let body = response_json(response).await;
    assert_eq!(body["success"], false);
    assert_eq!(body["code"], "auth.session_expired");
}

/// 已登录访问 /api/v1/ai/chat/stream 返回 SSE 事件流
/// `DisabledLlmProvider` 会触发 error 事件，但 `message_started` 应该先到达
#[tokio::test]
async fn ai_chat_stream_authenticated_emits_sse_events() {
    let _guard = diagnostics_test_lock().lock_owned().await;
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139001", "ios-ai-stream-test").await;
    let pet = create_pet(&app, &access_token, "毛球").await;
    let pet_id = pet["id"].as_str().expect("pet id");

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &access_token,
            json!({
                "message": "毛球今天怎么样",
                "surface": "home_private",
                "selected_pet_id": pet_id
            }),
        ))
        .await
        .expect("send chat stream request");

    assert_eq!(response.status(), StatusCode::OK);
    let text = response_text(response).await;

    assert!(
        text.contains("event: message_started"),
        "SSE should contain message_started event, got: {text}"
    );
    assert!(
        text.contains("event: error"),
        "SSE should contain error event for disabled provider, got: {text}"
    );
    let started_index = text
        .find("event: message_started")
        .expect("message_started event index");
    let error_index = text.find("event: error").expect("error event index");
    assert!(
        started_index < error_index,
        "message_started should arrive before provider error, got: {text}"
    );

    let error = sse_event_data(&text, "error");
    assert_eq!(error["code"], "ai.provider.not_configured");
    assert_eq!(error["retryable"], false);
    assert_eq!(
        error["safe_fallback_text"],
        "暂时无法获取回答，请稍后重试。"
    );
}

/// 流式聊天写入后端业务链路诊断事件
#[tokio::test]
async fn ai_chat_stream_records_backend_diagnostics_chain() {
    let _guard = diagnostics_test_lock().lock_owned().await;
    let diagnostics = install_ai_test_diagnostics();
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139019", "ios-ai-diagnostics").await;
    let pet = create_pet(&app, &access_token, "毛球").await;
    let pet_id = pet["id"].as_str().expect("pet id");

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &access_token,
            json!({
                "message": "毛球今天拉肚子了怎么办",
                "surface": "home_private",
                "selected_pet_id": pet_id
            }),
        ))
        .await
        .expect("send diagnostics chat stream request");

    assert_eq!(response.status(), StatusCode::OK);
    let _ = response_text(response).await;
    diagnostics.flush().expect("flush diagnostics");

    let events = diagnostics.read_events().expect("diagnostics events");
    assert!(events.iter().any(|event| {
        event.kind == EventKind::Analytics
            && event.message == "ai.chat.stream.request.received"
            && event.metadata["surface"] == json!("home_private")
            && event.metadata["message_length_bucket"] == json!("1_32")
            && event.metadata.get("message").is_none()
    }));
    assert!(events.iter().any(|event| {
        event.message == "ai.chat.gate.decided"
            && event.metadata["gate_decision"] == json!("load_context")
            && event.metadata["context_loaded"] == json!(true)
    }));
    assert!(events.iter().any(|event| {
        event.message == "ai.chat.provider.started"
            && event.metadata["target_pet_present"] == json!(true)
    }));
    assert!(events.iter().any(|event| {
        event.message == "ai.chat.stream.event.emitted"
            && event.metadata["event_name"] == json!("error")
            && event.metadata["error_code"] == json!("ai.provider.not_configured")
    }));
    assert!(events.iter().any(|event| {
        event.message == "ai.chat.provider.error"
            && event.metadata["error_code"] == json!("ai.provider.not_configured")
            && event.metadata["retryable"] == json!(false)
    }));
}

/// 配置 `OpenAI` 兼容 Provider 后 `/api/v1/ai/chat/stream` 返回真实 Provider delta
#[tokio::test]
async fn ai_chat_stream_uses_configured_openai_provider() {
    let server = MockServer::start();
    let mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .body_contains("\"stream\":false")
            .body_contains("只能基于提供的事实包")
            .body_contains("## 目标宠物")
            .body_contains("pet_identity")
            .body_contains("\"tools\"")
            .body_contains("load_pet_identity_context");
        then.status(200)
            .header("content-type", "application/json")
            .body(
                r#"{
                    "id": "chatcmpl-contract",
                    "model": "contract-model",
                    "choices": [
                        {
                            "message": {
                                "role": "assistant",
                                "content": "真实 Provider"
                            },
                            "finish_reason": "stop"
                        }
                    ],
                    "usage": {
                        "prompt_tokens": 2,
                        "completion_tokens": 3,
                        "total_tokens": 5
                    }
                }"#,
            );
    });

    let mut config = maohuoban_rust::BackendConfig::local_test();
    config.ai_llm_provider_config = Some(
        maohuoban_ai_infrastructure::provider::OpenAiCompatibleConfig {
            base_url: server.base_url(),
            api_key: "contract-api-key".to_owned(),
            model: "contract-model".to_owned(),
            timeout_secs: 5,
            temperature: 0.2,
            max_output_tokens: None,
        },
    );
    let app = maohuoban_rust::test_support::spawn_auth_test_app_with_config(config).await;
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139009", "ios-ai-provider-config").await;
    let pet = create_pet(&app, &access_token, "毛球").await;
    let pet_id = pet["id"].as_str().expect("pet id");

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &access_token,
            json!({
                "message": "毛球今天怎么样",
                "surface": "home_private",
                "selected_pet_id": pet_id
            }),
        ))
        .await
        .expect("send configured chat stream request");

    assert_eq!(response.status(), StatusCode::OK);
    let text = response_text(response).await;

    mock.assert();
    assert!(
        text.contains("event: delta"),
        "SSE should contain delta event, got: {text}"
    );
    assert!(
        text.contains("真实 Provider"),
        "SSE should contain configured provider content, got: {text}"
    );
    assert!(
        text.contains("event: message_completed"),
        "SSE should contain completion event, got: {text}"
    );

    let identity_log_count: i64 = sqlx::query_scalar(
        r"
        SELECT COUNT(*)
        FROM ai_tool_access_logs
        WHERE tool_name = 'load_pet_identity_context'
          AND target_pet_id = $1
          AND allowed = true
        ",
    )
    .bind(uuid::Uuid::parse_str(pet_id).expect("pet id"))
    .fetch_one(app.pool())
    .await
    .expect("count identity tool log");

    assert_eq!(identity_log_count, 1);
}

/// Provider 返回工具调用时 `/api/v1/ai/chat/stream` 通过自有 Agent Runtime 执行工具并回灌
#[tokio::test]
async fn ai_chat_stream_executes_runtime_tool_call_and_followup_model() {
    let server = MockServer::start();
    let mut config = maohuoban_rust::BackendConfig::local_test();
    config.ai_llm_provider_config = Some(
        maohuoban_ai_infrastructure::provider::OpenAiCompatibleConfig {
            base_url: server.base_url(),
            api_key: "contract-api-key".to_owned(),
            model: "contract-model".to_owned(),
            timeout_secs: 5,
            temperature: 0.2,
            max_output_tokens: None,
        },
    );
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
        text.contains("event: tool_call") && text.contains("load_pet_identity_context"),
        "SSE should contain runtime tool_call event, got: {text}"
    );
    let tool_call_events = sse_event_data_all(&text, "tool_call");
    assert!(
        tool_call_events.iter().any(|event| {
            event["tool_name"] == "load_pet_identity_context" && event["status"] == "allowed"
        }),
        "SSE should keep runtime tool name on allowed tool_call event, got: {tool_call_events:?}"
    );
    assert!(
        !text.contains("runtime_tool"),
        "SSE should not expose runtime tool placeholder names, got: {text}"
    );
    assert!(
        text.contains("已读取毛球档案，当前可以继续观察精神和食欲。"),
        "SSE should contain followup model final text, got: {text}"
    );
    assert!(
        text.contains("event: message_completed"),
        "SSE should contain message_completed event, got: {text}"
    );
}

/// Provider 输出医疗诊断时由回答校验器回退为安全消息
#[tokio::test]
async fn ai_chat_stream_verifies_and_blocks_medical_diagnosis() {
    let server = MockServer::start();
    let mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .body_contains("\"stream\":false");
        then.status(200)
            .header("content-type", "application/json")
            .body(
                r#"{
                    "id": "chatcmpl-medical",
                    "model": "contract-model",
                    "choices": [
                        {
                            "message": {
                                "role": "assistant",
                                "content": "毛球得了肠胃炎，需要吃阿莫西林。"
                            },
                            "finish_reason": "stop"
                        }
                    ],
                    "usage": {
                        "prompt_tokens": 2,
                        "completion_tokens": 8,
                        "total_tokens": 10
                    }
                }"#,
            );
    });

    let mut config = maohuoban_rust::BackendConfig::local_test();
    config.ai_llm_provider_config = Some(
        maohuoban_ai_infrastructure::provider::OpenAiCompatibleConfig {
            base_url: server.base_url(),
            api_key: "contract-api-key".to_owned(),
            model: "contract-model".to_owned(),
            timeout_secs: 5,
            temperature: 0.2,
            max_output_tokens: None,
        },
    );
    let app = maohuoban_rust::test_support::spawn_auth_test_app_with_config(config).await;
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139012", "ios-ai-verifier").await;
    let pet = create_pet(&app, &access_token, "毛球").await;
    let pet_id = pet["id"].as_str().expect("pet id");

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &access_token,
            json!({
                "message": "毛球拉肚子了，是不是肠胃炎？",
                "surface": "home_private",
                "selected_pet_id": pet_id
            }),
        ))
        .await
        .expect("send verifier chat stream request");

    assert_eq!(response.status(), StatusCode::OK);
    let text = response_text(response).await;

    mock.assert();
    assert!(
        !text.contains("阿莫西林") && !text.contains("得了肠胃炎"),
        "unsafe provider diagnosis should not be streamed, got: {text}"
    );
    assert!(
        text.contains("毛球助手不能进行诊断或开具药物"),
        "SSE should contain verifier safe fallback, got: {text}"
    );
    assert!(
        text.contains("\"status\":\"blocked\"")
            && text.contains("\"blocked_reason\":\"medical_blocked\""),
        "message_completed should include blocked verification, got: {text}"
    );
}

/// `off_topic` 请求写入 gate log，且不调用主 `LLM Provider`
#[tokio::test]
async fn ai_chat_stream_off_topic_records_gate_log_and_skips_provider() {
    let server = MockServer::start();
    let mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions");
        then.status(200)
            .header("content-type", "text/event-stream")
            .body("data: {\"choices\":[{\"delta\":{\"content\":\"不应调用\"}}]}\n\n");
    });

    let mut config = maohuoban_rust::BackendConfig::local_test();
    config.ai_llm_provider_config = Some(
        maohuoban_ai_infrastructure::provider::OpenAiCompatibleConfig {
            base_url: server.base_url(),
            api_key: "contract-api-key".to_owned(),
            model: "contract-model".to_owned(),
            timeout_secs: 5,
            temperature: 0.2,
            max_output_tokens: None,
        },
    );
    let app = maohuoban_rust::test_support::spawn_auth_test_app_with_config(config).await;
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139010", "ios-ai-off-topic").await;

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &access_token,
            json!({
                "message": "帮我写一首关于夏天的诗",
                "surface": "home_private"
            }),
        ))
        .await
        .expect("send off-topic chat stream request");

    assert_eq!(response.status(), StatusCode::OK);
    let text = response_text(response).await;

    mock.assert_hits(0);
    assert!(
        text.contains("event: message_completed"),
        "SSE should complete with a safe boundary message, got: {text}"
    );

    let row: (String, bool, Option<String>) = sqlx::query_as(
        r"
        SELECT intent, context_loaded, risk_signal
        FROM ai_request_gate_logs
        ORDER BY created_at DESC
        LIMIT 1
        ",
    )
    .fetch_one(app.pool())
    .await
    .expect("read latest gate log");

    assert_eq!(row.0, "off_topic");
    assert!(!row.1);
    assert_eq!(row.2, None);
}

/// 宠物领域流式请求会从后端宠物档案解析 selected pet
#[tokio::test]
async fn ai_chat_stream_resolves_selected_pet_from_backend_catalog() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139011", "ios-ai-pet-resolve").await;

    let pet = create_pet(&app, &access_token, "毛球").await;
    let pet_id = pet["id"].as_str().expect("pet id");
    let profile_number = pet["profile_number"].as_str().expect("profile number");

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &access_token,
            json!({
                "message": "毛球今天拉肚子了怎么办",
                "surface": "home_private",
                "selected_pet_id": pet_id
            }),
        ))
        .await
        .expect("send selected pet chat stream request");

    assert_eq!(response.status(), StatusCode::OK);
    let text = response_text(response).await;
    let started = sse_event_data(&text, "message_started");

    assert_eq!(started["target_pet"]["pet_id"], pet_id);
    assert_eq!(started["target_pet"]["pet_name"], "毛球");
    assert_eq!(started["target_pet"]["pet_species"], "cat");
    assert_eq!(started["target_pet"]["profile_number"], profile_number);
    assert!(
        text.contains("event: tool_call") && text.contains("list_authorized_pet_candidates"),
        "SSE should contain authorized pet catalog tool_call, got: {text}"
    );

    let row: (Option<uuid::Uuid>, Option<uuid::Uuid>, bool) = sqlx::query_as(
        r"
        SELECT selected_pet_id, resolved_pet_id, context_loaded
        FROM ai_request_gate_logs
        ORDER BY created_at DESC
        LIMIT 1
        ",
    )
    .fetch_one(app.pool())
    .await
    .expect("read latest gate log");

    let pet_uuid = uuid::Uuid::parse_str(pet_id).expect("parse pet id");
    assert_eq!(row.0, Some(pet_uuid));
    assert_eq!(row.1, Some(pet_uuid));
    assert!(row.2);

    let tool_log: (String, bool, Option<uuid::Uuid>, serde_json::Value) = sqlx::query_as(
        r"
        SELECT tool_name, allowed, target_pet_id, returned_ref_ids
        FROM ai_tool_access_logs
        WHERE tool_name = 'list_authorized_pet_candidates'
        ORDER BY created_at DESC
        LIMIT 1
        ",
    )
    .fetch_one(app.pool())
    .await
    .expect("read latest tool access log");

    assert_eq!(tool_log.0, "list_authorized_pet_candidates");
    assert!(tool_log.1);
    assert_eq!(tool_log.2, Some(pet_uuid));
    assert_eq!(tool_log.3, json!([pet_id]));

    let snapshot: serde_json::Value = sqlx::query_scalar(
        r"
        SELECT pet_display_snapshot
        FROM ai_chat_sessions
        WHERE primary_pet_id = $1
        ORDER BY updated_at DESC
        LIMIT 1
        ",
    )
    .bind(pet_uuid)
    .fetch_one(app.pool())
    .await
    .expect("read session pet snapshot");

    assert_eq!(snapshot["pet_id"], pet_id);
    assert_eq!(snapshot["pet_name"], "毛球");
    assert_eq!(snapshot["pet_species"], "cat");
    assert_eq!(snapshot["profile_number"], profile_number);
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

fn install_ai_test_diagnostics() -> Diagnostics {
    let root =
        std::env::temp_dir().join(format!("maohuoban-ai-diagnostics-{}", uuid::Uuid::new_v4()));
    let store = FileSegmentStore::new(root.join("segments"), 1024 * 1024).expect("store");
    Diagnostics::install(DiagnosticsConfig {
        service_name: "maohuoban-rust".to_owned(),
        environment: "test".to_owned(),
        privacy: PrivacyPolicy::default(),
        capture: CapturePolicy::default(),
        cleanup: CleanupPolicy::default(),
        store: Box::new(store),
    })
    .expect("install diagnostics")
}

fn sse_event_data(text: &str, event_name: &str) -> Value {
    let mut lines = text.lines();
    while let Some(line) = lines.next() {
        if line.trim() == format!("event: {event_name}") {
            for data_line in lines.by_ref() {
                if let Some(data) = data_line.strip_prefix("data: ") {
                    return serde_json::from_str(data).expect("parse sse data");
                }
            }
        }
    }

    panic!("missing SSE event {event_name}, got: {text}");
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

fn install_runtime_tool_call_mocks<'a>(
    server: &'a MockServer,
    pet_id: &str,
) -> (Mock<'a>, Mock<'a>) {
    let first_body = runtime_tool_call_response_body(pet_id);
    let first_mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .matches(runtime_first_model_request)
            .body_contains("\"tools\"")
            .body_contains("load_pet_identity_context");
        then.status(200)
            .header("content-type", "application/json")
            .body(first_body.to_string());
    });
    let second_mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .matches(runtime_followup_model_request)
            .body_contains("\"role\":\"tool\"")
            .body_contains("\"tool_call_id\":\"call_1\"");
        then.status(200)
            .header("content-type", "application/json")
            .body(runtime_tool_followup_response_body());
    });
    (first_mock, second_mock)
}

fn runtime_tool_call_response_body(pet_id: &str) -> serde_json::Value {
    serde_json::json!({
        "id": "chatcmpl-runtime-tool-call",
        "model": "contract-model",
        "choices": [
            {
                "message": {
                    "role": "assistant",
                    "content": "",
                    "tool_calls": [
                        {
                            "id": "call_1",
                            "type": "function",
                            "function": {
                                "name": "load_pet_identity_context",
                                "arguments": serde_json::json!({ "pet_id": pet_id }).to_string()
                            }
                        }
                    ]
                },
                "finish_reason": "tool_calls"
            }
        ],
        "usage": {
            "prompt_tokens": 8,
            "completion_tokens": 2,
            "total_tokens": 10
        }
    })
}

fn runtime_tool_followup_response_body() -> &'static str {
    r#"{
        "id": "chatcmpl-runtime-final",
        "model": "contract-model",
        "choices": [
            {
                "message": {
                    "role": "assistant",
                    "content": "已读取毛球档案，当前可以继续观察精神和食欲。"
                },
                "finish_reason": "stop"
            }
        ],
        "usage": {
            "prompt_tokens": 12,
            "completion_tokens": 8,
            "total_tokens": 20
        }
    }"#
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
