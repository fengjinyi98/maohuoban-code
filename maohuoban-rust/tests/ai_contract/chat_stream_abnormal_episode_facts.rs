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

#[tokio::test]
async fn ai_chat_stream_persists_abnormal_followup_entry_context() {
    let _guard = diagnostics_test_lock().lock_owned().await;
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let fixture = create_abnormal_episode_fixture(&app).await;
    let source_hint_id = Uuid::new_v4();
    let agent_followup_id = Uuid::new_v4();

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &fixture.access_token,
            json!({
                "message": "毛球刚才提醒我更新异常，现在该看什么？",
                "surface": "home_private",
                "selected_pet_id": fixture.pet_id.to_string(),
                "chat_context_kind": "abnormal_episode_followup",
                "abnormal_episode_id": fixture.episode_id.to_string(),
                "source_hint_id": source_hint_id.to_string(),
                "agent_followup_id": agent_followup_id.to_string()
            }),
        ))
        .await
        .expect("send abnormal followup entry chat request");

    assert_eq!(response.status(), StatusCode::OK);
    let text = response_text(response).await;
    let started = sse_event_data(&text, "message_started");
    let chat_session_id = started["chat_session_id"]
        .as_str()
        .expect("chat session id");

    let persisted: (Option<String>, Option<Uuid>, Option<Uuid>, Option<Uuid>) = sqlx::query_as(
        r"
        SELECT chat_context_kind, abnormal_episode_id, source_hint_id, agent_followup_id
        FROM ai_chat_sessions
        WHERE id = $1::uuid
        ",
    )
    .bind(chat_session_id.parse::<Uuid>().expect("chat session uuid"))
    .fetch_one(app.pool())
    .await
    .expect("load persisted ai chat session");

    assert_eq!(persisted.0.as_deref(), Some("abnormal_episode_followup"));
    assert_eq!(persisted.1, Some(fixture.episode_id));
    assert_eq!(persisted.2, Some(source_hint_id));
    assert_eq!(persisted.3, Some(agent_followup_id));
}

#[tokio::test]
async fn abnormal_followup_entry_reuses_same_agent_session_and_context() {
    let _guard = diagnostics_test_lock().lock_owned().await;
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let fixture = create_abnormal_episode_fixture(&app).await;
    let source_hint_id = Uuid::new_v4();
    let first_followup_id = Uuid::new_v4();
    let second_followup_id = Uuid::new_v4();

    let first_session_id = send_abnormal_followup_entry_request(
        &app,
        &fixture,
        source_hint_id,
        first_followup_id,
        "毛球提醒我更新异常，先看看现在追踪到哪了？",
    )
    .await;

    let second_session_id = send_abnormal_followup_entry_request(
        &app,
        &fixture,
        source_hint_id,
        second_followup_id,
        "这是第二次提醒，我继续补充情况。",
    )
    .await;

    assert_eq!(
        second_session_id, first_session_id,
        "same abnormal episode followup should reuse one agent session"
    );

    let persisted: (
        Option<String>,
        Option<Uuid>,
        Option<Uuid>,
        Option<Uuid>,
        i64,
    ) = sqlx::query_as(
        r"
            SELECT s.chat_context_kind,
                   s.abnormal_episode_id,
                   s.source_hint_id,
                   s.agent_followup_id,
                   COUNT(t.id) AS turn_count
            FROM ai_chat_sessions s
            LEFT JOIN ai_session_turns t ON t.session_id = s.id
            WHERE s.id = $1::uuid
            GROUP BY s.id
            ",
    )
    .bind(first_session_id)
    .fetch_one(app.pool())
    .await
    .expect("load reused session and turns");

    assert_eq!(persisted.0.as_deref(), Some("abnormal_episode_followup"));
    assert_eq!(persisted.1, Some(fixture.episode_id));
    assert_eq!(persisted.2, Some(source_hint_id));
    assert_eq!(
        persisted.3,
        Some(second_followup_id),
        "reused abnormal episode session must keep the latest proactive followup context for later chat_session_id-only turns"
    );
    assert_eq!(persisted.4, 2);
}

