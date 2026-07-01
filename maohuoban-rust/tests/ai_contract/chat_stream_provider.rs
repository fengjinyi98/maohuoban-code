// chat_stream_provider OpenAI 兼容 Provider 流式合同测试
// 核心职责：
// - 验证 HTTP stream 主链路通过 Runtime Workbench 请求 Provider SSE
// - 验证 Provider 输出违规文本时由后端校验器替换为安全消息

use axum::http::StatusCode;
use httpmock::MockServer;
use maohuoban_diagnostics::{
    CapturePolicy, CleanupPolicy, Diagnostics, DiagnosticsConfig, FileSegmentStore, PrivacyPolicy,
};
use serde_json::{Value, json};
use tower::ServiceExt;

use super::{
    authorized_json_request, diagnostics_test_lock, login_and_get_token, response_json,
    response_text,
};

/// 配置 `OpenAI` 兼容 Provider 后 `/api/v1/ai/chat/stream` 返回真实 Provider delta
#[tokio::test]
async fn ai_chat_stream_uses_configured_openai_provider() {
    let _guard = diagnostics_test_lock().lock_owned().await;
    let diagnostics = install_provider_test_diagnostics();
    let server = MockServer::start();
    let mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .body_contains("\"stream\":true")
            .body_contains("只能基于提供的事实包")
            .body_contains("## 目标宠物")
            .body_contains("pet_identity")
            .body_contains("\"tools\"")
            .body_contains("load_pet_identity_context");
        then.status(200)
            .header("content-type", "text/event-stream")
            .body(
                "data: {\"choices\":[{\"delta\":{\"content\":\"真实 Provider\"}}]}\n\n\
                 data: {\"choices\":[{\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":2,\"completion_tokens\":3,\"total_tokens\":5}}\n\n\
                 data: [DONE]\n\n",
            );
    });

    let app = spawn_provider_test_app(&server).await;
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
        text.contains("event: answer_delta"),
        "SSE should contain answer_delta event, got: {text}"
    );
    assert!(
        text.contains("真实 Provider"),
        "SSE should contain configured provider content, got: {text}"
    );
    assert!(
        text.contains("event: answer_completed"),
        "SSE should contain completion event, got: {text}"
    );
    let started = sse_event_data(&text, "message_started");
    let chat_session_id_prefix = uuid_prefix_from_sse(&started, "chat_session_id");
    let message_id_prefix = uuid_prefix_from_sse(&started, "message_id");
    diagnostics.flush().expect("flush diagnostics");
    let events = diagnostics.read_events().expect("diagnostics events");
    for event_name in [
        "ai.provider.openai.request.prepared",
        "ai.provider.openai.http.response.started",
        "ai.provider.openai.stream.chunk",
        "ai.provider.openai.stream.event",
    ] {
        let event = events
            .iter()
            .find(|event| {
                event.message == event_name
                    && event.metadata["chat_session_id_prefix"] == json!(chat_session_id_prefix)
                    && event.metadata["message_id_prefix"] == json!(message_id_prefix)
            })
            .unwrap_or_else(|| panic!("missing provider diagnostics event {event_name}"));
        assert_eq!(
            event.metadata["chat_session_id_prefix"],
            json!(chat_session_id_prefix)
        );
        assert_eq!(
            event.metadata["message_id_prefix"],
            json!(message_id_prefix)
        );
        assert!(
            event.metadata["turn_id_prefix"]
                .as_str()
                .is_some_and(|value| !value.is_empty()),
            "missing turn correlation in {event:?}"
        );
        assert!(
            event.metadata["tool_call_id"].is_string(),
            "missing tool correlation field in {event:?}"
        );
        assert_eq!(event.metadata["provider"], json!("openai_compatible"));
        assert_eq!(event.metadata["model"], json!("contract-model"));
    }
    assert!(events.iter().any(|event| {
        event.message == "ai.provider.openai.request.prepared"
            && event.metadata["chat_session_id_prefix"] == json!(chat_session_id_prefix)
            && event.metadata["message_id_prefix"] == json!(message_id_prefix)
            && event.metadata["provider"] == json!("openai_compatible")
            && event.metadata["model_route"] == json!("primary")
            && event.metadata["model"] == json!("contract-model")
            && event.metadata["request_body_text"]
                .as_str()
                .is_some_and(|body| {
                    body.contains("\"message\":\"毛球今天怎么样\"")
                        || body.contains("毛球今天怎么样")
                })
    }));
    assert!(events.iter().any(|event| {
        event.message == "ai.chat.workbench.built"
            && event.metadata["chat_session_id_prefix"] == json!(chat_session_id_prefix)
            && event.metadata["message_id_prefix"] == json!(message_id_prefix)
            && event.metadata["capability_catalog"]
                .as_array()
                .is_some_and(|capabilities| {
                    capabilities
                        .iter()
                        .any(|value| value == "private_pet_context")
                })
            && event.metadata["visible_tools"]
                .as_array()
                .is_some_and(|tools| {
                    tools
                        .iter()
                        .any(|value| value == "load_pet_identity_context")
                })
            && event.metadata["memory_count"] == json!(0)
            && event.metadata["recent_conversation_count"] == json!(0)
            && event.metadata["context_summary_present"] == json!(false)
    }));
    assert!(events.iter().any(|event| {
        event.message == "ai.provider.openai.stream.chunk"
            && event.metadata["chat_session_id_prefix"] == json!(chat_session_id_prefix)
            && event.metadata["message_id_prefix"] == json!(message_id_prefix)
            && event.metadata["chunk_text"]
                .as_str()
                .is_some_and(|body| body.contains("真实 Provider"))
    }));
    assert!(events.iter().any(|event| {
        event.message == "ai.provider.openai.stream.event"
            && event.metadata["chat_session_id_prefix"] == json!(chat_session_id_prefix)
            && event.metadata["message_id_prefix"] == json!(message_id_prefix)
            && event.metadata["event_name"] == json!("delta")
            && event.metadata["payload"]["content"] == json!("真实 Provider")
    }));
    for event in &events {
        let metadata = serde_json::to_string(&event.metadata).expect("serialize metadata");
        assert!(
            !metadata.contains("Bearer contract-api-key")
                && !metadata.contains("\"api_key\"")
                && !metadata.contains("contract-api-key")
                && !metadata.contains("Cookie"),
            "provider diagnostics leaked auth secret: {event:?}"
        );
    }

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

