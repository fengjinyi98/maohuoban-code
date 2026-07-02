// chat_stream AI 流式聊天基础合同测试
// 核心职责：
// - 验证认证、基础 SSE、诊断事件和目标宠物解析合同
// - 保留 stream 主链路的最小入口级回归

use axum::http::StatusCode;
use maohuoban_diagnostics::{
    CapturePolicy, CleanupPolicy, Diagnostics, DiagnosticsConfig, EventKind, FileSegmentStore,
    PrivacyPolicy,
};
use serde_json::{Value, json};
use tower::ServiceExt;

use super::{
    authorized_json_request, diagnostics_test_lock, json_request, login_and_get_token,
    response_json, response_text,
};

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
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    let diagnostics = install_ai_test_diagnostics();
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
            && event.metadata["message"] == json!("毛球今天拉肚子了怎么办")
    }));
    assert!(events.iter().any(|event| {
        event.message == "ai.chat.gate.decided"
            && event.metadata["gate_decision"] == json!("enter_workbench")
            && event.metadata["context_loaded"] == json!(false)
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
            && event.metadata["engine_mode"] == json!("self_hosted")
            && event.metadata["retryable"] == json!(false)
    }));
    assert!(events.iter().any(|event| {
        event.message == "ai.runtime.model.request.prepared"
            && event.metadata["message_contents"]
                .as_array()
                .is_some_and(|contents| {
                    contents
                        .iter()
                        .any(|value| value == "毛球今天拉肚子了怎么办")
                })
    }));
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
        text.contains("event: execution_trace_completed") && text.contains("正在确认宠物档案权限"),
        "SSE should contain authorized pet catalog execution trace, got: {text}"
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
    assert!(!row.2);

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

/// 历史会话续聊会从 session 恢复目标宠物
/// 核心职责：
/// - 验证第二轮请求只传 `chat_session_id` 时仍能恢复 `primary_pet_id`
/// - 防止历史会话继续对话时回退到未选择宠物边界响应
#[tokio::test]
async fn ai_chat_stream_restores_selected_pet_from_existing_session() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139021", "ios-ai-session-pet").await;

    let pet = create_pet(&app, &access_token, "毛球").await;
    let pet_id = pet["id"].as_str().expect("pet id");

    let first_response = app
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
        .expect("send first selected pet chat stream request");

    assert_eq!(first_response.status(), StatusCode::OK);
    let first_text = response_text(first_response).await;
    let first_started = sse_event_data(&first_text, "message_started");
    let chat_session_id = first_started["chat_session_id"]
        .as_str()
        .expect("chat session id");

    let second_response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &access_token,
            json!({
                "message": "今天拉肚子还没好怎么办",
                "surface": "home_private",
                "chat_session_id": chat_session_id
            }),
        ))
        .await
        .expect("send follow-up chat stream request");

    assert_eq!(second_response.status(), StatusCode::OK);
    let second_text = response_text(second_response).await;
    let second_started = sse_event_data(&second_text, "message_started");

    assert_eq!(second_started["target_pet"]["pet_id"], pet_id);
    assert!(
        !second_text.contains("需要先选择宠物"),
        "follow-up should restore session pet instead of asking for selection, got: {second_text}"
    );

    let row: (Option<uuid::Uuid>, Option<uuid::Uuid>, bool) = sqlx::query_as(
        r"
        SELECT selected_pet_id, resolved_pet_id, context_loaded
        FROM ai_request_gate_logs
        WHERE session_id = $1
        ORDER BY created_at DESC
        LIMIT 1
        ",
    )
    .bind(uuid::Uuid::parse_str(chat_session_id).expect("parse session id"))
    .fetch_one(app.pool())
    .await
    .expect("read latest follow-up gate log");

    let pet_uuid = uuid::Uuid::parse_str(pet_id).expect("parse pet id");
    assert_eq!(row.0, Some(pet_uuid));
    assert_eq!(row.1, Some(pet_uuid));
    assert!(!row.2);
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
