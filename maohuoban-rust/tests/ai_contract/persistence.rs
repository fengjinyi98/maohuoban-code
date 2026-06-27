use axum::http::StatusCode;
use maohuoban_ai_application::ai::ports::AiSessionRepository;
use maohuoban_ai_domain::ai::{AiProposedAction, AiProposedActionKind, AiProposedActionRisk};
use maohuoban_ai_infrastructure::repository::PostgresAiSessionRepository;
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
