use axum::http::StatusCode;
use maohuoban_diagnostics::EventKind;
use serde_json::json;
use std::time::Duration;
use tower::ServiceExt;

#[path = "history/support.rs"]
mod support;

use super::{
    authorized_delete_request, authorized_get_request, authorized_json_request,
    diagnostics_test_lock, login_and_get_token, response_json, response_text,
};
use support::{
    create_chat_session, create_pet_with_avatar, current_user_id, get_session_messages,
    insert_persisted_content_blocks_fixture, install_ai_history_test_diagnostics,
    list_chat_sessions, unauthorized_ai_sessions_request, unauthorized_session_messages_request,
    upload_pending_avatar,
};

/// GET /api/v1/ai/chat-sessions 未登录返回 401
#[tokio::test]
async fn ai_chat_sessions_unauthorized_without_token() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;

    let response = app
        .router()
        .clone()
        .oneshot(unauthorized_ai_sessions_request())
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
        .oneshot(unauthorized_session_messages_request(session_id))
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

/// GET /api/v1/ai/chat-sessions 返回已激活的异常追踪会话上下文
#[tokio::test]
async fn ai_chat_sessions_returns_abnormal_episode_context() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139120", "ios-ai-history-context").await;
    let actor_user_id = current_user_id(app.pool(), "13800139120").await;
    let session_id = uuid::Uuid::new_v4();
    let episode_id = uuid::Uuid::new_v4();
    let source_hint_id = uuid::Uuid::new_v4();
    let agent_followup_id = uuid::Uuid::new_v4();

    sqlx::query(
        r"
        INSERT INTO ai_chat_sessions
            (id, actor_user_id, surface, source_hint_id, chat_context_kind,
             abnormal_episode_id, agent_followup_id, title, status,
             session_visibility, context_status, activated_at, created_at, updated_at)
        VALUES
            ($1, $2, 'home_private', $3, 'abnormal_episode_followup',
             $4, $5, '异常追踪', 'active',
             'visible', 'active', now(), now(), now())
        ",
    )
    .bind(session_id)
    .bind(actor_user_id)
    .bind(source_hint_id)
    .bind(episode_id)
    .bind(agent_followup_id)
    .execute(app.pool())
    .await
    .expect("insert abnormal episode session");

    sqlx::query(
        r"
        INSERT INTO ai_messages
            (id, session_id, role, content, content_blocks, status, citations, created_at)
        VALUES
            ($1, $3, 'system', '异常主动追踪 planning：内部规划提示', '[]'::jsonb, 'completed', '[]'::jsonb, now()),
            ($2, $3, 'assistant', '现在情况好转了吗？', '[]'::jsonb, 'completed', '[]'::jsonb, now())
        ",
    )
    .bind(uuid::Uuid::new_v4())
    .bind(uuid::Uuid::new_v4())
    .bind(session_id)
    .execute(app.pool())
    .await
    .expect("insert abnormal session messages");

    let body = list_chat_sessions(&app, &access_token).await;
    let first = &body["data"][0];

    assert_eq!(first["id"], session_id.to_string());
    assert_eq!(first["chat_context_kind"], "abnormal_episode_followup");
    assert_eq!(first["context_status"], "active");
    assert_eq!(first["abnormal_episode_id"], episode_id.to_string());
    assert_eq!(first["source_hint_id"], source_hint_id.to_string());
    assert_eq!(first["agent_followup_id"], agent_followup_id.to_string());
    assert_eq!(first["last_message_preview"], "现在情况好转了吗？");
}

/// GET /api/v1/ai/chat-sessions 不返回后台异常追踪上下文
#[tokio::test]
async fn ai_chat_sessions_hides_background_abnormal_tracking_context() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139121", "ios-ai-history-bg").await;
    let actor_user_id = current_user_id(app.pool(), "13800139121").await;
    let background_session_id = uuid::Uuid::new_v4();
    let visible_session_id = uuid::Uuid::new_v4();

    sqlx::query(
        r"
        INSERT INTO ai_chat_sessions
            (id, actor_user_id, surface, chat_context_kind, abnormal_episode_id,
             agent_followup_id, title, status, session_visibility, context_status,
             created_at, updated_at)
        VALUES
            ($1, $2, 'home_private', 'abnormal_episode_followup', $3,
             $4, '后台异常追踪', 'active', 'background', 'active',
             now(), now()),
            ($5, $2, 'home_private', NULL, NULL,
             NULL, '真实聊天', 'active', 'visible', 'active',
             now(), now())
        ",
    )
    .bind(background_session_id)
    .bind(actor_user_id)
    .bind(uuid::Uuid::new_v4())
    .bind(uuid::Uuid::new_v4())
    .bind(visible_session_id)
    .execute(app.pool())
    .await
    .expect("insert session visibility fixtures");

    let body = list_chat_sessions(&app, &access_token).await;
    let sessions = body["data"].as_array().expect("sessions array");

    assert!(
        sessions
            .iter()
            .all(|session| session["id"] != background_session_id.to_string()),
        "background tracking context must stay hidden from chat history: {sessions:?}"
    );
    assert!(
        sessions
            .iter()
            .any(|session| session["id"] == visible_session_id.to_string()),
        "visible chat session should still appear in history"
    );
}

