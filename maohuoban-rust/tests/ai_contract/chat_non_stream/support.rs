use axum::http::StatusCode;
use httpmock::{Mock, MockServer, prelude::HttpMockRequest};
use serde_json::{Value, json};
use tower::ServiceExt;

use crate::{authorized_json_request, response_json};

/// `create_pet` 创建非流式 AI 合同测试宠物
/// 核心职责：
/// - 为当前登录用户创建授权宠物
/// - 返回接口 data 供后续 AI 请求携带 `selected_pet_id`
pub async fn create_pet(
    app: &maohuoban_rust::test_support::AuthTestApp,
    access_token: &str,
    name: &str,
) -> Value {
    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/pets",
            access_token,
            json!({
                "name": name,
                "species": "cat",
                "breed": "英短",
                "sex": "male",
                "birthday": "2024-01-01",
                "arrival_date": "2024-03-01"
            }),
        ))
        .await
        .expect("create pet");

    assert_eq!(response.status(), StatusCode::CREATED);
    response_json(response).await["data"].clone()
}

/// `install_runtime_tool_call_mocks` 安装非流式工具调用模型响应
/// 核心职责：
/// - 固定首轮模型工具调用响应
/// - 固定工具回灌后的 followup 模型响应
pub fn install_runtime_tool_call_mocks<'a>(
    server: &'a MockServer,
    pet_id: &str,
) -> (Mock<'a>, Mock<'a>) {
    let first_body = runtime_tool_call_response_body(pet_id);
    let first_mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .matches(runtime_first_model_request)
            .body_contains("\"tools\"")
            .body_contains("load_pet_identity_context");
        then.status(200)
            .header("content-type", "text/event-stream")
            .body(first_body);
    });
    let second_mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .matches(runtime_followup_model_request)
            .body_contains("\"stream\":true")
            .body_contains("\"role\":\"tool\"")
            .body_contains("\"tool_call_id\":\"call_1\"");
        then.status(200)
            .header("content-type", "text/event-stream")
            .body(runtime_tool_followup_response_body());
    });
    (first_mock, second_mock)
}

fn runtime_tool_call_response_body(pet_id: &str) -> String {
    let arguments = serde_json::json!({ "pet_id": pet_id }).to_string();
    format!(
        "data: {{\"choices\":[{{\"delta\":{{\"tool_calls\":[{{\"id\":\"call_1\",\"function\":{{\"name\":\"load_pet_identity_context\",\"arguments\":{arguments:?}}}}}]}}}}]}}\n\n\
         data: {{\"choices\":[{{\"finish_reason\":\"tool_calls\"}}],\"usage\":{{\"prompt_tokens\":8,\"completion_tokens\":2,\"total_tokens\":10}}}}\n\n\
         data: [DONE]\n\n"
    )
}

fn runtime_tool_followup_response_body() -> &'static str {
    "data: {\"choices\":[{\"delta\":{\"content\":\"已读取毛球档案，当前可以继续观察精神和食欲。\"}}]}\n\n\
     data: {\"choices\":[{\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":12,\"completion_tokens\":8,\"total_tokens\":20}}\n\n\
     data: [DONE]\n\n"
}

fn runtime_first_model_request(req: &HttpMockRequest) -> bool {
    let body = request_body(req);
    body.contains("\"tools\"")
        && body.contains("load_pet_identity_context")
        && !body.contains("\"role\":\"tool\"")
}

fn runtime_followup_model_request(req: &HttpMockRequest) -> bool {
    let body = request_body(req);
    body.contains("\"role\":\"tool\"") && body.contains("\"tool_call_id\":\"call_1\"")
}

/// `load_actor_user_id_by_phone` 按手机号读取测试用户 ID
/// 核心职责：
/// - 从 `user_identities` 读取登录后 `actor_user_id`
/// - 为记忆写入合同测试提供用户上下文
pub async fn load_actor_user_id_by_phone(
    app: &maohuoban_rust::test_support::AuthTestApp,
    phone: &str,
) -> uuid::Uuid {
    sqlx::query_scalar(
        r"
        SELECT user_id
        FROM user_identities
        WHERE provider = 'phone' AND identifier = $1
        ",
    )
    .bind(phone)
    .fetch_one(app.pool())
    .await
    .expect("load actor user id")
}

/// `insert_user_memory` 写入用户偏好记忆
/// 核心职责：
/// - 直接写入测试记忆表
/// - 验证非流式主链会把记忆投影进 provider prompt
pub async fn insert_user_memory(
    app: &maohuoban_rust::test_support::AuthTestApp,
    actor_user_id: uuid::Uuid,
    summary: &str,
) {
    sqlx::query(
        r"
        INSERT INTO agent_memory_items
            (id, scope_type, scope_id, actor_user_id, memory_kind,
             content, summary, source_ref, confidence, status)
        VALUES ($1, 'user', $2, $2, 'preference', $3, $3, '{}'::jsonb, 0.95, 'active')
        ",
    )
    .bind(uuid::Uuid::new_v4())
    .bind(actor_user_id)
    .bind(summary)
    .execute(app.pool())
    .await
    .expect("insert user memory");
}

/// `assert_non_stream_session_header_finalized` 断言会话头被 finalizer 更新
/// 核心职责：
/// - 验证 `last_message_at、last_turn_id` 和 `primary_pet_id`
/// - 验证 assistant message 关联同一 `turn_id`
pub async fn assert_non_stream_session_header_finalized(
    app: &maohuoban_rust::test_support::AuthTestApp,
    body: &Value,
    pet_id: &str,
) {
    let chat_session_id = uuid::Uuid::parse_str(
        body["data"]["chat_session_id"]
            .as_str()
            .expect("chat session id"),
    )
    .expect("parse chat session id");
    let message_id = uuid::Uuid::parse_str(
        body["data"]["message_id"]
            .as_str()
            .expect("assistant message id"),
    )
    .expect("parse assistant message id");
    let session_header: (
        Option<chrono::DateTime<chrono::Utc>>,
        Option<uuid::Uuid>,
        Option<uuid::Uuid>,
    ) = sqlx::query_as(
        r"
        SELECT last_message_at, last_turn_id, primary_pet_id
        FROM ai_chat_sessions
        WHERE id = $1
        ",
    )
    .bind(chat_session_id)
    .fetch_one(app.pool())
    .await
    .expect("load chat session header");

    assert!(
        session_header.0.is_some(),
        "finalizer must persist last_message_at"
    );
    assert!(
        session_header.1.is_some(),
        "finalizer must persist last_turn_id"
    );
    assert_eq!(
        session_header.2.map(|id| id.to_string()),
        Some(pet_id.to_owned())
    );

    let message_turn_id: Option<uuid::Uuid> = sqlx::query_scalar(
        r"
        SELECT turn_id
        FROM ai_messages
        WHERE id = $1
        ",
    )
    .bind(message_id)
    .fetch_one(app.pool())
    .await
    .expect("load assistant turn id");
    assert_eq!(session_header.1, message_turn_id);
}

fn request_body(req: &HttpMockRequest) -> String {
    req.body
        .as_ref()
        .map(|body| String::from_utf8_lossy(body).into_owned())
        .unwrap_or_default()
}
