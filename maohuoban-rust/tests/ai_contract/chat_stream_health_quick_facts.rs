use axum::http::StatusCode;
use chrono::{DateTime, Utc};
use httpmock::{Mock, MockServer, prelude::HttpMockRequest};
use serde_json::json;
use tower::ServiceExt;
use uuid::Uuid;

use super::{
    authorized_json_request, diagnostics_test_lock, json_request, response_json, response_text,
    sse_event_data,
};

struct HealthQuickFactFixture {
    access_token: String,
    actor_user_id: Uuid,
    pet_id: Uuid,
}

struct HealthQuickFactEventIds {
    poop: Uuid,
    energy: Uuid,
    appetite: Uuid,
}

/// AI stream 会通过 Runtime 工具读取近期健康快捷事实后回灌 Provider
#[tokio::test]
async fn ai_chat_stream_loads_recent_health_quick_facts_for_provider_prompt() {
    let _guard = diagnostics_test_lock().lock_owned().await;
    let server = MockServer::start();
    let (first_mock, followup_mock) = install_health_quick_fact_mocks(&server);

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
    let fixture = insert_health_quick_fact_fixture(&app).await;
    let event_ids = insert_health_quick_fact_events(&app, &fixture).await;

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &fixture.access_token,
            json!({
                "message": "梅录今天便便、精神、食欲怎么样？",
                "surface": "home_private",
                "selected_pet_id": fixture.pet_id.to_string()
            }),
        ))
        .await
        .expect("send health quick facts chat stream request");

    let status = response.status();
    let text = response_text(response).await;

    assert_eq!(
        status,
        StatusCode::OK,
        "health quick facts stream failed, body: {text}"
    );

    first_mock.assert();
    followup_mock.assert();
    let started = sse_event_data(&text, "message_started");
    let chat_session_id = started["chat_session_id"]
        .as_str()
        .expect("chat session id");
    assert!(
        text.contains("event: execution_trace_completed")
            && text.contains("正在查看梅录近期健康记录"),
        "SSE should contain health facts execution trace, got: {text}"
    );
    assert_health_quick_fact_citations(&text, &event_ids);
    assert_health_quick_fact_tool_log(&app, chat_session_id, fixture.pet_id, &event_ids).await;
}

fn install_health_quick_fact_mocks(server: &MockServer) -> (Mock<'_>, Mock<'_>) {
    let first_mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .body_contains("\"stream\":true")
            .body_contains("load_pet_recent_health_facts")
            .matches(request_without_tool_result);
        then.status(200)
            .header("content-type", "text/event-stream")
            .body(tool_call_response_body(
                "call_recent_health",
                "load_pet_recent_health_facts",
            ));
    });
    let followup_mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .body_contains("\"stream\":true")
            .body_contains("\"role\":\"tool\"")
            .body_contains("\"tool_call_id\":\"call_recent_health\"")
            .body_contains("便便正常")
            .body_contains("精神不错")
            .body_contains("食欲正常");
        then.status(200)
            .header("content-type", "text/event-stream")
            .body(
                "data: {\"choices\":[{\"delta\":{\"content\":\"今天记录显示便便正常、精神不错、食欲正常。\"}}]}\n\n\
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
    let body = req
        .body
        .as_ref()
        .map(|body| String::from_utf8_lossy(body).into_owned())
        .unwrap_or_default();
    !body.contains("\"role\":\"tool\"")
}

