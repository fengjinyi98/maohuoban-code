// AgentProactiveFollowup 主动异常追踪合同测试
// 核心职责：
// - 验证异常 episode 可保存 Agent 主动追踪计划
// - 验证调度器到期后生成可操作的站内轻提醒

use super::*;

async fn create_pet_and_abnormal_episode(
    app: &maohuoban_rust::test_support::AuthTestApp,
    user_id: &str,
    phone_suffix_name: &str,
) -> (String, String, String) {
    let create_pet_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": phone_suffix_name,
                "species": "cat",
                "breed": "英短",
                "sex": "female",
                "birthday": "2025-02-01"
            }),
            Some(user_id),
        ))
        .await
        .expect("create pet");
    assert_eq!(create_pet_response.status(), StatusCode::CREATED);
    let create_pet_body = response_json(create_pet_response).await;
    let pet_id = create_pet_body["data"]["id"]
        .as_str()
        .expect("pet id")
        .to_owned();

    let create_abnormal_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/events"),
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
            Some(user_id),
        ))
        .await
        .expect("create abnormal event");
    assert_eq!(create_abnormal_response.status(), StatusCode::CREATED);
    let create_abnormal_body = response_json(create_abnormal_response).await;
    let event_id = create_abnormal_body["data"]["id"]
        .as_str()
        .expect("event id")
        .to_owned();
    let episode_id = create_abnormal_body["data"]["event_payload"]["episode_id"]
        .as_str()
        .expect("episode id")
        .to_owned();

    (pet_id, event_id, episode_id)
}

async fn insert_scheduled_followup(
    app: &maohuoban_rust::test_support::AuthTestApp,
    pet_id: &str,
    episode_id: &str,
    event_id: &str,
    due_at: chrono::DateTime<chrono::Utc>,
) -> uuid::Uuid {
    let followup_id = uuid::Uuid::new_v4();
    sqlx::query(
        r"
        INSERT INTO agent_proactive_followups (
            id, pet_id, episode_id, trigger_event_id, status,
            due_at, message_title, message_body, rationale, recommended_actions,
            created_at, updated_at
        )
        VALUES (
            $1, $2::uuid, $3::uuid, $4::uuid, 'scheduled',
            $5, '毛球想确认一下',
            '饭团早上记录了拉肚子，已经 6 小时了。现在便便、精神和食欲有好转吗？',
            '明显腹泻需要半日复查',
            $6::jsonb,
            now(), now()
        )
        ",
    )
    .bind(followup_id)
    .bind(pet_id)
    .bind(episode_id)
    .bind(event_id)
    .bind(due_at)
    .bind(json!(["update_observation", "chat_with_agent"]))
    .execute(app.pool())
    .await
    .expect("insert proactive followup plan");
    followup_id
}

#[tokio::test]
async fn abnormal_creation_creates_initial_agent_followup_plan() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13900139136").await;

    let (_pet_id, event_id, episode_id) =
        create_pet_and_abnormal_episode(&app, &user_id, "小米").await;

    let plan: (
        uuid::Uuid,
        String,
        Option<uuid::Uuid>,
        chrono::DateTime<chrono::Utc>,
        String,
        String,
    ) = sqlx::query_as(
        r"
        SELECT id, status, trigger_event_id, due_at, message_title, message_body
        FROM agent_proactive_followups
        WHERE episode_id = $1::uuid
        ORDER BY created_at DESC
        LIMIT 1
        ",
    )
    .bind(episode_id.parse::<uuid::Uuid>().expect("episode uuid"))
    .fetch_optional(app.pool())
    .await
    .expect("load initial proactive followup plan")
    .expect("abnormal creation should create initial proactive followup plan");

    assert_eq!(plan.1, "planning");
    assert_eq!(
        plan.2,
        Some(event_id.parse::<uuid::Uuid>().expect("event uuid"))
    );
    assert_eq!(plan.4, "毛球想确认一下");
    assert!(
        plan.5.contains("情况有变化吗"),
        "initial followup message should ask user to update abnormal situation: {}",
        plan.5
    );

    let episode_projection: (Option<chrono::DateTime<chrono::Utc>>, Option<uuid::Uuid>) =
        sqlx::query_as(
            r"
        SELECT next_followup_due_at, last_followup_plan_id
        FROM abnormal_episodes
        WHERE id = $1::uuid
        ",
        )
        .bind(episode_id.parse::<uuid::Uuid>().expect("episode uuid"))
        .fetch_one(app.pool())
        .await
        .expect("load episode followup projection");

    assert_eq!(episode_projection.0, Some(plan.3));
    assert_eq!(episode_projection.1, Some(plan.0));
}

