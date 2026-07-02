// workbench Provider 工作台进入场景
// 核心职责：
// - 验证助手身份问题进入工作台 Provider
// - 验证 off-topic 请求写入 gate log 并进入 Provider

use axum::http::StatusCode;
use httpmock::MockServer;
use serde_json::json;
use tower::ServiceExt;

use crate::{authorized_json_request, login_and_get_token, response_text};

use super::app::spawn_provider_test_app;
use super::sse::sse_event_data;

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

    let app = spawn_provider_test_app(&server).await;
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

    let app = spawn_provider_test_app(&server).await;
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

    assert_eq!(row.0, "allowed");
    assert_eq!(row.1, "enter_workbench");
    assert!(!row.2);
    assert_eq!(row.3, None);
}
