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
    let forbidden_fields = ["contract-api-key", "api_key", "authorization", "Bearer"];

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
    }));
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