#[tokio::test]
async fn due_agent_followup_creates_actionable_abnormal_followup_hint() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13900139137").await;

    let (pet_id, event_id, episode_id) =
        create_pet_and_abnormal_episode(&app, &user_id, "饭团").await;

    let planned_due_at = chrono::DateTime::parse_from_rfc3339("2026-07-05T06:10:00Z")
        .expect("planned due_at")
        .with_timezone(&chrono::Utc);
    let followup_id =
        insert_scheduled_followup(&app, &pet_id, &episode_id, &event_id, planned_due_at).await;

    let projected_hint_count: i64 =
        sqlx::query_scalar(r"SELECT project_due_agent_proactive_followups($1::timestamptz)")
            .bind(planned_due_at)
            .fetch_one(app.pool())
            .await
            .expect("project due proactive followup");
    assert_eq!(projected_hint_count, 1);

    let dashboard_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/home/dashboard?selected_pet_id={pet_id}"),
            Some(&user_id),
        ))
        .await
        .expect("load dashboard");
    assert_eq!(dashboard_response.status(), StatusCode::OK);
    let dashboard = response_json(dashboard_response).await;
    let hints = dashboard["data"]["attention_hints"].as_array().unwrap();
    let followup_hint = hints
        .iter()
        .find(|hint| hint["kind"] == "abnormal_followup_due")
        .expect("dashboard should include abnormal_followup_due hint");

    assert_eq!(followup_hint["title"], "毛球想确认一下");
    assert_eq!(followup_hint["created_by"], "agent");
    assert_eq!(followup_hint["route"]["kind"], "abnormal_detail");
    assert_eq!(
        followup_hint["route"]["payload"]["agent_followup_id"],
        followup_id.to_string()
    );
    assert_eq!(
        followup_hint["route"]["payload"]["default_action"],
        "update_observation"
    );
    assert_eq!(
        followup_hint["route"]["payload"]["actions"][0]["id"],
        "update_observation"
    );
    assert_eq!(
        followup_hint["route"]["payload"]["actions"][0]["title"],
        "更新情况"
    );
    assert_eq!(
        followup_hint["route"]["payload"]["actions"][0]["presentation"]["auto_open_sheet"],
        "abnormal_followup"
    );
    assert_eq!(
        followup_hint["route"]["payload"]["actions"][1]["id"],
        "chat_with_agent"
    );
    assert_eq!(
        followup_hint["route"]["payload"]["actions"][1]["title"],
        "问问毛球"
    );
    assert_eq!(
        followup_hint["route"]["payload"]["actions"][1]["chat_context"]["kind"],
        "abnormal_episode_followup"
    );

    let followup_status: String =
        sqlx::query_scalar(r"SELECT status FROM agent_proactive_followups WHERE id = $1")
            .bind(followup_id)
            .fetch_one(app.pool())
            .await
            .expect("load followup status");
    assert_eq!(followup_status, "due");
}