#[tokio::test]
#[allow(clippy::too_many_lines)]
async fn abnormal_followup_agent_confirmed_write_keeps_episode_context() {
    let _guard = diagnostics_test_lock().lock_owned().await;
    let server = MockServer::start();
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
    let (source_hint_id, agent_followup_id) = insert_due_agent_followup_hint(&app, &fixture).await;

    let prepare_mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .body_contains("\"stream\":true")
            .body_contains("prepare_pet_observation_write")
            .body_contains("便便仍稀，精神一般")
            .matches(request_without_tool_result)
            .matches(|req| !request_body(req).contains("确认写入这次异常更新"));
        then.status(200)
            .header("content-type", "text/event-stream")
            .body(
                "data: {\"choices\":[{\"delta\":{\"tool_calls\":[{\"id\":\"call_prepare_abnormal\",\"function\":{\"name\":\"prepare_pet_observation_write\",\"arguments\":\"{\\\"note\\\":\\\"便便仍稀，精神一般\\\"}\"}}]}}]}\n\n\
                 data: {\"choices\":[{\"finish_reason\":\"tool_calls\"}],\"usage\":{\"prompt_tokens\":8,\"completion_tokens\":2,\"total_tokens\":10}}\n\n\
                 data: [DONE]\n\n",
            );
    });

    let prepare_response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &fixture.access_token,
            json!({
                "message": "毛球追问后我反馈：便便仍稀，精神一般",
                "surface": "home_private",
                "selected_pet_id": fixture.pet_id.to_string(),
                "chat_context_kind": "abnormal_episode_followup",
                "abnormal_episode_id": fixture.episode_id.to_string(),
                "source_hint_id": source_hint_id.to_string(),
                "agent_followup_id": agent_followup_id.to_string()
            }),
        ))
        .await
        .expect("send abnormal followup prepare request");

    assert_eq!(prepare_response.status(), StatusCode::OK);
    let prepare_text = response_text(prepare_response).await;
    prepare_mock.assert();
    let started = sse_event_data(&prepare_text, "message_started");
    let chat_session_id = started["chat_session_id"]
        .as_str()
        .expect("chat session id")
        .parse::<Uuid>()
        .expect("chat session uuid");
    let confirmation_event = sse_event_data(&prepare_text, "confirmation_task");
    let confirmation_task_id = confirmation_event["confirmation_task_id"]
        .as_str()
        .expect("confirmation task id")
        .parse::<Uuid>()
        .expect("confirmation task uuid");

    let prepared_task: (
        Option<serde_json::Value>,
        Option<Uuid>,
        Option<String>,
        Option<Uuid>,
    ) = sqlx::query_as(
        r"
        SELECT candidate_payload, source_hint_id, source_ref_type, source_ref_id
        FROM agent_confirmation_tasks
        WHERE id = $1
        ",
    )
    .bind(confirmation_task_id)
    .fetch_one(app.pool())
    .await
    .expect("load prepared confirmation task");
    let candidate_payload = prepared_task.0.expect("candidate payload");
    assert_eq!(candidate_payload["event_kind"], "health");
    assert_eq!(candidate_payload["event_subkind"], "symptom_followup");
    assert_eq!(
        candidate_payload["episode_id"],
        fixture.episode_id.to_string()
    );
    assert_eq!(candidate_payload["source"], "agent_assisted_followup");
    assert_eq!(
        candidate_payload["agent_followup_id"],
        agent_followup_id.to_string()
    );
    assert_eq!(prepared_task.1, Some(source_hint_id));
    assert_eq!(prepared_task.2.as_deref(), Some("agent_proactive_followup"));
    assert_eq!(prepared_task.3, Some(agent_followup_id));

    let commit_tool_mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .body_contains("\"stream\":true")
            .body_contains("commit_pet_observation_write")
            .body_contains(confirmation_task_id.to_string())
            .body_contains("确认写入这次异常更新")
            .matches(request_without_tool_result);
        then.status(200)
            .header("content-type", "text/event-stream")
            .body(
                "data: {\"choices\":[{\"delta\":{\"tool_calls\":[{\"id\":\"call_commit_abnormal\",\"function\":{\"name\":\"commit_pet_observation_write\",\"arguments\":\"{\\\"confirmation_task_id\\\":\\\""
                    .to_owned()
                    + &confirmation_task_id.to_string()
                    + "\\\"}\"}}]}}]}\n\n\
                 data: {\"choices\":[{\"finish_reason\":\"tool_calls\"}],\"usage\":{\"prompt_tokens\":8,\"completion_tokens\":2,\"total_tokens\":10}}\n\n\
                 data: [DONE]\n\n",
            );
    });
    let commit_answer_mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .body_contains("\"stream\":true")
            .body_contains("\"tool_call_id\":\"call_commit_abnormal\"");
        then.status(200)
            .header("content-type", "text/event-stream")
            .body(
                "data: {\"choices\":[{\"delta\":{\"content\":\"已把这次异常更新写入进展时间线。\"}}]}\n\n\
                 data: {\"choices\":[{\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":12,\"completion_tokens\":8,\"total_tokens\":20}}\n\n\
                 data: [DONE]\n\n",
            );
    });

    let commit_response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &fixture.access_token,
            json!({
                "message": "确认写入这次异常更新",
                "surface": "home_private",
                "selected_pet_id": fixture.pet_id.to_string(),
                "chat_session_id": chat_session_id.to_string(),
                "confirmation_task_id": confirmation_task_id.to_string()
            }),
        ))
        .await
        .expect("send abnormal followup commit request");

    assert_eq!(commit_response.status(), StatusCode::OK);
    let commit_text = response_text(commit_response).await;
    commit_tool_mock.assert();
    commit_answer_mock.assert();
    assert!(commit_text.contains("已把这次异常更新写入进展时间线。"));

    let written_event: (String, serde_json::Value) = sqlx::query_as(
        r"
        SELECT event_subkind, event_payload
        FROM pet_events
        WHERE id = (
            SELECT resolved_event_id
            FROM agent_confirmation_tasks
            WHERE id = $1
        )
        ",
    )
    .bind(confirmation_task_id)
    .fetch_one(app.pool())
    .await
    .expect("load committed event");
    assert_eq!(written_event.0, "symptom_followup");
    assert_eq!(
        written_event.1["episode_id"],
        fixture.episode_id.to_string()
    );
    assert_eq!(written_event.1["source"], "agent_assisted_followup");
    assert_eq!(
        written_event.1["agent_followup_id"],
        agent_followup_id.to_string()
    );

    let followup_status: String =
        sqlx::query_scalar(r"SELECT status FROM agent_proactive_followups WHERE id = $1")
            .bind(agent_followup_id)
            .fetch_one(app.pool())
            .await
            .expect("load agent followup status");
    assert_eq!(followup_status, "answered");
}

