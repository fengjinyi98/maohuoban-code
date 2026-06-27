use axum::http::StatusCode;
use httpmock::MockServer;
use serde_json::json;
use tower::ServiceExt;

use super::{
    authorized_json_request, json_request, login_and_get_token, response_json, response_text,
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
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139001", "ios-ai-stream-test").await;

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &access_token,
            json!({
                "message": "毛球今天怎么样",
                "surface": "home_private"
            }),
        ))
        .await
        .expect("send chat stream request");

    assert_eq!(response.status(), StatusCode::OK);
    let text = response_text(response).await;

    // SSE 应包含 message_started 事件
    assert!(
        text.contains("event: message_started"),
        "SSE should contain message_started event, got: {text}"
    );

    // DisabledLlmProvider 触发 error 事件
    assert!(
        text.contains("event: error"),
        "SSE should contain error event for disabled provider, got: {text}"
    );
}

/// 已登录访问 /api/v1/ai/chat 返回 `provider_not_configured`
#[tokio::test]
async fn ai_chat_non_stream_returns_provider_not_configured() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139002", "ios-ai-chat-test").await;

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat",
            &access_token,
            json!({
                "message": "毛球今天怎么样",
                "surface": "home_private"
            }),
        ))
        .await
        .expect("send chat request");

    assert_eq!(response.status(), StatusCode::SERVICE_UNAVAILABLE);
    let body = response_json(response).await;
    assert_eq!(body["success"], false);
    assert_eq!(body["code"], "ai.provider_not_configured");
}

/// 配置 `OpenAI` 兼容 Provider 后 `/api/v1/ai/chat/stream` 返回真实 Provider delta
#[tokio::test]
async fn ai_chat_stream_uses_configured_openai_provider() {
    let server = MockServer::start();
    let mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key");
        then.status(200)
            .header("content-type", "text/event-stream")
            .body(
                "data: {\"choices\":[{\"delta\":{\"content\":\"真实\"}}]}\n\n\
                 data: {\"choices\":[{\"delta\":{\"content\":\" Provider\"}}]}\n\n\
                 data: {\"choices\":[{\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":2,\"completion_tokens\":3,\"total_tokens\":5}}\n\n\
                 data: [DONE]\n\n",
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

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &access_token,
            json!({
                "message": "毛球今天怎么样",
                "surface": "home_private"
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