#[tokio::test]
async fn scheduler_run_once_projects_due_agent_followup_hint() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13900139141").await;

    let (pet_id, event_id, episode_id) =
        create_pet_and_abnormal_episode(&app, &user_id, "雪球").await;

    let planned_due_at = chrono::DateTime::parse_from_rfc3339("2026-07-05T06:10:00Z")
        .expect("planned due_at")
        .with_timezone(&chrono::Utc);
    let followup_id =
        insert_scheduled_followup(&app, &pet_id, &episode_id, &event_id, planned_due_at).await;

    let result = maohuoban_rust::agent_followup_scheduler::run_once(app.pool(), planned_due_at)
        .await
        .expect("run agent followup scheduler");

    assert_eq!(result.projected_hints, 1);

    let active_hint_count: i64 = sqlx::query_scalar(
        r"
        SELECT COUNT(*)
        FROM attention_hints
        WHERE source_ref_type = 'agent_proactive_followup'
          AND source_ref_id = $1
          AND kind = 'abnormal_followup_due'
          AND status = 'active'
        ",
    )
    .bind(followup_id)
    .fetch_one(app.pool())
    .await
    .expect("count active scheduler hint");

    assert_eq!(active_hint_count, 1);
}

#[tokio::test]
async fn scheduler_run_once_writes_first_agent_followup_message() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13900139142").await;

    let (pet_id, event_id, episode_id) =
        create_pet_and_abnormal_episode(&app, &user_id, "花卷").await;
    let planned_due_at = chrono::DateTime::parse_from_rfc3339("2026-07-05T06:10:00Z")
        .expect("planned due_at")
        .with_timezone(&chrono::Utc);
    let followup_id =
        insert_scheduled_followup(&app, &pet_id, &episode_id, &event_id, planned_due_at).await;

    let result = maohuoban_rust::agent_followup_scheduler::run_once(app.pool(), planned_due_at)
        .await
        .expect("run agent followup scheduler");

    assert_eq!(result.projected_hints, 1);

    let session: (
        uuid::Uuid,
        Option<String>,
        Option<uuid::Uuid>,
        Option<uuid::Uuid>,
    ) = sqlx::query_as(
        r"
            SELECT id, chat_context_kind, abnormal_episode_id, agent_followup_id
            FROM ai_chat_sessions
            WHERE abnormal_episode_id = $1::uuid
              AND actor_user_id = $2::uuid
              AND status = 'active'
            ORDER BY updated_at DESC
            LIMIT 1
            ",
    )
    .bind(episode_id.parse::<uuid::Uuid>().expect("episode uuid"))
    .bind(user_id.parse::<uuid::Uuid>().expect("user uuid"))
    .fetch_one(app.pool())
    .await
    .expect("load abnormal followup session");

    assert_eq!(session.1.as_deref(), Some("abnormal_episode_followup"));
    assert_eq!(
        session.2,
        Some(episode_id.parse::<uuid::Uuid>().expect("episode uuid"))
    );
    assert_eq!(session.3, Some(followup_id));

    let message: (String, String, String) = sqlx::query_as(
        r"
        SELECT role, content, status
        FROM ai_messages
        WHERE session_id = $1
        ORDER BY created_at ASC
        LIMIT 1
        ",
    )
    .bind(session.0)
    .fetch_one(app.pool())
    .await
    .expect("load first proactive agent message");

    assert_eq!(message.0, "assistant");
    assert_eq!(
        message.1,
        "饭团早上记录了拉肚子，已经 6 小时了。现在便便、精神和食欲有好转吗？"
    );
    assert_eq!(message.2, "completed");

    let second_result =
        maohuoban_rust::agent_followup_scheduler::run_once(app.pool(), planned_due_at)
            .await
            .expect("rerun agent followup scheduler");
    assert_eq!(second_result.projected_hints, 0);
    assert_eq!(second_result.proactive_messages, 0);
    let message_count: i64 = sqlx::query_scalar(
        r"
        SELECT COUNT(*)
        FROM ai_messages
        WHERE session_id = $1
          AND role = 'assistant'
          AND content = $2
        ",
    )
    .bind(session.0)
    .bind(message.1)
    .fetch_one(app.pool())
    .await
    .expect("count proactive agent messages");
    assert_eq!(message_count, 1);
}