#[tokio::test]
#[allow(clippy::too_many_lines)]
async fn abnormal_followup_second_turn_restores_agent_context_from_session() {
    let _guard = diagnostics_test_lock().lock_owned().await;
    let server = MockServer::start();
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
    let (source_hint_id, agent_followup_id) = insert_due_agent_followup_hint(&app, &fixture).await;

    let entry_mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .body_contains("\"stream\":true")
            .body_contains("毛球提醒我更新异常")
            .matches(request_without_tool_result)
            .matches(|req| !request_body(req).contains("帮我记录这次异常观察"));
        then.status(200)
            .header("content-type", "text/event-stream")
            .body(
                "data: {\"choices\":[{\"delta\":{\"content\":\"我会围绕这次异常继续追踪。\"}}]}\n\n\
                 data: {\"choices\":[{\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":8,\"completion_tokens\":8,\"total_tokens\":16}}\n\n\
                 data: [DONE]\n\n",
            );
    });

    let entry_response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &fixture.access_token,
            json!({
                "message": "毛球提醒我更新异常，先打开这个追踪会话。",
                "surface": "home_private",
                "selected_pet_id": fixture.pet_id.to_string(),
                "chat_context_kind": "abnormal_episode_followup",
                "abnormal_episode_id": fixture.episode_id.to_string(),
                "source_hint_id": source_hint_id.to_string(),
                "agent_followup_id": agent_followup_id.to_string()
            }),
        ))
        .await
        .expect("send abnormal followup entry request");

    assert_eq!(entry_response.status(), StatusCode::OK);
    let entry_text = response_text(entry_response).await;
    entry_mock.assert();
    let chat_session_id = sse_event_data(&entry_text, "message_started")["chat_session_id"]
        .as_str()
        .expect("chat session id")
        .parse::<Uuid>()
        .expect("chat session uuid");

    let prepare_mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .body_contains("\"stream\":true")
            .body_contains("异常主动追踪 planning")
            .body_contains("prepare_pet_observation_write")
            .body_contains("便便还有点稀，精神好些了")
            .matches(request_without_tool_result);
        then.status(200)
            .header("content-type", "text/event-stream")
            .body(
                "data: {\"choices\":[{\"delta\":{\"tool_calls\":[{\"id\":\"call_prepare_from_session\",\"function\":{\"name\":\"prepare_pet_observation_write\",\"arguments\":\"{\\\"note\\\":\\\"便便还有点稀，精神好些了\\\"}\"}}]}}]}\n\n\
                 data: {\"choices\":[{\"finish_reason\":\"tool_calls\"}],\"usage\":{\"prompt_tokens\":8,\"completion_tokens\":2,\"total_tokens\":10}}\n\n\
                 data: [DONE]\n\n",
            );
    });

    let prepare_response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &fixture.access_token,
            json!({
                "message": "帮我记录这次异常观察：便便还有点稀，精神好些了",
                "surface": "home_private",
                "chat_session_id": chat_session_id.to_string()
            }),
        ))
        .await
        .expect("send abnormal followup second turn prepare request");

    assert_eq!(prepare_response.status(), StatusCode::OK);
    let prepare_text = response_text(prepare_response).await;
    let confirmation_task_id =
        sse_event_data(&prepare_text, "confirmation_task")["confirmation_task_id"]
            .as_str()
            .expect("confirmation task id")
            .parse::<Uuid>()
            .expect("confirmation task uuid");
    prepare_mock.assert();

    let prepared_task: (
        Option<serde_json::Value>,
        Option<Uuid>,
        Option<String>,
        Option<Uuid>,
    ) = sqlx::query_as(
        r"
        SELECT candidate_payload, source_hint_id, source_ref_type, source_ref_id
        FROM agent_confirmation_tasks
        WHERE id = $1
        ",
    )
    .bind(confirmation_task_id)
    .fetch_one(app.pool())
    .await
    .expect("load prepared confirmation task");

    let candidate_payload = prepared_task.0.expect("candidate payload");
    assert_eq!(candidate_payload["event_subkind"], "symptom_followup");
    assert_eq!(
        candidate_payload["episode_id"],
        fixture.episode_id.to_string()
    );
    assert_eq!(candidate_payload["source"], "agent_assisted_followup");
    assert_eq!(
        candidate_payload["agent_followup_id"],
        agent_followup_id.to_string()
    );
    assert_eq!(prepared_task.1, Some(source_hint_id));
    assert_eq!(prepared_task.2.as_deref(), Some("agent_proactive_followup"));
    assert_eq!(prepared_task.3, Some(agent_followup_id));
}

