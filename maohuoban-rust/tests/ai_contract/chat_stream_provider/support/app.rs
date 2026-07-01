// app Provider 流式合同测试应用支撑
// 核心职责：
// - 使用 mock server 构造测试数据库隔离的 AuthTestApp
// - 创建宠物、用户记忆等 Provider 场景 fixture

use axum::http::StatusCode;
use httpmock::MockServer;
use serde_json::{Value, json};
use tower::ServiceExt;

use crate::{authorized_json_request, response_json};

/// `spawn_provider_test_app` 使用 mock server 构建 Provider 测试应用
pub(crate) async fn spawn_provider_test_app(
    server: &MockServer,
) -> maohuoban_rust::test_support::AuthTestApp {
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
    maohuoban_rust::test_support::spawn_auth_test_app_with_config(config).await
}

pub(crate) async fn create_pet(
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

pub(crate) async fn load_actor_user_id_by_phone(
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

pub(crate) async fn insert_user_memory(
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