#[tokio::test]
async fn future_agent_followup_does_not_show_before_due_at() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13900139138").await;
    let (pet_id, event_id, episode_id) =
        create_pet_and_abnormal_episode(&app, &user_id, "奶盖").await;

    let planned_due_at = chrono::DateTime::parse_from_rfc3339("2026-07-05T06:10:00Z")
        .expect("planned due_at")
        .with_timezone(&chrono::Utc);
    let followup_id =
        insert_scheduled_followup(&app, &pet_id, &episode_id, &event_id, planned_due_at).await;

    let projected_hint_count: i64 =
        sqlx::query_scalar(r"SELECT project_due_agent_proactive_followups($1::timestamptz)")
            .bind(
                chrono::DateTime::parse_from_rfc3339("2026-07-05T05:10:00Z")
                    .expect("before due_at")
                    .with_timezone(&chrono::Utc),
            )
            .fetch_one(app.pool())
            .await
            .expect("project before due");
    assert_eq!(projected_hint_count, 0);

    let dashboard_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/home/dashboard?selected_pet_id={pet_id}"),
            Some(&user_id),
        ))
        .await
        .expect("load dashboard");
    assert_eq!(dashboard_response.status(), StatusCode::OK);
    let dashboard = response_json(dashboard_response).await;
    let hints = dashboard["data"]["attention_hints"].as_array().unwrap();
    assert!(
        hints
            .iter()
            .all(|hint| hint["kind"] != "abnormal_followup_due"),
        "future proactive followup {followup_id} must not appear before due_at: {hints:?}"
    );
}

#[tokio::test]
async fn symptom_followup_resolves_due_agent_followup_hint() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13900139139").await;
    let (pet_id, event_id, episode_id) =
        create_pet_and_abnormal_episode(&app, &user_id, "桃酥").await;

    let planned_due_at = chrono::DateTime::parse_from_rfc3339("2026-07-05T06:10:00Z")
        .expect("planned due_at")
        .with_timezone(&chrono::Utc);
    let followup_id =
        insert_scheduled_followup(&app, &pet_id, &episode_id, &event_id, planned_due_at).await;
    let _: i64 = sqlx::query_scalar(r"SELECT project_due_agent_proactive_followups($1)")
        .bind(planned_due_at)
        .fetch_one(app.pool())
        .await
        .expect("project due followup");

    let followup_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/events"),
            json!({
                "event_kind": "health",
                "event_subkind": "symptom_followup",
                "title": "追加观察",
                "summary": "便便仍稀，精神一般",
                "visibility": "private",
                "occurred_at": "2026-07-05T06:30:00Z",
                "event_payload": {
                    "episode_id": episode_id,
                    "condition_change": "unchanged",
                    "note": "便便仍稀，精神一般"
                }
            }),
            Some(&user_id),
        ))
        .await
        .expect("create symptom followup");
    assert_eq!(followup_response.status(), StatusCode::CREATED);

    let followup_status: String =
        sqlx::query_scalar(r"SELECT status FROM agent_proactive_followups WHERE id = $1")
            .bind(followup_id)
            .fetch_one(app.pool())
            .await
            .expect("load followup status");
    assert_eq!(followup_status, "answered");

    let active_hint_count: i64 = sqlx::query_scalar(
        r"
        SELECT COUNT(*)
        FROM attention_hints
        WHERE source_ref_type = 'agent_proactive_followup'
          AND source_ref_id = $1
          AND kind = 'abnormal_followup_due'
          AND status = 'active'
        ",
    )
    .bind(followup_id)
    .fetch_one(app.pool())
    .await
    .expect("count active proactive hint");
    assert_eq!(active_hint_count, 0);
}