#[tokio::test]
#[allow(clippy::too_many_lines)]
async fn abnormal_followup_agent_can_save_planned_followup_from_session_context() {
    let _guard = diagnostics_test_lock().lock_owned().await;
    let server = MockServer::start();
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
    let (source_hint_id, agent_followup_id) = insert_due_agent_followup_hint(&app, &fixture).await;
    let planned_due_at = "2026-07-05T18:30:00Z";

    let entry_mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .body_contains("\"stream\":true")
            .body_contains("毛球提醒我更新异常")
            .matches(request_without_tool_result)
            .matches(|req| !request_body(req).contains("根据这次异常继续安排下一次追踪"));
        then.status(200)
            .header("content-type", "text/event-stream")
            .body(
                "data: {\"choices\":[{\"delta\":{\"content\":\"我会围绕这次异常继续追踪。\"}}]}\n\n\
                 data: {\"choices\":[{\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":8,\"completion_tokens\":8,\"total_tokens\":16}}\n\n\
                 data: [DONE]\n\n",
            );
    });

    let entry_response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &fixture.access_token,
            json!({
                "message": "毛球提醒我更新异常，先打开这个追踪会话。",
                "surface": "home_private",
                "selected_pet_id": fixture.pet_id.to_string(),
                "chat_context_kind": "abnormal_episode_followup",
                "abnormal_episode_id": fixture.episode_id.to_string(),
                "source_hint_id": source_hint_id.to_string(),
                "agent_followup_id": agent_followup_id.to_string()
            }),
        ))
        .await
        .expect("send abnormal followup entry request");

    assert_eq!(entry_response.status(), StatusCode::OK);
    let entry_text = response_text(entry_response).await;
    entry_mock.assert();
    let chat_session_id = sse_event_data(&entry_text, "message_started")["chat_session_id"]
        .as_str()
        .expect("chat session id")
        .parse::<Uuid>()
        .expect("chat session uuid");

    let save_mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .body_contains("\"stream\":true")
            .body_contains("异常主动追踪 planning")
            .body_contains("save_abnormal_episode_followup_plan")
            .matches(request_without_tool_result);
        then.status(200)
            .header("content-type", "text/event-stream")
            .body(
                "data: {\"choices\":[{\"delta\":{\"tool_calls\":[{\"id\":\"call_save_plan\",\"function\":{\"name\":\"save_abnormal_episode_followup_plan\",\"arguments\":\"{\\\"due_at\\\":\\\""
                    .to_owned()
                    + planned_due_at
                    + "\\\",\\\"message_title\\\":\\\"毛球稍后再确认\\\",\\\"message_body\\\":\\\"继续确认便便、精神和食欲是否好转。\\\",\\\"rationale\\\":\\\"用户仍在异常追踪中，需要稍后复查。\\\",\\\"recommended_actions\\\":[\\\"update_observation\\\",\\\"chat_with_agent\\\"]}\"}}]}}]}\n\n\
                 data: {\"choices\":[{\"finish_reason\":\"tool_calls\"}],\"usage\":{\"prompt_tokens\":8,\"completion_tokens\":2,\"total_tokens\":10}}\n\n\
                 data: [DONE]\n\n",
            );
    });

    let answer_mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .body_contains("\"stream\":true")
            .body_contains("\"tool_call_id\":\"call_save_plan\"");
        then.status(200)
            .header("content-type", "text/event-stream")
            .body(
                "data: {\"choices\":[{\"delta\":{\"content\":\"我会稍后再提醒你更新这次异常。\"}}]}\n\n\
                 data: {\"choices\":[{\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":12,\"completion_tokens\":8,\"total_tokens\":20}}\n\n\
                 data: [DONE]\n\n",
            );
    });

    let save_response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &fixture.access_token,
            json!({
                "message": "根据这次异常继续安排下一次追踪。",
                "surface": "home_private",
                "chat_session_id": chat_session_id.to_string()
            }),
        ))
        .await
        .expect("send abnormal followup planning save request");

    assert_eq!(save_response.status(), StatusCode::OK);
    let save_text = response_text(save_response).await;
    save_mock.assert();
    answer_mock.assert();
    assert!(save_text.contains("我会稍后再提醒你更新这次异常。"));

    let saved_plan: (
        String,
        chrono::DateTime<chrono::Utc>,
        String,
        String,
        serde_json::Value,
    ) = sqlx::query_as(
        r"
        SELECT status, due_at, message_title, message_body, recommended_actions
        FROM agent_proactive_followups
        WHERE id = $1
        ",
    )
    .bind(agent_followup_id)
    .fetch_one(app.pool())
    .await
    .expect("load saved proactive followup plan");

    assert_eq!(saved_plan.0, "scheduled");
    assert_eq!(
        saved_plan.1,
        chrono::DateTime::parse_from_rfc3339(planned_due_at)
            .expect("planned due_at")
            .with_timezone(&chrono::Utc)
    );
    assert_eq!(saved_plan.2, "毛球稍后再确认");
    assert_eq!(saved_plan.3, "继续确认便便、精神和食欲是否好转。");
    assert_eq!(
        saved_plan.4,
        json!(["update_observation", "chat_with_agent"])
    );

    let episode_projection: (Option<chrono::DateTime<chrono::Utc>>, Option<Uuid>) = sqlx::query_as(
        r"
            SELECT next_followup_due_at, last_followup_plan_id
            FROM abnormal_episodes
            WHERE id = $1
            ",
    )
    .bind(fixture.episode_id)
    .fetch_one(app.pool())
    .await
    .expect("load episode followup projection");

    assert_eq!(episode_projection.0, Some(saved_plan.1));
    assert_eq!(episode_projection.1, Some(agent_followup_id));
}

