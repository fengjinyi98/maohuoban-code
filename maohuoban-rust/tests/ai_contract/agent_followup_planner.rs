// AgentFollowupPlanner 异常主动追踪后台规划合同测试
// 核心职责：
// - 验证异常创建后的待规划项由后台 Agent planner 动态细化
// - 锁定 planner 使用同一个异常追踪上下文和受控保存 tool

use axum::http::StatusCode;
use httpmock::{MockServer, prelude::HttpMockRequest};
use serde_json::json;
use tower::ServiceExt;
use uuid::Uuid;

use super::{authorized_json_request, diagnostics_test_lock, login_and_get_token, response_json};

#[tokio::test]
#[allow(clippy::too_many_lines)]
async fn planner_run_once_saves_dynamic_plan_for_pending_abnormal_followup() {
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
    let app = maohuoban_rust::test_support::spawn_auth_test_app_with_config(config.clone()).await;
    app.reset().await;
    let access_token = login_and_get_token(&app, "13900139188", "ios-agent-followup-planner").await;
    let (_pet_id, episode_id, followup_id) =
        create_abnormal_event_and_load_plan(&app, &access_token).await;

    let planned_due_at = "2026-07-05T08:40:00Z";
    let episode_mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .body_contains("异常主动追踪 planning")
            .body_contains("load_pet_abnormal_episode_facts")
            .matches(|req| !request_body(req).contains("\"role\":\"tool\""))
            .matches(|req| !request_body(req).contains("\"episode_id\":\""))
            .matches(|req| !request_body(req).contains("\"agent_followup_id\":\""));
        then.status(200)
            .header("content-type", "text/event-stream")
            .body(tool_call_sse(
                "call_episode",
                "load_pet_abnormal_episode_facts",
                "{}",
            ));
    });
    let quick_facts_mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .body_contains("\"role\":\"tool\"")
            .body_contains("\"tool_call_id\":\"call_episode\"")
            .body_contains("load_pet_recent_health_facts")
            .matches(|req| !request_body(req).contains("\"tool_call_id\":\"call_quick\""));
        then.status(200)
            .header("content-type", "text/event-stream")
            .body(tool_call_sse(
                "call_quick",
                "load_pet_recent_health_facts",
                "{}",
            ));
    });
    let diet_mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .body_contains("\"tool_call_id\":\"call_quick\"")
            .body_contains("load_pet_current_diet_context")
            .matches(|req| !request_body(req).contains("\"tool_call_id\":\"call_diet\""));
        then.status(200)
            .header("content-type", "text/event-stream")
            .body(tool_call_sse(
                "call_diet",
                "load_pet_current_diet_context",
                "{}",
            ));
    });
    let inventory_mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .body_contains("\"tool_call_id\":\"call_diet\"")
            .body_contains("load_food_inventory_change_hints")
            .matches(|req| !request_body(req).contains("\"tool_call_id\":\"call_inventory\""));
        then.status(200)
            .header("content-type", "text/event-stream")
            .body(tool_call_sse(
                "call_inventory",
                "load_food_inventory_change_hints",
                "{}",
            ));
    });
    let save_mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .body_contains("\"tool_call_id\":\"call_inventory\"")
            .body_contains("save_abnormal_episode_followup_plan")
            .matches(|req| !request_body(req).contains("\"tool_call_id\":\"call_save_plan\""))
            .matches(|req| !request_body(req).contains("\"episode_id\":\""))
            .matches(|req| !request_body(req).contains("\"agent_followup_id\":\""));
        then.status(200)
            .header("content-type", "text/event-stream")
            .body(save_plan_sse(planned_due_at));
    });

    let result = maohuoban_rust::agent_followup_planner::run_once(
        maohuoban_rust::agent_followup_planner::AgentFollowupPlannerConfig {
            ai_llm_provider_config: config.ai_llm_provider_config,
            runtime_engine_mode: config.ai_runtime_engine_mode,
        },
        app.pool().clone(),
        chrono::DateTime::parse_from_rfc3339("2026-07-05T00:20:00Z")
            .expect("planner now")
            .with_timezone(&chrono::Utc),
    )
    .await
    .expect("run agent followup planner once");

    episode_mock.assert();
    quick_facts_mock.assert();
    diet_mock.assert();
    inventory_mock.assert();
    save_mock.assert();
    assert_eq!(result.planned_count, 1);

    let saved_plan: (
        String,
        chrono::DateTime<chrono::Utc>,
        String,
        String,
        String,
        serde_json::Value,
        serde_json::Value,
        Option<Uuid>,
    ) = sqlx::query_as(
        r"
        SELECT status, due_at, message_title, message_body, rationale, recommended_actions, planning_decision, source_turn_id
        FROM agent_proactive_followups
        WHERE id = $1
        ",
    )
    .bind(followup_id)
    .fetch_one(app.pool())
    .await
    .expect("load saved dynamic plan");

    assert_eq!(saved_plan.0, "scheduled");
    assert_eq!(
        saved_plan.1,
        chrono::DateTime::parse_from_rfc3339(planned_due_at)
            .expect("planned due_at")
            .with_timezone(&chrono::Utc)
    );
    assert_eq!(saved_plan.2, "毛球想晚点确认");
    assert_eq!(
        saved_plan.3,
        "团团早上有水样便，晚点请确认便便、精神和食欲是否好转。"
    );
    assert_eq!(saved_plan.4, "明显腹泻需尽快首次追踪，但模型选择晚些复查。");
    assert_eq!(
        saved_plan.5,
        json!(["update_observation", "chat_with_agent"])
    );
    assert_eq!(saved_plan.6["urgency_window"], "short_delay");
    let source_turn_id = saved_plan
        .7
        .expect("dynamic plan must keep source runtime turn id for audit");
    let persisted_turn_count: i64 = sqlx::query_scalar(
        r"
        SELECT COUNT(*)
        FROM ai_session_turns
        WHERE id = $1
        ",
    )
    .bind(source_turn_id)
    .fetch_one(app.pool())
    .await
    .expect("count persisted source turn");
    assert_eq!(
        persisted_turn_count, 1,
        "source_turn_id must point to the planner runtime turn"
    );

    let episode_projection: (Option<chrono::DateTime<chrono::Utc>>, Option<Uuid>) = sqlx::query_as(
        r"
            SELECT next_followup_due_at, last_followup_plan_id
            FROM abnormal_episodes
            WHERE id = $1
            ",
    )
    .bind(episode_id)
    .fetch_one(app.pool())
    .await
    .expect("load episode followup projection");

    assert_eq!(episode_projection.0, Some(saved_plan.1));
    assert_eq!(episode_projection.1, Some(followup_id));

    let save_tool_audit: (serde_json::Value, serde_json::Value, Option<String>) = sqlx::query_as(
        r"
        SELECT request_payload, response_payload, risk_signal
        FROM ai_tool_access_logs
        WHERE session_id = (
            SELECT session_id
            FROM ai_session_turns
            WHERE id = $1
        )
          AND tool_name = 'save_abnormal_episode_followup_plan'
        ORDER BY created_at DESC
        LIMIT 1
        ",
    )
    .bind(source_turn_id)
    .fetch_one(app.pool())
    .await
    .expect("load save plan tool audit payloads");
    assert_eq!(save_tool_audit.0["due_at"], planned_due_at);
    assert_eq!(
        save_tool_audit.0["time_decision"]["urgency_window"],
        "short_delay"
    );
    assert_eq!(save_tool_audit.0["time_decision"]["time_tool_used"], true);
    assert_eq!(save_tool_audit.1["fact_count"], 1);
    assert!(
        save_tool_audit.2.is_none(),
        "planning audit must preserve model-submitted payloads without code-generated timing risk labels"
    );
}