#[tokio::test]
async fn symptom_followup_creates_next_agent_followup_plan() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13900139140").await;
    let (pet_id, event_id, episode_id) =
        create_pet_and_abnormal_episode(&app, &user_id, "云朵").await;

    let planned_due_at = chrono::DateTime::parse_from_rfc3339("2026-07-05T06:10:00Z")
        .expect("planned due_at")
        .with_timezone(&chrono::Utc);
    let _current_followup_id =
        insert_scheduled_followup(&app, &pet_id, &episode_id, &event_id, planned_due_at).await;
    let _: i64 = sqlx::query_scalar(r"SELECT project_due_agent_proactive_followups($1)")
        .bind(planned_due_at)
        .fetch_one(app.pool())
        .await
        .expect("project due followup");

    let followup_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/events"),
            json!({
                "event_kind": "health",
                "event_subkind": "symptom_followup",
                "title": "追加观察",
                "summary": "便便仍稀，精神一般",
                "visibility": "private",
                "occurred_at": "2026-07-05T06:30:00Z",
                "event_payload": {
                    "episode_id": episode_id,
                    "condition_change": "unchanged",
                    "note": "便便仍稀，精神一般"
                }
            }),
            Some(&user_id),
        ))
        .await
        .expect("create symptom followup");
    assert_eq!(followup_response.status(), StatusCode::CREATED);
    let followup_body = response_json(followup_response).await;
    let followup_event_id = followup_body["data"]["id"]
        .as_str()
        .expect("followup event id")
        .parse::<uuid::Uuid>()
        .expect("followup event uuid");

    let next_plan: (
        uuid::Uuid,
        String,
        Option<uuid::Uuid>,
        chrono::DateTime<chrono::Utc>,
        String,
        String,
    ) = sqlx::query_as(
        r"
        SELECT id, status, trigger_event_id, due_at, message_title, message_body
        FROM agent_proactive_followups
        WHERE episode_id = $1::uuid
          AND trigger_event_id = $2::uuid
        ORDER BY created_at DESC
        LIMIT 1
        ",
    )
    .bind(episode_id.parse::<uuid::Uuid>().expect("episode uuid"))
    .bind(followup_event_id)
    .fetch_optional(app.pool())
    .await
    .expect("load next proactive followup plan")
    .expect("symptom followup should create next proactive followup plan");

    assert_eq!(next_plan.1, "planning");
    assert_eq!(next_plan.2, Some(followup_event_id));
    assert!(
        next_plan.3
            > chrono::DateTime::parse_from_rfc3339("2026-07-05T06:30:00Z")
                .expect("observed at")
                .with_timezone(&chrono::Utc),
        "next plan due_at should be after the followup observation time"
    );
    assert_eq!(next_plan.4, "毛球稍后再确认");
    assert!(
        next_plan.5.contains("继续观察"),
        "next followup message should explain continued tracking: {}",
        next_plan.5
    );

    let episode_projection: (Option<chrono::DateTime<chrono::Utc>>, Option<uuid::Uuid>) =
        sqlx::query_as(
            r"
        SELECT next_followup_due_at, last_followup_plan_id
        FROM abnormal_episodes
        WHERE id = $1::uuid
        ",
        )
        .bind(episode_id.parse::<uuid::Uuid>().expect("episode uuid"))
        .fetch_one(app.pool())
        .await
        .expect("load episode followup projection");

    assert_eq!(episode_projection.0, Some(next_plan.3));
    assert_eq!(episode_projection.1, Some(next_plan.0));
}