/// POST /api/v1/ai/chat-sessions/abnormal-episode/activate 激活后台异常追踪会话
#[tokio::test]
async fn ai_chat_sessions_activate_background_abnormal_episode_context() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139123", "ios-ai-history-activate").await;
    let actor_user_id = current_user_id(app.pool(), "13800139123").await;
    let session_id = uuid::Uuid::new_v4();
    let episode_id = uuid::Uuid::new_v4();

    sqlx::query(
        r"
        INSERT INTO ai_chat_sessions
            (id, actor_user_id, surface, chat_context_kind, abnormal_episode_id,
             title, status, session_visibility, context_status, created_at, updated_at)
        VALUES
            ($1, $2, 'home_private', 'abnormal_episode_followup', $3,
             '异常追踪', 'active', 'background', 'active', now(), now())
        ",
    )
    .bind(session_id)
    .bind(actor_user_id)
    .bind(episode_id)
    .execute(app.pool())
    .await
    .expect("insert background abnormal session");

    sqlx::query(
        r"
        INSERT INTO ai_messages
            (id, session_id, role, content, content_blocks, status, citations, created_at)
        VALUES
            ($1, $3, 'system', '异常主动追踪 planning：内部规划提示', '[]'::jsonb, 'completed', '[]'::jsonb, now()),
            ($2, $3, 'assistant', '馒头现在情况好转了吗？', '[]'::jsonb, 'completed', '[]'::jsonb, now())
        ",
    )
    .bind(uuid::Uuid::new_v4())
    .bind(uuid::Uuid::new_v4())
    .bind(session_id)
    .execute(app.pool())
    .await
    .expect("insert background session messages");

    let before = list_chat_sessions(&app, &access_token).await;
    assert!(
        before["data"]
            .as_array()
            .expect("sessions")
            .iter()
            .all(|session| session["id"] != session_id.to_string()),
        "background session should be hidden before activation"
    );

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat-sessions/abnormal-episode/activate",
            &access_token,
            json!({ "abnormal_episode_id": episode_id }),
        ))
        .await
        .expect("activate abnormal episode session");

    assert_eq!(response.status(), StatusCode::OK);
    let body = response_json(response).await;
    assert_eq!(body["data"]["id"], session_id.to_string());
    assert_eq!(
        body["data"]["last_message_preview"],
        "馒头现在情况好转了吗？"
    );

    let messages = get_session_messages(&app, &access_token, &session_id.to_string()).await;
    assert_eq!(messages["data"].as_array().expect("messages").len(), 1);
    assert_eq!(messages["data"][0]["role"], "assistant");
    assert_eq!(messages["data"][0]["content"], "馒头现在情况好转了吗？");
}

/// 历史列表和消息详情写入后端诊断计数
#[tokio::test]
async fn ai_chat_history_records_backend_diagnostics_counts() {
    let _guard = diagnostics_test_lock().lock_owned().await;
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    let diagnostics = install_ai_history_test_diagnostics();
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139020", "ios-ai-history-diagnostics").await;

    let session_id = create_chat_session(&app, &access_token, "毛球今天吃饭了吗").await;
    let list_body = list_chat_sessions(&app, &access_token).await;
    assert!(
        list_body["data"]
            .as_array()
            .is_some_and(|items| !items.is_empty())
    );

    let _ = get_session_messages(&app, &access_token, &session_id).await;

    diagnostics.flush().expect("flush diagnostics");
    let events = diagnostics.read_events().expect("diagnostics events");
    assert!(events.iter().any(|event| {
        event.kind == EventKind::Analytics
            && event.message == "ai.history.sessions.loaded"
            && event.metadata["session_count"]
                .as_u64()
                .is_some_and(|count| count >= 1)
    }));
    assert!(events.iter().any(|event| {
        event.message == "ai.history.messages.loaded"
            && event.metadata["chat_session_id_prefix"]
                == json!(session_id.chars().take(8).collect::<String>())
            && event.metadata["message_count"]
                .as_u64()
                .is_some_and(|count| count >= 1)
            && event.metadata.get("message_text").is_none()
    }));
}