async fn create_abnormal_event_and_load_plan(
    app: &maohuoban_rust::test_support::AuthTestApp,
    access_token: &str,
) -> (Uuid, Uuid, Uuid) {
    let create_pet_response = app
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
                "sex": "female",
                "birthday": "2025-02-01"
            }),
        ))
        .await
        .expect("create pet");
    assert_eq!(create_pet_response.status(), StatusCode::CREATED);
    let create_pet_body = response_json(create_pet_response).await;
    let pet_id = create_pet_body["data"]["id"]
        .as_str()
        .expect("pet id")
        .parse::<Uuid>()
        .expect("pet uuid");

    let create_abnormal_response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/events"),
            access_token,
            json!({
                "event_kind": "health",
                "event_subkind": "abnormal_symptom",
                "title": "异常：拉肚子",
                "summary": "早上出现水样便一次",
                "visibility": "private",
                "occurred_at": "2026-07-05T00:10:00Z",
                "event_payload": {
                    "symptom_kinds": ["stool"],
                    "severity": "obvious",
                    "note": "早上出现水样便一次"
                }
            }),
        ))
        .await
        .expect("create abnormal event");
    assert_eq!(create_abnormal_response.status(), StatusCode::CREATED);
    let create_abnormal_body = response_json(create_abnormal_response).await;
    let episode_id = create_abnormal_body["data"]["event_payload"]["episode_id"]
        .as_str()
        .expect("episode id")
        .parse::<Uuid>()
        .expect("episode uuid");

    let pending_plan: (Uuid, String) = sqlx::query_as(
        r"
        SELECT id, status
        FROM agent_proactive_followups
        WHERE episode_id = $1
        ",
    )
    .bind(episode_id)
    .fetch_one(app.pool())
    .await
    .expect("load pending proactive followup");
    assert_eq!(pending_plan.1, "planning");

    (pet_id, episode_id, pending_plan.0)
}