#[tokio::test]
async fn abnormal_recovery_clears_agent_followup_projection() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13900139143").await;
    let (pet_id, event_id, episode_id) =
        create_pet_and_abnormal_episode(&app, &user_id, "米糕").await;

    let planned_due_at = chrono::DateTime::parse_from_rfc3339("2026-07-05T06:10:00Z")
        .expect("planned due_at")
        .with_timezone(&chrono::Utc);
    let followup_id =
        insert_scheduled_followup(&app, &pet_id, &episode_id, &event_id, planned_due_at).await;
    sqlx::query(
        r"
        UPDATE abnormal_episodes
        SET next_followup_due_at = $1,
            last_followup_plan_id = $2
        WHERE id = $3::uuid
        ",
    )
    .bind(planned_due_at)
    .bind(followup_id)
    .bind(&episode_id)
    .execute(app.pool())
    .await
    .expect("set episode followup projection");

    let recovery_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/events"),
            json!({
                "event_kind": "health",
                "event_subkind": "abnormal_recovery",
                "title": "恢复记录",
                "summary": "便便和精神恢复正常",
                "visibility": "private",
                "occurred_at": "2026-07-05T08:00:00Z",
                "event_payload": {
                    "episode_id": episode_id,
                    "recovered_at": "2026-07-05T08:00:00Z",
                    "recovery_note": "便便和精神恢复正常"
                }
            }),
            Some(&user_id),
        ))
        .await
        .expect("create recovery event");
    assert_eq!(recovery_response.status(), StatusCode::CREATED);

    let projection: (
        String,
        Option<chrono::DateTime<chrono::Utc>>,
        Option<uuid::Uuid>,
    ) = sqlx::query_as(
        r"
        SELECT status, next_followup_due_at, last_followup_plan_id
        FROM abnormal_episodes
        WHERE id = $1::uuid
        ",
    )
    .bind(&episode_id)
    .fetch_one(app.pool())
    .await
    .expect("load recovered episode projection");

    assert_eq!(projection.0, "recovered");
    assert_eq!(
        projection.1, None,
        "recovered episode must not keep a next followup due projection"
    );
    assert_eq!(
        projection.2, None,
        "recovered episode must not keep a last active followup plan projection"
    );

    let followup_status: String =
        sqlx::query_scalar(r"SELECT status FROM agent_proactive_followups WHERE id = $1")
            .bind(followup_id)
            .fetch_one(app.pool())
            .await
            .expect("load followup status");
    assert_eq!(followup_status, "resolved");
}

#[tokio::test]
async fn deleting_parent_abnormal_event_clears_agent_followup_projection() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13900139144").await;
    let (pet_id, event_id, episode_id) =
        create_pet_and_abnormal_episode(&app, &user_id, "芝麻").await;

    let planned_due_at = chrono::DateTime::parse_from_rfc3339("2026-07-05T06:10:00Z")
        .expect("planned due_at")
        .with_timezone(&chrono::Utc);
    let followup_id =
        insert_scheduled_followup(&app, &pet_id, &episode_id, &event_id, planned_due_at).await;
    sqlx::query(
        r"
        UPDATE abnormal_episodes
        SET next_followup_due_at = $1,
            last_followup_plan_id = $2
        WHERE id = $3::uuid
        ",
    )
    .bind(planned_due_at)
    .bind(followup_id)
    .bind(&episode_id)
    .execute(app.pool())
    .await
    .expect("set episode followup projection");

    let delete_response = app
        .router()
        .oneshot(empty_request(
            "DELETE",
            &format!("/api/v1/pet-events/{event_id}"),
            Some(&user_id),
        ))
        .await
        .expect("delete parent abnormal event");
    assert_eq!(delete_response.status(), StatusCode::OK);

    let projection: (
        String,
        Option<chrono::DateTime<chrono::Utc>>,
        Option<uuid::Uuid>,
    ) = sqlx::query_as(
        r"
        SELECT status, next_followup_due_at, last_followup_plan_id
        FROM abnormal_episodes
        WHERE id = $1::uuid
        ",
    )
    .bind(&episode_id)
    .fetch_one(app.pool())
    .await
    .expect("load closed episode projection");

    assert_eq!(projection.0, "closed");
    assert_eq!(
        projection.1, None,
        "closed episode must not keep a next followup due projection"
    );
    assert_eq!(
        projection.2, None,
        "closed episode must not keep a last active followup plan projection"
    );

    let followup_status: String =
        sqlx::query_scalar(r"SELECT status FROM agent_proactive_followups WHERE id = $1")
            .bind(followup_id)
            .fetch_one(app.pool())
            .await
            .expect("load followup status");
    assert_eq!(followup_status, "cancelled");
}

