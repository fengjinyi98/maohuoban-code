// provider Provider 成功链路场景
// 核心职责：
// - 验证配置 OpenAI 兼容 Provider 后的 stream 主链路
// - 验证工作台 memory、工具目录和诊断事件进入 Provider 请求

use axum::http::StatusCode;
use httpmock::MockServer;
use serde_json::json;
use tower::ServiceExt;

use crate::{authorized_json_request, diagnostics_test_lock, login_and_get_token, response_text};

use super::app::{
    create_pet, insert_user_memory, load_actor_user_id_by_phone, spawn_provider_test_app,
};
use super::diagnostics::{assert_provider_diagnostics, install_provider_test_diagnostics};
use super::sse::{assert_provider_stream_response, sse_event_data, uuid_prefix_from_sse};

/// 配置 `OpenAI` 兼容 Provider 后 `/api/v1/ai/chat/stream` 返回真实 Provider delta
#[tokio::test]
async fn ai_chat_stream_uses_configured_openai_provider() {
    let _guard = diagnostics_test_lock().lock_owned().await;
    let server = MockServer::start();
    let mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .body_contains("\"stream\":true")
            .body_contains("只能基于提供的事实包")
            .body_contains("已选宠物: 毛球")
            .body_contains("\"tools\"")
            .body_contains("load_pet_identity_context")
            .body_contains("用户喜欢直接给可执行建议");
        then.status(200)
            .header("content-type", "text/event-stream")
            .body(
                "data: {\"choices\":[{\"delta\":{\"content\":\"真实 Provider\"}}]}\n\n\
                 data: {\"choices\":[{\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":2,\"completion_tokens\":3,\"total_tokens\":5}}\n\n\
                 data: [DONE]\n\n",
            );
    });

    let app = spawn_provider_test_app(&server).await;
    let diagnostics = install_provider_test_diagnostics();
    app.reset().await;
    let phone = "13800139009";
    let access_token = login_and_get_token(&app, phone, "ios-ai-provider-config").await;
    let actor_user_id = load_actor_user_id_by_phone(&app, phone).await;
    insert_user_memory(&app, actor_user_id, "用户喜欢直接给可执行建议").await;
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
    assert_provider_stream_response(&text);
    let started = sse_event_data(&text, "message_started");
    let chat_session_id_prefix = uuid_prefix_from_sse(&started, "chat_session_id");
    let message_id_prefix = uuid_prefix_from_sse(&started, "message_id");
    diagnostics.flush().expect("flush diagnostics");
    let events = diagnostics.read_events().expect("diagnostics events");
    assert_provider_diagnostics(
        &events,
        &chat_session_id_prefix,
        &message_id_prefix,
        "毛球今天怎么样",
    );
    assert_no_identity_tool_log_without_tool_call(&app, pet_id).await;
}

async fn assert_no_identity_tool_log_without_tool_call(
    app: &maohuoban_rust::test_support::AuthTestApp,
    pet_id: &str,
) {
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

    assert_eq!(identity_log_count, 0);
}
