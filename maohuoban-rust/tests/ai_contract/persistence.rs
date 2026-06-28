use axum::http::StatusCode;
use chrono::{TimeZone, Utc};
use maohuoban_ai_application::ai::ports::{AiSessionRepository, SessionEventRepository};
use maohuoban_ai_domain::ai::{
    AgentSessionEventEntry, AiProposedAction, AiProposedActionKind, AiProposedActionRisk,
};
use maohuoban_ai_infrastructure::repository::{
    PostgresAiSessionRepository, PostgresSessionEventRepository,
};
use serde_json::json;
use tower::ServiceExt;

use super::{authorized_json_request, login_and_get_token, response_text};

/// AI chat stream 成功后 DB 中有 session 和 user message
#[tokio::test]
async fn ai_chat_stream_persists_session_and_user_message() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139003", "ios-ai-persist-test").await;

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &access_token,
            json!({
                "message": "毛球拉肚子了怎么办",
                "surface": "home_private"
            }),
        ))
        .await
        .expect("send chat stream request");

    assert_eq!(response.status(), StatusCode::OK);
    // 消费完整响应体，确保 stream 结束
    let _ = response_text(response).await;

    // 查询 DB 验证持久化
    let session_count: i64 =
        sqlx::query_scalar("SELECT COUNT(*) FROM ai_chat_sessions WHERE title LIKE '%毛球拉肚子%'")
            .fetch_one(app.pool())
            .await
            .expect("count sessions");

    assert_eq!(session_count, 1, "should have 1 AI chat session");

    let user_msg_count: i64 = sqlx::query_scalar(
        "SELECT COUNT(*) FROM ai_messages WHERE role = 'user' AND content = '毛球拉肚子了怎么办'",
    )
    .fetch_one(app.pool())
    .await
    .expect("count user messages");

    assert_eq!(user_msg_count, 1, "should have 1 user message");

    // 验证 session 的 actor_user_id 不为空
    let actor_id: uuid::Uuid = sqlx::query_scalar(
        "SELECT actor_user_id FROM ai_chat_sessions WHERE title LIKE '%毛球拉肚子%'",
    )
    .fetch_one(app.pool())
    .await
    .expect("get actor_user_id");

    assert!(!actor_id.is_nil(), "actor_user_id should not be nil");
}

/// AI chat stream 不允许请求体传入 `actor_user_id`
#[tokio::test]
async fn ai_chat_stream_ignores_actor_user_id_in_body() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139004", "ios-ai-no-actor").await;

    let fake_actor_id = uuid::Uuid::new_v4();
    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &access_token,
            json!({
                "message": "测试",
                "surface": "home_private",
                "actor_user_id": fake_actor_id
            }),
        ))
        .await
        .expect("send chat stream request");

    assert_eq!(response.status(), StatusCode::OK);
    let _ = response_text(response).await;

    // 验证 DB 中的 actor_user_id 不是请求体传入的值
    let db_actor_id: uuid::Uuid =
        sqlx::query_scalar("SELECT actor_user_id FROM ai_chat_sessions WHERE title = '测试'")
            .fetch_one(app.pool())
            .await
            .expect("get actor_user_id");

    assert_ne!(
        db_actor_id, fake_actor_id,
        "actor_user_id should come from token, not request body"
    );
}