/// GET /api/v1/ai/chat-sessions 对旧空快照补齐当前宠物头像
#[tokio::test]
async fn ai_chat_sessions_returns_pet_avatar_when_snapshot_avatar_is_missing() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139015", "ios-ai-history-avatar").await;

    let avatar_asset_id = upload_pending_avatar(&app, &access_token).await;
    let pet = create_pet_with_avatar(&app, &access_token, "毛球", &avatar_asset_id).await;
    let pet_id = pet["id"].as_str().expect("pet id");

    let stream_response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &access_token,
            json!({
                "message": "毛球今天拉肚子了怎么办",
                "surface": "home_private",
                "selected_pet_id": pet_id
            }),
        ))
        .await
        .expect("send chat stream");
    assert_eq!(stream_response.status(), StatusCode::OK);
    let _ = response_text(stream_response).await;

    let pet_uuid = uuid::Uuid::parse_str(pet_id).expect("parse pet id");
    let session_id: uuid::Uuid = sqlx::query_scalar(
        r"
        SELECT id
        FROM ai_chat_sessions
        WHERE primary_pet_id = $1
        ORDER BY updated_at DESC
        LIMIT 1
        ",
    )
    .bind(pet_uuid)
    .fetch_one(app.pool())
    .await
    .expect("read created session id");

    sqlx::query(
        r"
        UPDATE ai_chat_sessions
        SET pet_display_snapshot = jsonb_set(
            pet_display_snapshot,
            '{pet_avatar_url}',
            'null'::jsonb,
            true
        )
        WHERE id = $1
        ",
    )
    .bind(session_id)
    .execute(app.pool())
    .await
    .expect("clear stored snapshot avatar");

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
    let first = &body["data"][0];
    let expected_avatar_url = format!("/api/v1/media/assets/{avatar_asset_id}/content");
    assert_eq!(
        first["pet_display_snapshot"]["pet_avatar_url"],
        expected_avatar_url
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
    let msg_body = get_session_messages(&app, &access_token, session_id).await;
    assert_eq!(msg_body["success"], true);
    let messages = msg_body["data"].as_array().expect("messages array");
    assert!(!messages.is_empty(), "should have at least 1 message");

    // 第一条应该是用户消息
    let first_msg = &messages[0];
    assert_eq!(first_msg["role"], "user");
    assert_eq!(first_msg["content"], "毛球精神不好");
}

/// GET /api/v1/ai/chat-sessions/{id}/messages 不返回后台 planning system 消息
#[tokio::test]
async fn ai_session_messages_hide_background_planning_system_messages() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let access_token =
        login_and_get_token(&app, "13800139122", "ios-ai-history-system-filter").await;
    let actor_user_id = current_user_id(app.pool(), "13800139122").await;
    let session_id = uuid::Uuid::new_v4();

    sqlx::query(
        r"
        INSERT INTO ai_chat_sessions
            (id, actor_user_id, surface, chat_context_kind, title, status,
             session_visibility, context_status, activated_at, created_at, updated_at)
        VALUES
            ($1, $2, 'home_private', 'abnormal_episode_followup', '异常追踪', 'active',
             'visible', 'active', now(), now(), now())
        ",
    )
    .bind(session_id)
    .bind(actor_user_id)
    .execute(app.pool())
    .await
    .expect("insert visible abnormal session");

    sqlx::query(
        r"
        INSERT INTO ai_messages
            (id, session_id, role, content, content_blocks, status, citations, created_at)
        VALUES
            ($1, $3, 'system', '异常主动追踪 planning：内部规划提示', '[]'::jsonb, 'completed', '[]'::jsonb, now()),
            ($2, $3, 'assistant', '现在情况好转了吗？', '[]'::jsonb, 'completed', '[]'::jsonb, now())
        ",
    )
    .bind(uuid::Uuid::new_v4())
    .bind(uuid::Uuid::new_v4())
    .bind(session_id)
    .execute(app.pool())
    .await
    .expect("insert system and assistant messages");

    let body = get_session_messages(&app, &access_token, &session_id.to_string()).await;
    let messages = body["data"].as_array().expect("messages array");

    assert_eq!(messages.len(), 1);
    assert_eq!(messages[0]["role"], "assistant");
    assert_eq!(messages[0]["content"], "现在情况好转了吗？");
}

