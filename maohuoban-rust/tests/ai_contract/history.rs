use axum::http::StatusCode;
use serde_json::json;
use tower::ServiceExt;

use super::{authorized_get_request, authorized_json_request, login_and_get_token, response_json};

/// GET /api/v1/ai/chat-sessions 未登录返回 401
#[tokio::test]
async fn ai_chat_sessions_unauthorized_without_token() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;

    let response = app
        .router()
        .clone()
        .oneshot(
            axum::http::Request::builder()
                .method("GET")
                .uri("/api/v1/ai/chat-sessions")
                .body(axum::body::Body::empty())
                .expect("build request"),
        )
        .await
        .expect("send request");

    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
}

/// GET /api/v1/ai/chat-sessions/{id}/messages 未登录返回 401
#[tokio::test]
async fn ai_session_messages_unauthorized_without_token() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;

    let session_id = uuid::Uuid::new_v4();
    let response = app
        .router()
        .clone()
        .oneshot(
            axum::http::Request::builder()
                .method("GET")
                .uri(format!("/api/v1/ai/chat-sessions/{session_id}/messages"))
                .body(axum::body::Body::empty())
                .expect("build request"),
        )
        .await
        .expect("send unauthorized messages request");

    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
}

/// GET /api/v1/ai/chat-sessions 返回当前用户会话列表
#[tokio::test]
async fn ai_chat_sessions_returns_user_sessions() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139005", "ios-ai-history-list").await;

    // 先发一条聊天创建会话
    let _ = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &access_token,
            json!({
                "message": "毛球吃饭了吗",
                "surface": "home_private"
            }),
        ))
        .await
        .expect("send chat stream");

    // 查询历史列表
    let response = app
        .router()
        .clone()
        .oneshot(authorized_get_request(
            "/api/v1/ai/chat-sessions",
            &access_token,
        ))
        .await
        .expect("get sessions");

    assert_eq!(response.status(), StatusCode::OK);
    let body = response_json(response).await;
    assert_eq!(body["success"], true);
    let sessions = body["data"].as_array().expect("sessions array");
    assert!(!sessions.is_empty(), "should have at least 1 session");

    let first = &sessions[0];
    assert!(first["id"].as_str().is_some(), "session id");
    assert!(first["title"].as_str().is_some(), "session title");
    assert!(first["subtitle"].as_str().is_some(), "session subtitle");
    assert!(
        first["last_message_at"].as_str().is_some(),
        "last_message_at"
    );
}

/// GET /api/v1/ai/chat-sessions/{id}/messages 返回会话消息
#[tokio::test]
async fn ai_session_messages_returns_messages() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139006", "ios-ai-msg-detail").await;

    // 发一条聊天创建会话和消息
    let _ = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &access_token,
            json!({
                "message": "毛球精神不好",
                "surface": "home_private"
            }),
        ))
        .await
        .expect("send chat stream");

    // 获取会话列表
    let list_response = app
        .router()
        .clone()
        .oneshot(authorized_get_request(
            "/api/v1/ai/chat-sessions",
            &access_token,
        ))
        .await
        .expect("get sessions");

    let list_body = response_json(list_response).await;
    let session_id = list_body["data"][0]["id"].as_str().expect("session id");

    // 获取消息详情
    let msg_response = app
        .router()
        .clone()
        .oneshot(authorized_get_request(
            &format!("/api/v1/ai/chat-sessions/{session_id}/messages"),
            &access_token,
        ))
        .await
        .expect("get messages");

    assert_eq!(msg_response.status(), StatusCode::OK);
    let msg_body = response_json(msg_response).await;
    assert_eq!(msg_body["success"], true);
    let messages = msg_body["data"].as_array().expect("messages array");
    assert!(!messages.is_empty(), "should have at least 1 message");

    // 第一条应该是用户消息
    let first_msg = &messages[0];
    assert_eq!(first_msg["role"], "user");
    assert_eq!(first_msg["content"], "毛球精神不好");
}

/// 其他用户不能访问不属于自己的会话消息
#[tokio::test]
async fn ai_session_messages_rejects_other_user() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;

    // 用户 A 创建会话
    let token_a = login_and_get_token(&app, "13800139007", "ios-ai-user-a").await;
    let _ = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &token_a,
            json!({
                "message": "用户A的会话",
                "surface": "home_private"
            }),
        ))
        .await
        .expect("send chat stream");

    // 获取用户 A 的会话 ID
    let list_response = app
        .router()
        .clone()
        .oneshot(authorized_get_request("/api/v1/ai/chat-sessions", &token_a))
        .await
        .expect("get sessions");
    let list_body = response_json(list_response).await;
    let session_id = list_body["data"][0]["id"].as_str().expect("session id");

    // 用户 B 登录
    let token_b = login_and_get_token(&app, "13800139008", "ios-ai-user-b").await;

    // 用户 B 尝试访问用户 A 的会话消息
    let response = app
        .router()
        .clone()
        .oneshot(authorized_get_request(
            &format!("/api/v1/ai/chat-sessions/{session_id}/messages"),
            &token_b,
        ))
        .await
        .expect("get messages as user b");

    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
}