fn install_provider_test_diagnostics() -> Diagnostics {
    let root = std::env::temp_dir().join(format!(
        "maohuoban-ai-provider-diagnostics-{}",
        uuid::Uuid::new_v4()
    ));
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

/// `spawn_provider_test_app` 使用 mock server 构建 Provider 测试应用
async fn spawn_provider_test_app(server: &MockServer) -> maohuoban_rust::test_support::AuthTestApp {
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
    maohuoban_rust::test_support::spawn_auth_test_app_with_config(config).await
}

/// 助手身份问题没有私域宠物上下文时仍进入后端工作台和 Provider
#[tokio::test]
async fn ai_chat_stream_identity_enters_workbench() {
    let server = MockServer::start();
    let mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .body_contains("你是谁");
        then.status(200)
            .header("content-type", "text/event-stream")
            .body(
                "data: {\"choices\":[{\"delta\":{\"content\":\"我是毛球，可以帮你聊宠物照护和毛伙伴 App 使用。\"}}]}\n\n\
                 data: {\"choices\":[{\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":2,\"completion_tokens\":3,\"total_tokens\":5}}\n\n\
                 data: [DONE]\n\n",
            );
    });

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
    let access_token = login_and_get_token(&app, "13800139022", "ios-ai-identity").await;

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &access_token,
            json!({
                "message": "你是谁",
                "surface": "home_private"
            }),
        ))
        .await
        .expect("send identity chat stream request");

    assert_eq!(response.status(), StatusCode::OK);
    let text = response_text(response).await;

    mock.assert();
    assert!(
        text.contains("我是毛球，可以帮你聊宠物照护和毛伙伴 App 使用。"),
        "SSE should contain provider identity answer, got: {text}"
    );
    assert!(
        text.contains("event: answer_completed"),
        "SSE should contain completion event, got: {text}"
    );
    let started = sse_event_data(&text, "message_started");
    let chat_session_id = started["chat_session_id"]
        .as_str()
        .expect("chat session id");

    let row: (String, bool, Option<String>) = sqlx::query_as(
        r"
        SELECT gate_decision, context_loaded, risk_signal
        FROM ai_request_gate_logs
        WHERE session_id = $1
        ORDER BY created_at DESC
        LIMIT 1
        ",
    )
    .bind(uuid::Uuid::parse_str(chat_session_id).expect("parse chat session id"))
    .fetch_one(app.pool())
    .await
    .expect("read latest gate log");

    assert_eq!(row.0, "enter_workbench");
    assert!(!row.1);
    assert_eq!(row.2, None);
}