/// GET /api/v1/ai/chat-sessions/{id}/messages 回放结构化内容块
#[tokio::test]
async fn ai_session_messages_returns_persisted_content_blocks() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139106", "ios-ai-block-history").await;
    let actor_user_id = current_user_id(app.pool(), "13800139106").await;
    let session_id = uuid::Uuid::new_v4();
    let message_id = uuid::Uuid::new_v4();
    insert_persisted_content_blocks_fixture(app.pool(), actor_user_id, session_id, message_id)
        .await;

    let body = get_session_messages(&app, &access_token, &session_id.to_string()).await;
    let messages = body["data"].as_array().expect("messages array");
    let assistant = messages
        .iter()
        .find(|message| message["id"] == message_id.to_string())
        .expect("assistant message");

    assert_eq!(
        assistant["content_blocks"][0]["type"],
        json!("section_heading")
    );
    assert_eq!(
        assistant["content_blocks"][1]["type"],
        json!("pet_profile_card")
    );
    assert_eq!(assistant["content_blocks"][1]["pet"]["name"], json!("梅录"));
}

/// PATCH /api/v1/ai/chat-sessions/{id}/title 重命名当前用户会话
#[tokio::test]
async fn ai_chat_session_title_can_be_renamed_by_owner() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139016", "ios-ai-history-rename").await;
    let session_id = create_chat_session(&app, &access_token, "毛球今天吃饭了吗").await;

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "PATCH",
            &format!("/api/v1/ai/chat-sessions/{session_id}/title"),
            &access_token,
            json!({ "title": "毛球吃饭复盘" }),
        ))
        .await
        .expect("rename chat session");

    assert_eq!(response.status(), StatusCode::OK);
    let body = response_json(response).await;
    assert_eq!(body["success"], true);
    assert_eq!(body["code"], "ai.session_renamed");
    assert_eq!(body["data"]["id"], session_id);
    assert_eq!(body["data"]["title"], "毛球吃饭复盘");

    let list_body = list_chat_sessions(&app, &access_token).await;
    assert_eq!(list_body["data"][0]["title"], "毛球吃饭复盘");
}

/// PATCH /api/v1/ai/chat-sessions/{id}/pin 置顶后列表优先返回该会话
#[tokio::test]
async fn ai_chat_session_pin_moves_session_to_top() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139017", "ios-ai-history-pin").await;
    let first_session_id = create_chat_session(&app, &access_token, "第一条聊天").await;
    tokio::time::sleep(Duration::from_millis(5)).await;
    let second_session_id = create_chat_session(&app, &access_token, "第二条聊天").await;

    let before_body = list_chat_sessions(&app, &access_token).await;
    assert_eq!(before_body["data"][0]["id"], second_session_id);

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "PATCH",
            &format!("/api/v1/ai/chat-sessions/{first_session_id}/pin"),
            &access_token,
            json!({ "is_pinned": true }),
        ))
        .await
        .expect("pin chat session");

    assert_eq!(response.status(), StatusCode::OK);
    let body = response_json(response).await;
    assert_eq!(body["code"], "ai.session_pin_updated");
    assert_eq!(body["data"]["id"], first_session_id);
    assert_eq!(body["data"]["is_pinned"], true);

    let after_body = list_chat_sessions(&app, &access_token).await;
    assert_eq!(after_body["data"][0]["id"], first_session_id);
    assert_eq!(after_body["data"][0]["is_pinned"], true);
    assert_eq!(after_body["data"][1]["id"], second_session_id);
}

/// DELETE /api/v1/ai/chat-sessions/{id} 删除后历史列表不再返回该会话
#[tokio::test]
async fn ai_chat_session_delete_hides_session_from_history() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139018", "ios-ai-history-delete").await;
    let session_id = create_chat_session(&app, &access_token, "准备删除的聊天").await;

    let response = app
        .router()
        .clone()
        .oneshot(authorized_delete_request(
            &format!("/api/v1/ai/chat-sessions/{session_id}"),
            &access_token,
        ))
        .await
        .expect("delete chat session");

    assert_eq!(response.status(), StatusCode::OK);
    let body = response_json(response).await;
    assert_eq!(body["code"], "ai.session_deleted");
    assert_eq!(body["data"]["id"], session_id);

    let list_body = list_chat_sessions(&app, &access_token).await;
    let sessions = list_body["data"].as_array().expect("sessions array");
    assert!(
        sessions.iter().all(|session| session["id"] != session_id),
        "deleted session should be hidden from history list"
    );
}

/// 会话操作拒绝其他用户访问
#[tokio::test]
async fn ai_chat_session_mutation_rejects_other_user() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let token_a = login_and_get_token(&app, "13800139019", "ios-ai-mutation-a").await;
    let token_b = login_and_get_token(&app, "13800139020", "ios-ai-mutation-b").await;
    let session_id = create_chat_session(&app, &token_a, "用户 A 的聊天").await;

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "PATCH",
            &format!("/api/v1/ai/chat-sessions/{session_id}/title"),
            &token_b,
            json!({ "title": "用户 B 尝试重命名" }),
        ))
        .await
        .expect("rename other user session");

    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
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