/// AI proposed action 仓储会写入待确认动作表
#[tokio::test]
async fn ai_proposed_action_repository_persists_pending_action() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139019", "ios-ai-proposed-action").await;

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &access_token,
            json!({
                "message": "测试建议动作",
                "surface": "home_private"
            }),
        ))
        .await
        .expect("send chat stream request");

    assert_eq!(response.status(), StatusCode::OK);
    let _ = response_text(response).await;

    let session_id: uuid::Uuid =
        sqlx::query_scalar("SELECT id FROM ai_chat_sessions WHERE title = '测试建议动作'")
            .fetch_one(app.pool())
            .await
            .expect("get session id");

    let action = AiProposedAction {
        id: uuid::Uuid::new_v4(),
        action_kind: AiProposedActionKind::DietChangeConfirmation,
        target_pet_id: uuid::Uuid::new_v4(),
        payload: json!({"food_name": "渴望六种鱼"}),
        confirm_text: "确认饭团正在吃渴望六种鱼".to_owned(),
        risk_level: AiProposedActionRisk::Medium,
        source_message_id: None,
        confirmation_task_id: None,
    };

    let pet_event_count_before: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM pet_events")
        .fetch_one(app.pool())
        .await
        .expect("count pet events before proposed action");

    let repo = PostgresAiSessionRepository::new(app.pool().clone());
    repo.insert_proposed_action(session_id, &action)
        .await
        .expect("insert proposed action");

    let row: (String, String, String, serde_json::Value) = sqlx::query_as(
        r"
        SELECT action_kind, risk_level, status, payload
        FROM ai_proposed_actions
        WHERE id = $1
        ",
    )
    .bind(action.id)
    .fetch_one(app.pool())
    .await
    .expect("read proposed action");

    assert_eq!(row.0, "diet_change_confirmation");
    assert_eq!(row.1, "medium");
    assert_eq!(row.2, "pending");
    assert_eq!(row.3["food_name"], "渴望六种鱼");

    let pet_event_count_after: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM pet_events")
        .fetch_one(app.pool())
        .await
        .expect("count pet events after proposed action");

    assert_eq!(
        pet_event_count_after, pet_event_count_before,
        "proposed action persistence must not write pet_events strong facts"
    );
}

/// AI session event 仓储按 turn 追加并按写入顺序读回 runtime events
#[tokio::test]
async fn ai_session_event_store_appends_and_lists_turn_events() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;

    let session_id = uuid::Uuid::new_v4();
    let turn_id = uuid::Uuid::new_v4();
    insert_chat_session_fixture(app.pool(), session_id).await;

    let repo = PostgresSessionEventRepository::new(app.pool().clone());
    let started = AgentSessionEventEntry::new(
        session_id,
        turn_id,
        "turn_started",
        json!({
            "turn_id": turn_id,
            "chat_session_id": session_id,
            "agent_id": "main_pet_care_agent",
            "surface": "home_private"
        }),
    );
    let model_started = AgentSessionEventEntry::new(
        session_id,
        turn_id,
        "model_call_started",
        json!({
            "turn_id": turn_id,
            "model_label": "primary",
            "tool_count": 0
        }),
    );

    repo.append(&started).await.expect("append turn_started");
    repo.append(&model_started)
        .await
        .expect("append model_call_started");

    let turn_events = repo
        .list_by_turn(turn_id)
        .await
        .expect("list events by turn");

    assert_eq!(turn_events.len(), 2);
    assert_eq!(turn_events[0].event_name, "turn_started");
    assert_eq!(turn_events[1].event_name, "model_call_started");
    assert_eq!(turn_events[0].payload["agent_id"], "main_pet_care_agent");

    let row_count: i64 = sqlx::query_scalar(
        r"
        SELECT COUNT(*)
        FROM ai_session_events
        WHERE session_id = $1 AND turn_id = $2
        ",
    )
    .bind(session_id)
    .bind(turn_id)
    .fetch_one(app.pool())
    .await
    .expect("count session events");
    assert_eq!(row_count, 2);
}

/// AI session event 仓储按 session 读回事件，并能通过 payload 关联用户可见消息
#[tokio::test]
async fn ai_session_event_store_lists_session_events_with_message_link_payload() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;

    let session_id = uuid::Uuid::new_v4();
    let turn_id = uuid::Uuid::new_v4();
    let message_id = uuid::Uuid::new_v4();
    insert_chat_session_fixture(app.pool(), session_id).await;
    insert_ai_message_fixture(app.pool(), session_id, message_id).await;

    let repo = PostgresSessionEventRepository::new(app.pool().clone());
    repo.append(&AgentSessionEventEntry::new(
        session_id,
        turn_id,
        "turn_finished",
        json!({
            "turn_id": turn_id,
            "message_id": message_id,
            "final_text_summary": "照护建议摘要",
            "status": "completed"
        }),
    ))
    .await
    .expect("append turn_finished");

    let session_events = repo
        .list_by_session(session_id)
        .await
        .expect("list events by session");

    assert_eq!(session_events.len(), 1);
    assert_eq!(session_events[0].event_name, "turn_finished");
    assert_eq!(
        session_events[0].payload["message_id"],
        message_id.to_string()
    );

    let linked_message_count: i64 = sqlx::query_scalar(
        r"
        SELECT COUNT(*)
        FROM ai_messages
        WHERE id = ($1)::uuid
          AND session_id = $2
        ",
    )
    .bind(
        session_events[0].payload["message_id"]
            .as_str()
            .expect("message id payload"),
    )
    .bind(session_id)
    .fetch_one(app.pool())
    .await
    .expect("count linked message");
    assert_eq!(linked_message_count, 1);
}