#[tokio::test]
#[allow(clippy::too_many_lines)]
async fn abnormal_followup_plan_can_save_branch_actions_from_session_context() {
    let _guard = diagnostics_test_lock().lock_owned().await;
    let server = MockServer::start();
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
    let (source_hint_id, agent_followup_id) = insert_due_agent_followup_hint(&app, &fixture).await;

    let due_at = "2026-07-05T18:30:00Z";
    let save_mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .body_contains("\"stream\":true")
            .body_contains("save_abnormal_episode_followup_plan")
            .body_contains("book_clinic")
            .matches(request_without_tool_result);
        then.status(200)
            .header("content-type", "text/event-stream")
            .body(
                "data: {\"choices\":[{\"delta\":{\"tool_calls\":[{\"id\":\"call_save_branch_plan\",\"function\":{\"name\":\"save_abnormal_episode_followup_plan\",\"arguments\":\"{\\\"due_at\\\":\\\""
                    .to_owned()
                    + due_at
                    + "\\\",\\\"message_title\\\":\\\"毛球建议尽快处理\\\",\\\"message_body\\\":\\\"异常有加重迹象，建议联系医院并继续补充状态。\\\",\\\"rationale\\\":\\\"用户反馈加重，需要提供就医入口并持续追踪。\\\",\\\"recommended_actions\\\":[\\\"update_observation\\\",\\\"chat_with_agent\\\",\\\"book_clinic\\\"]}\"}}]}}]}\n\n\
                 data: {\"choices\":[{\"finish_reason\":\"tool_calls\"}],\"usage\":{\"prompt_tokens\":8,\"completion_tokens\":2,\"total_tokens\":10}}\n\n\
                 data: [DONE]\n\n",
            );
    });

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &fixture.access_token,
            json!({
                "message": "基于这次加重反馈，安排下一次追踪。",
                "surface": "home_private",
                "selected_pet_id": fixture.pet_id.to_string(),
                "chat_context_kind": "abnormal_episode_followup",
                "abnormal_episode_id": fixture.episode_id.to_string(),
                "source_hint_id": source_hint_id.to_string(),
                "agent_followup_id": agent_followup_id.to_string()
            }),
        ))
        .await
        .expect("save branch action followup plan");

    assert_eq!(response.status(), StatusCode::OK);
    let _text = response_text(response).await;
    save_mock.assert();

    let saved: serde_json::Value = sqlx::query_scalar(
        r"
        SELECT recommended_actions
        FROM agent_proactive_followups
        WHERE id = $1
        ",
    )
    .bind(agent_followup_id)
    .fetch_one(app.pool())
    .await
    .expect("load saved branch actions");

    assert_eq!(
        saved,
        json!(["update_observation", "chat_with_agent", "book_clinic"])
    );
}