fn request_body(req: &HttpMockRequest) -> String {
    String::from_utf8_lossy(req.body.as_deref().unwrap_or_default()).into_owned()
}

fn tool_call_sse(call_id: &str, tool_name: &str, arguments: &str) -> String {
    format!(
        "data: {{\"choices\":[{{\"delta\":{{\"tool_calls\":[{{\"id\":\"{call_id}\",\"function\":{{\"name\":\"{tool_name}\",\"arguments\":\"{}\"}}}}]}}}}]}}\n\n\
         data: {{\"choices\":[{{\"finish_reason\":\"tool_calls\"}}],\"usage\":{{\"prompt_tokens\":8,\"completion_tokens\":2,\"total_tokens\":10}}}}\n\n\
         data: [DONE]\n\n",
        arguments.replace('"', "\\\"")
    )
}

fn save_plan_sse(planned_due_at: &str) -> String {
    "data: {\"choices\":[{\"delta\":{\"tool_calls\":[{\"id\":\"call_save_plan\",\"function\":{\"name\":\"save_abnormal_episode_followup_plan\",\"arguments\":\"{\\\"due_at\\\":\\\""
        .to_owned()
        + planned_due_at
        + "\\\",\\\"message_title\\\":\\\"毛球想晚点确认\\\",\\\"message_body\\\":\\\"团团早上有水样便，晚点请确认便便、精神和食欲是否好转。\\\",\\\"rationale\\\":\\\"明显腹泻需尽快首次追踪，但模型选择晚些复查。\\\",\\\"time_decision\\\":{\\\"now_at\\\":\\\"2026-07-05T00:20:00Z\\\",\\\"episode_started_at\\\":\\\"2026-07-05T00:10:00Z\\\",\\\"elapsed_minutes\\\":10,\\\"selected_due_at\\\":\\\""
        + planned_due_at
        + "\\\",\\\"delay_minutes\\\":500,\\\"urgency_window\\\":\\\"short_delay\\\",\\\"reason\\\":\\\"明显腹泻需要短延迟复查\\\",\\\"time_tool_used\\\":true},\\\"recommended_actions\\\":[\\\"update_observation\\\",\\\"chat_with_agent\\\"]}\"}}]}}]}\n\n\
           data: {\"choices\":[{\"finish_reason\":\"tool_calls\"}],\"usage\":{\"prompt_tokens\":12,\"completion_tokens\":4,\"total_tokens\":16}}\n\n\
           data: [DONE]\n\n"
}