#[tokio::test]
async fn improved_symptom_followup_marks_episode_recovering_and_plans_recovery_confirmation() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13900139145").await;
    let (pet_id, event_id, episode_id) =
        create_pet_and_abnormal_episode(&app, &user_id, "豆包").await;

    let planned_due_at = chrono::DateTime::parse_from_rfc3339("2026-07-05T06:10:00Z")
        .expect("planned due_at")
        .with_timezone(&chrono::Utc);
    let _current_followup_id =
        insert_scheduled_followup(&app, &pet_id, &episode_id, &event_id, planned_due_at).await;

    let followup_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/events"),
            json!({
                "event_kind": "health",
                "event_subkind": "symptom_followup",
                "title": "追加观察",
                "summary": "便便成形一些，精神恢复",
                "visibility": "private",
                "occurred_at": "2026-07-05T06:30:00Z",
                "event_payload": {
                    "episode_id": episode_id,
                    "condition_change": "improved",
                    "note": "便便成形一些，精神恢复"
                }
            }),
            Some(&user_id),
        ))
        .await
        .expect("create improved symptom followup");
    assert_eq!(followup_response.status(), StatusCode::CREATED);

    let episode_status: String =
        sqlx::query_scalar(r"SELECT status FROM abnormal_episodes WHERE id = $1::uuid")
            .bind(&episode_id)
            .fetch_one(app.pool())
            .await
            .expect("load episode status");
    assert_eq!(episode_status, "recovering");

    let next_plan: (String, String, serde_json::Value) = sqlx::query_as(
        r"
        SELECT status, message_body, recommended_actions
        FROM agent_proactive_followups
        WHERE episode_id = $1::uuid
          AND status = 'planning'
        ORDER BY created_at DESC
        LIMIT 1
        ",
    )
    .bind(&episode_id)
    .fetch_one(app.pool())
    .await
    .expect("load improved next plan");

    assert_eq!(next_plan.0, "planning");
    assert!(
        next_plan.1.contains("确认是否已经恢复"),
        "improved branch should plan a recovery confirmation followup: {}",
        next_plan.1
    );
    assert_eq!(
        next_plan.2,
        json!(["update_observation", "chat_with_agent", "mark_recovered"])
    );
}

#[tokio::test]
async fn worsened_symptom_followup_marks_episode_escalated_and_plans_clinic_action() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13900139146").await;
    let (pet_id, event_id, episode_id) =
        create_pet_and_abnormal_episode(&app, &user_id, "汤圆").await;

    let planned_due_at = chrono::DateTime::parse_from_rfc3339("2026-07-05T06:10:00Z")
        .expect("planned due_at")
        .with_timezone(&chrono::Utc);
    let _current_followup_id =
        insert_scheduled_followup(&app, &pet_id, &episode_id, &event_id, planned_due_at).await;

    let followup_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/events"),
            json!({
                "event_kind": "health",
                "event_subkind": "symptom_followup",
                "title": "追加观察",
                "summary": "便便更稀，精神更差，食欲下降",
                "visibility": "private",
                "occurred_at": "2026-07-05T06:30:00Z",
                "event_payload": {
                    "episode_id": episode_id,
                    "condition_change": "worsened",
                    "note": "便便更稀，精神更差，食欲下降"
                }
            }),
            Some(&user_id),
        ))
        .await
        .expect("create worsened symptom followup");
    assert_eq!(followup_response.status(), StatusCode::CREATED);

    let episode_status: String =
        sqlx::query_scalar(r"SELECT status FROM abnormal_episodes WHERE id = $1::uuid")
            .bind(&episode_id)
            .fetch_one(app.pool())
            .await
            .expect("load episode status");
    assert_eq!(episode_status, "escalated");

    let next_plan: (String, String, serde_json::Value) = sqlx::query_as(
        r"
        SELECT status, message_body, recommended_actions
        FROM agent_proactive_followups
        WHERE episode_id = $1::uuid
          AND status = 'planning'
        ORDER BY created_at DESC
        LIMIT 1
        ",
    )
    .bind(&episode_id)
    .fetch_one(app.pool())
    .await
    .expect("load worsened next plan");

    assert_eq!(next_plan.0, "planning");
    assert!(
        next_plan.1.contains("建议尽快联系医院"),
        "worsened branch should plan a clinic-oriented followup: {}",
        next_plan.1
    );
    assert_eq!(
        next_plan.2,
        json!(["update_observation", "chat_with_agent", "book_clinic"])
    );
}