/// AI session event 仓储对同一时间戳的事件仍按 append 顺序回放，并生成非空 event_index
#[tokio::test]
async fn ai_session_event_store_preserves_append_order_for_same_timestamp_events() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;

    let session_id = uuid::Uuid::new_v4();
    let turn_id = uuid::Uuid::new_v4();
    insert_chat_session_fixture(app.pool(), session_id).await;

    let same_timestamp = Utc
        .with_ymd_and_hms(2026, 6, 28, 10, 0, 0)
        .single()
        .expect("valid timestamp");

    let repo = PostgresSessionEventRepository::new(app.pool().clone());
    let first = AgentSessionEventEntry {
        id: uuid::Uuid::new_v4(),
        session_id,
        turn_id,
        parent_event_id: None,
        event_name: "turn_started".to_owned(),
        payload: json!({"turn_id": turn_id, "step": 1}),
        created_at: same_timestamp,
    };
    let second = AgentSessionEventEntry {
        id: uuid::Uuid::new_v4(),
        session_id,
        turn_id,
        parent_event_id: Some(first.id),
        event_name: "model_call_started".to_owned(),
        payload: json!({"turn_id": turn_id, "step": 2}),
        created_at: same_timestamp,
    };

    repo.append(&first).await.expect("append first event");
    repo.append(&second).await.expect("append second event");

    let turn_events = repo
        .list_by_turn(turn_id)
        .await
        .expect("list same timestamp events by turn");

    assert_eq!(
        turn_events
            .iter()
            .map(|event| event.event_name.as_str())
            .collect::<Vec<_>>(),
        vec!["turn_started", "model_call_started"]
    );

    let null_index_count: i64 = sqlx::query_scalar(
        r"
        SELECT COUNT(*)
        FROM ai_session_events
        WHERE session_id = $1
          AND turn_id = $2
          AND event_index IS NULL
        ",
    )
    .bind(session_id)
    .bind(turn_id)
    .fetch_one(app.pool())
    .await
    .expect("count null event_index rows");
    assert_eq!(null_index_count, 0);

    let column_is_nullable: String = sqlx::query_scalar(
        r"
        SELECT is_nullable
        FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = 'ai_session_events'
          AND column_name = 'event_index'
        ",
    )
    .fetch_one(app.pool())
    .await
    .expect("read event_index nullability");
    assert_eq!(column_is_nullable, "NO");
}

async fn insert_chat_session_fixture(pool: &sqlx::PgPool, session_id: uuid::Uuid) {
    sqlx::query(
        r"
        INSERT INTO ai_chat_sessions
            (id, actor_user_id, surface, title, status, created_at, updated_at)
        VALUES ($1, $2, 'home_private', 'session event fixture', 'active', now(), now())
        ",
    )
    .bind(session_id)
    .bind(uuid::Uuid::new_v4())
    .execute(pool)
    .await
    .expect("insert chat session fixture");
}

async fn insert_ai_message_fixture(
    pool: &sqlx::PgPool,
    session_id: uuid::Uuid,
    message_id: uuid::Uuid,
) {
    sqlx::query(
        r"
        INSERT INTO ai_messages
            (id, session_id, role, content, status, citations, created_at)
        VALUES ($1, $2, 'assistant', '照护建议', 'completed', '[]'::jsonb, now())
        ",
    )
    .bind(message_id)
    .bind(session_id)
    .execute(pool)
    .await
    .expect("insert ai message fixture");
}