async fn insert_quick_fact_event(
    app: &maohuoban_rust::test_support::AuthTestApp,
    pet_id: Uuid,
    actor_user_id: Uuid,
    title: &str,
    summary: &str,
    quick_fact_kind: &str,
    occurred_at: &str,
) -> Uuid {
    let event_id = Uuid::new_v4();
    let occurred_at = DateTime::parse_from_rfc3339(occurred_at)
        .expect("occurred_at")
        .with_timezone(&Utc);
    sqlx::query(
        r"
        INSERT INTO pet_events (
            id,
            pet_id,
            event_kind,
            event_subkind,
            title,
            summary,
            visibility,
            event_payload,
            occurred_at,
            actor_user_id,
            record_revision
        )
        VALUES ($1, $2, 'daily', 'quick_fact', $3, $4, 'private', $5, $6, $7, 1)
        ",
    )
    .bind(event_id)
    .bind(pet_id)
    .bind(title)
    .bind(summary)
    .bind(json!({
        "quick_fact_kind": quick_fact_kind,
        "quick_fact_submission_id": Uuid::new_v4().to_string()
    }))
    .bind(occurred_at)
    .bind(actor_user_id)
    .execute(app.pool())
    .await
    .expect("insert quick fact pet event");
    event_id
}

async fn insert_user_identity(
    app: &maohuoban_rust::test_support::AuthTestApp,
    user_id: Uuid,
    phone: &str,
) {
    sqlx::query(
        r"
        INSERT INTO users (id, status)
        VALUES ($1, 'active')
        ",
    )
    .bind(user_id)
    .execute(app.pool())
    .await
    .expect("insert user");

    sqlx::query(
        r"
        INSERT INTO user_identities (id, user_id, provider, identifier, verified_at)
        VALUES ($1, $2, 'phone', $3, now())
        ",
    )
    .bind(Uuid::new_v4())
    .bind(user_id)
    .bind(phone)
    .execute(app.pool())
    .await
    .expect("insert phone identity");
}

async fn insert_pet_profile_with_owner(
    app: &maohuoban_rust::test_support::AuthTestApp,
    pet_id: Uuid,
    owner_user_id: Uuid,
    name: &str,
) {
    sqlx::query(
        r"
        INSERT INTO pet_profiles (
            id,
            owner_user_id,
            name,
            species,
            breed,
            sex,
            birthday,
            managed_status,
            source_kind,
            profile_number,
            arrival_date,
            neuter_status,
            personality_tags,
            note,
            origin_kind
        )
        VALUES (
            $1,
            $2,
            $3,
            'cat',
            '英短',
            'male',
            DATE '2024-01-01',
            'family',
            'user_created',
            '9000000000000001',
            DATE '2024-03-01',
            'unknown',
            '[]'::jsonb,
            NULL,
            'user_created'
        )
        ",
    )
    .bind(pet_id)
    .bind(owner_user_id)
    .bind(name)
    .execute(app.pool())
    .await
    .expect("insert pet profile");

    sqlx::query(
        r"
        INSERT INTO pet_guardians (
            id,
            pet_id,
            guardian_type,
            guardian_user_id,
            role,
            status,
            started_at,
            granted_by_user_id
        )
        VALUES ($1, $2, 'user', $3, 'owner', 'active', now(), $3)
        ",
    )
    .bind(Uuid::new_v4())
    .bind(pet_id)
    .bind(owner_user_id)
    .execute(app.pool())
    .await
    .expect("insert owner guardian");
}

async fn login_and_get_token(
    app: &maohuoban_rust::test_support::AuthTestApp,
    phone: &str,
    device_id: &str,
) -> String {
    let response = app
        .router()
        .clone()
        .oneshot(json_request(
            "POST",
            "/api/v1/auth/phone/code",
            json!({
                "phone": phone,
                "agreement_accepted": true,
                "device": {
                    "device_id": device_id,
                    "device_name": "iPhone 17 Pro",
                    "platform": "iOS",
                    "app_version": "1.0"
                }
            }),
        ))
        .await
        .expect("send phone code");
    let status = response.status();
    let body = response_json(response).await;
    assert_eq!(status, StatusCode::OK, "send phone code failed: {body}");
    let challenge_id = body["data"]["challenge_id"]
        .as_str()
        .expect("challenge id")
        .to_owned();

    let response = app
        .router()
        .clone()
        .oneshot(json_request(
            "POST",
            "/api/v1/auth/phone/verify",
            json!({
                "challenge_id": challenge_id,
                "code": "123456",
                "device": {
                    "device_id": device_id,
                    "device_name": "iPhone 17 Pro",
                    "platform": "iOS",
                    "app_version": "1.0"
                }
            }),
        ))
        .await
        .expect("verify phone code");
    let status = response.status();
    let body = response_json(response).await;
    assert_eq!(status, StatusCode::OK, "verify phone code failed: {body}");
    body["data"]["access_token"]
        .as_str()
        .expect("access token")
        .to_owned()
}