/// Provider 输出医疗诊断时由回答校验器回退为安全消息
#[tokio::test]
async fn ai_chat_stream_verifies_and_blocks_medical_diagnosis() {
    let server = MockServer::start();
    let mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .body_contains("\"stream\":true");
        then.status(200)
            .header("content-type", "text/event-stream")
            .body(
                "data: {\"choices\":[{\"delta\":{\"content\":\"毛球得了肠胃炎，需要吃阿莫西林。\"}}]}\n\n\
                 data: {\"choices\":[{\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":2,\"completion_tokens\":8,\"total_tokens\":10}}\n\n\
                 data: [DONE]\n\n",
            );
    });

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
        "answer_completed should include blocked verification, got: {text}"
    );
}

/// `off_topic` 请求写入 gate log，且进入主工作台 Provider
#[tokio::test]
async fn ai_chat_stream_off_topic_records_gate_log_and_enters_workbench() {
    let server = MockServer::start();
    let mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions");
        then.status(200)
            .header("content-type", "text/event-stream")
            .body(
                "data: {\"choices\":[{\"delta\":{\"content\":\"我会把重点收回到宠物和毛伙伴 App 相关问题。\"}}]}\n\n\
                 data: {\"choices\":[{\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":5,\"completion_tokens\":8,\"total_tokens\":13}}\n\n\
                 data: [DONE]\n\n",
            );
    });

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

    mock.assert();
    assert!(
        text.contains("我会把重点收回到宠物和毛伙伴 App 相关问题。"),
        "SSE should contain provider workbench response, got: {text}"
    );
    assert!(
        text.contains("event: answer_completed"),
        "SSE should complete through workbench provider, got: {text}"
    );
    let started = sse_event_data(&text, "message_started");
    let chat_session_id = started["chat_session_id"]
        .as_str()
        .expect("chat session id");

    let row: (String, String, bool, Option<String>) = sqlx::query_as(
        r"
        SELECT intent, gate_decision, context_loaded, risk_signal
        FROM ai_request_gate_logs
        WHERE session_id = $1
        ORDER BY created_at DESC
        LIMIT 1
        ",
    )
    .bind(uuid::Uuid::parse_str(chat_session_id).expect("parse chat session id"))
    .fetch_one(app.pool())
    .await
    .expect("read latest gate log");

    assert_eq!(row.0, "off_topic");
    assert_eq!(row.1, "enter_workbench");
    assert!(!row.2);
    assert_eq!(row.3, None);
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

fn uuid_prefix_from_sse(event: &Value, field: &str) -> String {
    event[field]
        .as_str()
        .expect("uuid field")
        .chars()
        .take(8)
        .collect()
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