async fn send_abnormal_followup_entry_request(
    app: &maohuoban_rust::test_support::AuthTestApp,
    fixture: &AbnormalEpisodeFixture,
    source_hint_id: Uuid,
    agent_followup_id: Uuid,
    message: &str,
) -> Uuid {
    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &fixture.access_token,
            json!({
                "message": message,
                "surface": "home_private",
                "selected_pet_id": fixture.pet_id.to_string(),
                "chat_context_kind": "abnormal_episode_followup",
                "abnormal_episode_id": fixture.episode_id.to_string(),
                "source_hint_id": source_hint_id.to_string(),
                "agent_followup_id": agent_followup_id.to_string()
            }),
        ))
        .await
        .expect("send abnormal followup entry chat request");

    assert_eq!(response.status(), StatusCode::OK);
    let text = response_text(response).await;
    let started = sse_event_data(&text, "message_started");
    started["chat_session_id"]
        .as_str()
        .expect("chat session id")
        .parse()
        .expect("chat session uuid")
}

async fn insert_due_agent_followup_hint(
    app: &maohuoban_rust::test_support::AuthTestApp,
    fixture: &AbnormalEpisodeFixture,
) -> (Uuid, Uuid) {
    let agent_followup_id = Uuid::new_v4();
    let source_hint_id = Uuid::new_v4();

    sqlx::query(
        r"
        INSERT INTO agent_proactive_followups (
            id, pet_id, episode_id, trigger_event_id, status,
            due_at, message_title, message_body, rationale, recommended_actions,
            created_at, updated_at
        )
        VALUES (
            $1, $2, $3, $4, 'due',
            now(), '毛球想确认一下',
            '团团的异常已经过了一段时间，现在便便、精神和食欲有好转吗？',
            '合同测试插入到期主动追踪',
            $5::jsonb,
            now(), now()
        )
        ",
    )
    .bind(agent_followup_id)
    .bind(fixture.pet_id)
    .bind(fixture.episode_id)
    .bind(fixture.initial_event_id)
    .bind(json!(["update_observation", "chat_with_agent"]))
    .execute(app.pool())
    .await
    .expect("insert due agent followup");

    sqlx::query(
        r"
        INSERT INTO attention_hints (
            id, pet_id, kind, title, subtitle, icon, tone, priority,
            status, source_ref_type, source_ref_id,
            route_kind, route_payload, created_by,
            created_at, updated_at
        )
        VALUES (
            $1, $2, 'abnormal_followup_due', '毛球想确认一下',
            '团团的异常需要更新', 'bubble.left.and.exclamationmark.bubble.right',
            'notice', 20,
            'active', 'agent_proactive_followup', $3,
            'abnormal_detail', $4::jsonb, 'agent',
            now(), now()
        )
        ",
    )
    .bind(source_hint_id)
    .bind(fixture.pet_id)
    .bind(agent_followup_id)
    .bind(json!({
        "episode_id": fixture.episode_id.to_string(),
        "event_id": fixture.initial_event_id.to_string(),
        "agent_followup_id": agent_followup_id.to_string(),
        "default_action": "chat_with_agent"
    }))
    .execute(app.pool())
    .await
    .expect("insert due agent followup hint");

    (source_hint_id, agent_followup_id)
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

#[allow(clippy::too_many_arguments)]
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
