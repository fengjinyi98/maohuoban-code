use axum::http::StatusCode;
use httpmock::{Mock, MockServer, prelude::HttpMockRequest};
use serde_json::json;
use tower::ServiceExt;
use uuid::Uuid;

use super::{
    authorized_json_request, diagnostics_test_lock, login_and_get_token, response_json,
    response_text, sse_event_data,
};

struct AbnormalEpisodeFixture {
    access_token: String,
    pet_id: Uuid,
    episode_id: Uuid,
    initial_event_id: Uuid,
    followup_event_id: Uuid,
    recovery_event_id: Uuid,
}

/// AI stream 会通过 Runtime 工具读取异常 episode 事实且不混入 quick facts
#[tokio::test]
async fn ai_chat_stream_loads_abnormal_episode_facts_without_quick_fact_payload() {
    let _guard = diagnostics_test_lock().lock_owned().await;
    let server = MockServer::start();
    let (first_mock, followup_mock) = install_abnormal_episode_fact_mocks(&server);

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
    let fixture = create_abnormal_episode_fixture(&app).await;

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &fixture.access_token,
            json!({
                "message": "团团这个异常现在追踪到哪一步了？",
                "surface": "home_private",
                "selected_pet_id": fixture.pet_id.to_string()
            }),
        ))
        .await
        .expect("send abnormal episode facts chat stream request");

    let status = response.status();
    let text = response_text(response).await;

    assert_eq!(
        status,
        StatusCode::OK,
        "abnormal episode facts stream failed, body: {text}"
    );

    first_mock.assert();
    followup_mock.assert();
    let started = sse_event_data(&text, "message_started");
    let chat_session_id = started["chat_session_id"]
        .as_str()
        .expect("chat session id");
    assert!(
        text.contains("event: execution_trace_completed") && text.contains("正在查看团团异常追踪"),
        "SSE should contain abnormal episode execution trace, got: {text}"
    );
    assert_abnormal_episode_citations(&text, &fixture);
    assert_abnormal_episode_tool_log(&app, chat_session_id, &fixture).await;
}

fn install_abnormal_episode_fact_mocks(server: &MockServer) -> (Mock<'_>, Mock<'_>) {
    let first_mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .body_contains("\"stream\":true")
            .body_contains("load_pet_abnormal_episode_facts")
            .matches(request_without_tool_result);
        then.status(200)
            .header("content-type", "text/event-stream")
            .body(tool_call_response_body(
                "call_abnormal_episode",
                "load_pet_abnormal_episode_facts",
            ));
    });
    let followup_mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .body_contains("\"stream\":true")
            .body_contains("\"role\":\"tool\"")
            .body_contains("\"tool_call_id\":\"call_abnormal_episode\"")
            .body_contains("status=recovered")
            .body_contains("attachment_count=0")
            .body_contains("latest_observed_at=")
            .body_contains("追加观察")
            .body_contains("标记恢复")
            .matches(|req| {
                let tool_content = request_tool_content(req);
                !tool_content.contains("health.recent_quick_fact")
                    && !tool_content.contains("便便正常")
                    && !tool_content.contains("精神不错")
                    && !tool_content.contains("食欲正常")
            });
        then.status(200)
            .header("content-type", "text/event-stream")
            .body(
                "data: {\"choices\":[{\"delta\":{\"content\":\"异常追踪已包含父记录、追加观察和恢复记录。\"}}]}\n\n\
                 data: {\"choices\":[{\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":4,\"completion_tokens\":8,\"total_tokens\":12}}\n\n\
                 data: [DONE]\n\n",
            );
    });
    (first_mock, followup_mock)
}

fn tool_call_response_body(tool_call_id: &str, tool_name: &str) -> String {
    format!(
        "data: {{\"choices\":[{{\"delta\":{{\"tool_calls\":[{{\"id\":{tool_call_id:?},\"function\":{{\"name\":{tool_name:?},\"arguments\":\"{{}}\"}}}}]}}}}]}}\n\n\
         data: {{\"choices\":[{{\"finish_reason\":\"tool_calls\"}}],\"usage\":{{\"prompt_tokens\":8,\"completion_tokens\":2,\"total_tokens\":10}}}}\n\n\
         data: [DONE]\n\n"
    )
}

fn request_without_tool_result(req: &HttpMockRequest) -> bool {
    let body = request_body(req);
    !body.contains("\"role\":\"tool\"")
}

fn request_body(req: &HttpMockRequest) -> String {
    req.body
        .as_ref()
        .map(|body| String::from_utf8_lossy(body).into_owned())
        .unwrap_or_default()
}

fn request_tool_content(req: &HttpMockRequest) -> String {
    let body = request_body(req);
    let Ok(value) = serde_json::from_str::<serde_json::Value>(&body) else {
        return String::new();
    };
    value["messages"]
        .as_array()
        .into_iter()
        .flatten()
        .filter(|message| message["role"].as_str() == Some("tool"))
        .filter_map(|message| message["content"].as_str())
        .collect::<Vec<_>>()
        .join("\n")
}

async fn create_abnormal_episode_fixture(
    app: &maohuoban_rust::test_support::AuthTestApp,
) -> AbnormalEpisodeFixture {
    let access_token = login_and_get_token(app, "13800139066", "ios-ai-abnormal-episode").await;
    let pet_id = create_pet(app, &access_token).await;
    let (episode_id, initial_event_id) = create_abnormal_event(app, &access_token, pet_id).await;
    let followup_event_id = create_followup_event(app, &access_token, pet_id, episode_id).await;
    let recovery_event_id = create_recovery_event(app, &access_token, pet_id, episode_id).await;

    AbnormalEpisodeFixture {
        access_token,
        pet_id,
        episode_id,
        initial_event_id,
        followup_event_id,
        recovery_event_id,
    }
}

