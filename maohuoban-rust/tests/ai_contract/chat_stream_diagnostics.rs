use axum::http::StatusCode;
use maohuoban_diagnostics::{
    CapturePolicy, CleanupPolicy, Diagnostics, DiagnosticsConfig, EventKind, FileSegmentStore,
    PrivacyPolicy,
};
use serde_json::json;
use tower::ServiceExt;

use super::{authorized_json_request, diagnostics_test_lock, login_and_get_token, response_text};

/// 流式聊天诊断事件允许开发期正文观测，但不能泄露认证敏感字段
#[tokio::test]
async fn ai_chat_stream_diagnostics_do_not_leak_sensitive_text() {
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
    let forbidden_fields = [
        "contract-api-key",
        "api_key",
        "authorization",
        "Bearer",
        "Cookie",
    ];

    let ai_events: Vec<_> = events
        .iter()
        .filter(|event| event.message.starts_with("ai.chat."))
        .collect();
    assert!(!ai_events.is_empty(), "missing ai.chat diagnostics events");

    for event in &ai_events {
        let metadata = serde_json::to_string(&event.metadata).expect("serialize metadata");
        assert!(
            !forbidden_fields
                .iter()
                .any(|needle| { event.message.contains(needle) || metadata.contains(needle) }),
            "diagnostics leaked sensitive text in event: {event:?}"
        );
    }

    assert!(events.iter().any(|event| {
        event.kind == EventKind::Analytics
            && event.message == "ai.chat.stream.request.received"
            && event.metadata["surface"] == json!("home_private")
            && event.metadata["message_length_bucket"] == json!("1_32")
            && event.metadata["message"] == json!("毛球今天拉肚子了怎么办")
            && event.metadata["chat_session_id_prefix"].is_string()
            && event.metadata["message_id_prefix"].is_string()
    }));

    let finalizer_event = events
        .iter()
        .find(|event| event.message == "ai.chat.finalizer.completed")
        .expect("missing ai.chat.finalizer.completed diagnostics event");
    assert!(
        finalizer_event.metadata["terminal_status"]
            .as_str()
            .is_some_and(|status| !status.is_empty()),
        "finalizer diagnostics missing terminal_status"
    );
    assert!(
        finalizer_event.metadata["synchronous_writes"].is_array(),
        "finalizer diagnostics missing synchronous_writes"
    );
    assert!(
        finalizer_event.metadata["async_triggers"].is_array(),
        "finalizer diagnostics missing async_triggers"
    );
    assert!(
        finalizer_event.metadata["async_failures"].is_array(),
        "finalizer diagnostics missing async_failures"
    );
}

/// 流式聊天诊断事件必须记录 gate 决策的四个必备字段
#[tokio::test]
async fn ai_chat_stream_diagnostics_records_gate_decision_fields() {
    let _guard = diagnostics_test_lock().lock_owned().await;
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    let diagnostics = install_ai_test_diagnostics();
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139029", "ios-ai-gate-diag").await;
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
                "message": "毛球今天吃什么好",
                "surface": "home_private",
                "selected_pet_id": pet_id
            }),
        ))
        .await
        .expect("send gate diagnostics chat stream request");

    assert_eq!(response.status(), StatusCode::OK);
    let _ = response_text(response).await;
    diagnostics.flush().expect("flush diagnostics");

    let events = diagnostics.read_events().expect("diagnostics events");
    let gate_event = events
        .iter()
        .find(|event| event.message == "ai.chat.gate.decided")
        .expect("missing ai.chat.gate.decided diagnostics event");

    // 验证 gate 诊断事件必备字段存在且非空
    assert!(
        gate_event.metadata["intent"]
            .as_str()
            .is_some_and(|v| !v.is_empty()),
        "gate diagnostics missing intent field"
    );
    assert!(
        gate_event.metadata["gate_decision"]
            .as_str()
            .is_some_and(|v| !v.is_empty()),
        "gate diagnostics missing gate_decision field"
    );
    assert!(
        gate_event.metadata["context_loaded"].is_boolean(),
        "gate diagnostics missing context_loaded bool field"
    );
    assert!(
        gate_event.metadata["risk_signal_present"].is_boolean(),
        "gate diagnostics missing risk_signal_present bool field"
    );
    assert!(
        gate_event.metadata["allow_processing"].is_boolean(),
        "gate diagnostics missing allow_processing bool field"
    );
}

/// 流式聊天诊断事件必须记录 planning 决策字段
#[tokio::test]
async fn ai_chat_stream_diagnostics_records_planning_decision_fields() {
    let _guard = diagnostics_test_lock().lock_owned().await;
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    let diagnostics = install_ai_test_diagnostics();
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139049", "ios-ai-planning-diag").await;
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
        .expect("send planning diagnostics chat stream request");

    assert_eq!(response.status(), StatusCode::OK);
    let _ = response_text(response).await;
    diagnostics.flush().expect("flush diagnostics");

    let events = diagnostics.read_events().expect("diagnostics events");
    let planning_event = events
        .iter()
        .find(|event| event.message == "ai.chat.planning.decided")
        .expect("missing ai.chat.planning.decided diagnostics event");

    let required_fields = [
        "session_id",
        "turn_id",
        "message_id",
        "task_type",
        "step_list",
        "current_step",
        "step_transition",
        "replan_reason",
        "terminal_step",
        "policy_decision",
    ];
    for field in &required_fields {
        assert!(
            !planning_event.metadata[*field].is_null(),
            "planning diagnostics missing required field: {field}"
        );
    }
    assert!(
        planning_event.metadata["step_list"]
            .as_array()
            .is_some_and(|steps| !steps.is_empty()),
        "planning diagnostics step_list must be a non-empty array"
    );
    assert!(
        planning_event.metadata["task_type"]
            .as_str()
            .is_some_and(|value| !value.is_empty()),
        "planning diagnostics task_type must be present"
    );
    assert!(
        planning_event.metadata["policy_decision"]
            .as_str()
            .is_some_and(|value| !value.is_empty()),
        "planning diagnostics policy_decision must be present"
    );
}

/// gate 诊断事件四个必备字段即使在不加载上下文的请求中也存在
#[tokio::test]
async fn ai_chat_stream_diagnostics_gate_fields_present_for_all_intents() {
    let _guard = diagnostics_test_lock().lock_owned().await;
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    let diagnostics = install_ai_test_diagnostics();
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139039", "ios-ai-gate-fields").await;

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &access_token,
            json!({
                "message": "给我推荐一部好看的电影",
                "surface": "home_private"
            }),
        ))
        .await
        .expect("send gate fields diagnostics chat stream request");

    assert_eq!(response.status(), StatusCode::OK);
    let _ = response_text(response).await;
    diagnostics.flush().expect("flush diagnostics");

    let events = diagnostics.read_events().expect("diagnostics events");
    let gate_event = events
        .iter()
        .find(|event| event.message == "ai.chat.gate.decided")
        .expect("missing ai.chat.gate.decided diagnostics event");

    // 验证必备诊断字段始终存在
    let required_fields = [
        "intent",
        "gate_decision",
        "context_loaded",
        "risk_signal_present",
        "allow_processing",
    ];
    for field in &required_fields {
        assert!(
            !gate_event.metadata[*field].is_null(),
            "gate diagnostics missing required field: {field}"
        );
    }
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

async fn create_pet(
    app: &maohuoban_rust::test_support::AuthTestApp,
    access_token: &str,
    name: &str,
) -> serde_json::Value {
    let response = app
        .router()
        .clone()
        .oneshot(super::authorized_json_request(
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
    super::response_json(response).await["data"].clone()
}
