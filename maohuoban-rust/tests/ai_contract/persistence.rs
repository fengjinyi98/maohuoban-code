use axum::http::StatusCode;
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