async fn create_pet(app: &maohuoban_rust::test_support::AuthTestApp, access_token: &str) -> Uuid {
    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/pets",
            access_token,
            json!({
                "name": "团团",
                "species": "cat",
                "breed": "英短",
                "sex": "male",
                "birthday": "2025-01-01"
            }),
        ))
        .await
        .expect("create pet");
    assert_eq!(response.status(), StatusCode::CREATED);
    let body = response_json(response).await;
    Uuid::parse_str(body["data"]["id"].as_str().expect("pet id")).expect("parse pet id")
}

async fn create_abnormal_event(
    app: &maohuoban_rust::test_support::AuthTestApp,
    access_token: &str,
    pet_id: Uuid,
) -> (Uuid, Uuid) {
    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/events"),
            access_token,
            json!({
                "event_kind": "health",
                "event_subkind": "abnormal_symptom",
                "title": "异常：精神差",
                "summary": "今天明显没有精神",
                "visibility": "private",
                "occurred_at": "2026-07-03T09:00:00Z",
                "event_payload": {
                    "symptom_kinds": ["energy"],
                    "severity": "obvious"
                }
            }),
        ))
        .await
        .expect("create abnormal event");
    assert_eq!(response.status(), StatusCode::CREATED);
    let body = response_json(response).await;
    let event_id =
        Uuid::parse_str(body["data"]["id"].as_str().expect("event id")).expect("parse event id");
    let episode_id = Uuid::parse_str(
        body["data"]["event_payload"]["episode_id"]
            .as_str()
            .expect("episode id"),
    )
    .expect("parse episode id");
    (episode_id, event_id)
}

async fn create_followup_event(
    app: &maohuoban_rust::test_support::AuthTestApp,
    access_token: &str,
    pet_id: Uuid,
    episode_id: Uuid,
) -> Uuid {
    create_episode_event(
        app,
        access_token,
        pet_id,
        "symptom_followup",
        "追加观察",
        "精神一般，愿意走动",
        "2026-07-03T13:30:00Z",
        json!({
            "episode_id": episode_id.to_string(),
            "note": "精神一般，愿意走动"
        }),
    )
    .await
}

async fn create_recovery_event(
    app: &maohuoban_rust::test_support::AuthTestApp,
    access_token: &str,
    pet_id: Uuid,
    episode_id: Uuid,
) -> Uuid {
    create_episode_event(
        app,
        access_token,
        pet_id,
        "abnormal_recovery",
        "标记恢复",
        "精神恢复到平时状态",
        "2026-07-03T18:20:00Z",
        json!({
            "episode_id": episode_id.to_string(),
            "recovery_note": "精神恢复到平时状态"
        }),
    )
    .await
}

async fn create_episode_event(
    app: &maohuoban_rust::test_support::AuthTestApp,
    access_token: &str,
    pet_id: Uuid,
    subkind: &str,
    title: &str,
    summary: &str,
    occurred_at: &str,
    payload: serde_json::Value,
) -> Uuid {
    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/events"),
            access_token,
            json!({
                "event_kind": "health",
                "event_subkind": subkind,
                "title": title,
                "summary": summary,
                "visibility": "private",
                "occurred_at": occurred_at,
                "event_payload": payload
            }),
        ))
        .await
        .expect("create episode event");
    assert_eq!(response.status(), StatusCode::CREATED);
    let body = response_json(response).await;
    Uuid::parse_str(body["data"]["id"].as_str().expect("event id")).expect("parse event id")
}

fn assert_abnormal_episode_citations(text: &str, fixture: &AbnormalEpisodeFixture) {
    assert!(
        text.contains("event: citation")
            && text.contains(&fixture.initial_event_id.to_string())
            && text.contains(&fixture.followup_event_id.to_string()),
        "SSE should contain abnormal episode citation events, got: {text}"
    );
}

async fn assert_abnormal_episode_tool_log(
    app: &maohuoban_rust::test_support::AuthTestApp,
    chat_session_id: &str,
    fixture: &AbnormalEpisodeFixture,
) {
    let tool_log: (String, bool, Option<Uuid>, serde_json::Value) = sqlx::query_as(
        r"
        SELECT requested_scope, allowed, target_pet_id, returned_ref_ids
        FROM ai_tool_access_logs
        WHERE tool_name = 'load_pet_abnormal_episode_facts'
          AND session_id = $1
        ORDER BY created_at DESC
        LIMIT 1
        ",
    )
    .bind(Uuid::parse_str(chat_session_id).expect("parse chat session id"))
    .fetch_one(app.pool())
    .await
    .expect("read latest abnormal episode tool access log");

    assert_eq!(tool_log.0, "pet_abnormal_episode");
    assert!(tool_log.1);
    assert_eq!(tool_log.2, Some(fixture.pet_id));
    let returned_ref_ids = tool_log.3.as_array().expect("returned ref ids");
    assert!(returned_ref_ids.contains(&json!(fixture.episode_id.to_string())));
    assert!(returned_ref_ids.contains(&json!(fixture.initial_event_id.to_string())));
    assert!(returned_ref_ids.contains(&json!(fixture.followup_event_id.to_string())));
    assert!(returned_ref_ids.contains(&json!(fixture.recovery_event_id.to_string())));
}