async fn insert_health_quick_fact_fixture(
    app: &maohuoban_rust::test_support::AuthTestApp,
) -> HealthQuickFactFixture {
    let phone = "13800139041";
    let actor_user_id = Uuid::new_v4();
    let pet_id = Uuid::new_v4();
    insert_user_identity(app, actor_user_id, phone).await;
    insert_pet_profile_with_owner(app, pet_id, actor_user_id, "梅录").await;
    let access_token = login_and_get_token(app, phone, "ios-ai-health-quick-facts").await;
    HealthQuickFactFixture {
        access_token,
        actor_user_id,
        pet_id,
    }
}

async fn insert_health_quick_fact_events(
    app: &maohuoban_rust::test_support::AuthTestApp,
    fixture: &HealthQuickFactFixture,
) -> HealthQuickFactEventIds {
    let poop = insert_quick_fact_event(
        app,
        fixture.pet_id,
        fixture.actor_user_id,
        "便便正常",
        "粪便状态：健康成型",
        "poop_normal",
        "2026-07-05T08:10:00Z",
    )
    .await;
    let energy = insert_quick_fact_event(
        app,
        fixture.pet_id,
        fixture.actor_user_id,
        "精神不错",
        "精神与活力：正常平稳",
        "energy_normal",
        "2026-07-05T08:12:00Z",
    )
    .await;
    let appetite = insert_quick_fact_event(
        app,
        fixture.pet_id,
        fixture.actor_user_id,
        "食欲正常",
        "今天食欲正常",
        "appetite_normal",
        "2026-07-05T08:14:00Z",
    )
    .await;
    HealthQuickFactEventIds {
        poop,
        energy,
        appetite,
    }
}

fn assert_health_quick_fact_citations(text: &str, event_ids: &HealthQuickFactEventIds) {
    assert!(
        text.contains("event: citation")
            && text.contains(&event_ids.poop.to_string())
            && text.contains(&event_ids.energy.to_string())
            && text.contains(&event_ids.appetite.to_string()),
        "SSE should contain quick fact citation events, got: {text}"
    );
}

async fn assert_health_quick_fact_tool_log(
    app: &maohuoban_rust::test_support::AuthTestApp,
    chat_session_id: &str,
    pet_id: Uuid,
    event_ids: &HealthQuickFactEventIds,
) {
    let tool_log: (String, bool, Option<Uuid>, serde_json::Value) = sqlx::query_as(
        r"
        SELECT requested_scope, allowed, target_pet_id, returned_ref_ids
        FROM ai_tool_access_logs
        WHERE tool_name = 'load_pet_recent_health_facts'
          AND session_id = $1
        ORDER BY created_at DESC
        LIMIT 1
        ",
    )
    .bind(Uuid::parse_str(chat_session_id).expect("parse chat session id"))
    .fetch_one(app.pool())
    .await
    .expect("read latest health quick facts tool access log");

    assert_eq!(tool_log.0, "pet_recent_health_facts");
    assert!(tool_log.1);
    assert_eq!(tool_log.2, Some(pet_id));
    let returned_ref_ids = tool_log.3.as_array().expect("returned ref ids");
    assert!(returned_ref_ids.contains(&json!(event_ids.poop.to_string())));
    assert!(returned_ref_ids.contains(&json!(event_ids.energy.to_string())));
    assert!(returned_ref_ids.contains(&json!(event_ids.appetite.to_string())));
}
