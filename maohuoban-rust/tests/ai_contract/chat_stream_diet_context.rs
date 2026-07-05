use axum::http::StatusCode;
use httpmock::{Mock, MockServer, prelude::HttpMockRequest};
use serde_json::{Value, json};
use tower::ServiceExt;

use super::{
    authorized_json_request, diagnostics_test_lock, login_and_get_token, response_json,
    response_text, sse_event_data,
};

/// AI stream 会通过 Runtime 工具预取当前饮食上下文后回灌 Provider
#[tokio::test]
async fn ai_chat_stream_loads_current_diet_context_for_provider_prompt() {
    let _guard = diagnostics_test_lock().lock_owned().await;
    let server = MockServer::start();
    let (first_mock, followup_mock) = install_current_diet_context_mocks(&server);

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
    let access_token = login_and_get_token(&app, "13800139013", "ios-ai-diet-context").await;
    let pet = create_pet(&app, &access_token, "毛球").await;
    let pet_id = pet["id"].as_str().expect("pet id");
    let food_item_id = create_food_inventory_item(&app, &access_token, "渴望六种鱼").await;
    let assignment_id = set_current_staple(&app, &access_token, pet_id, &food_item_id).await;

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &access_token,
            json!({
                "message": "毛球现在吃的主粮是什么？",
                "surface": "home_private",
                "selected_pet_id": pet_id
            }),
        ))
        .await
        .expect("send diet context chat stream request");

    let status = response.status();
    let text = response_text(response).await;

    assert_eq!(
        status,
        StatusCode::OK,
        "diet context stream failed, body: {text}"
    );

    first_mock.assert();
    followup_mock.assert();
    let started = sse_event_data(&text, "message_started");
    let chat_session_id = started["chat_session_id"]
        .as_str()
        .expect("chat session id");
    assert!(
        text.contains("event: execution_trace_completed") && text.contains("正在查看毛球近期饮食"),
        "SSE should contain diet context execution trace, got: {text}"
    );
    assert!(
        text.contains("event: citation") && text.contains(&assignment_id),
        "SSE should contain diet assignment citation event, got: {text}"
    );

    let tool_log: (String, bool, Option<uuid::Uuid>, serde_json::Value) = sqlx::query_as(
        r"
        SELECT requested_scope, allowed, target_pet_id, returned_ref_ids
        FROM ai_tool_access_logs
        WHERE tool_name = 'load_pet_current_diet_context'
          AND session_id = $1
        ORDER BY created_at DESC
        LIMIT 1
        ",
    )
    .bind(uuid::Uuid::parse_str(chat_session_id).expect("parse chat session id"))
    .fetch_one(app.pool())
    .await
    .expect("read latest diet tool access log");

    let pet_uuid = uuid::Uuid::parse_str(pet_id).expect("parse pet id");
    assert_eq!(tool_log.0, "pet_current_diet");
    assert!(tool_log.1);
    assert_eq!(tool_log.2, Some(pet_uuid));
    let returned_ref_ids = tool_log.3.as_array().expect("returned ref ids");
    assert!(returned_ref_ids.contains(&json!(assignment_id)));

    let citation_count: i64 = sqlx::query_scalar(
        r"
        SELECT COUNT(*)
        FROM ai_message_citations
        WHERE source_kind = 'diet_assignment'
          AND source_id = $1
        ",
    )
    .bind(uuid::Uuid::parse_str(&assignment_id).expect("assignment id"))
    .fetch_one(app.pool())
    .await
    .expect("count persisted message citations");

    assert_eq!(citation_count, 1);
}

fn install_current_diet_context_mocks(server: &MockServer) -> (Mock<'_>, Mock<'_>) {
    let first_mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .body_contains("\"stream\":true")
            .body_contains("load_pet_current_diet_context")
            .matches(request_without_tool_result);
        then.status(200)
            .header("content-type", "text/event-stream")
            .body(tool_call_response_body(
                "call_current_diet",
                "load_pet_current_diet_context",
            ));
    });
    let followup_mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .body_contains("\"stream\":true")
            .body_contains("\"role\":\"tool\"")
            .body_contains("\"tool_call_id\":\"call_current_diet\"")
            .body_contains("渴望六种鱼");
        then.status(200)
            .header("content-type", "text/event-stream")
            .body(
                "data: {\"choices\":[{\"delta\":{\"content\":\"当前主粮是渴望六种鱼。\"}}]}\n\n\
                 data: {\"choices\":[{\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":4,\"completion_tokens\":6,\"total_tokens\":10}}\n\n\
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
    let body = req
        .body
        .as_ref()
        .map(|body| String::from_utf8_lossy(body).into_owned())
        .unwrap_or_default();
    !body.contains("\"role\":\"tool\"")
}

async fn create_pet(
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

    let status = response.status();
    let body = response_json(response).await;
    assert_eq!(status, StatusCode::CREATED, "create_pet failed: {body}");
    body["data"].clone()
}

async fn create_food_inventory_item(
    app: &maohuoban_rust::test_support::AuthTestApp,
    access_token: &str,
    name: &str,
) -> String {
    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/food-inventory/items",
            access_token,
            json!({
                "name": name,
                "brand": "Orijen",
                "category": "main_food",
                "inventory_status": "sealed",
                "quantity": 1,
                "production_date": "2026-01-01",
                "shelf_life_months": 18
            }),
        ))
        .await
        .expect("create food inventory item");

    let status = response.status();
    let body = response_json(response).await;
    assert_eq!(
        status,
        StatusCode::CREATED,
        "create_food_inventory_item failed: {body}"
    );
    body["data"]["id"]
        .as_str()
        .expect("food item id")
        .to_owned()
}

async fn set_current_staple(
    app: &maohuoban_rust::test_support::AuthTestApp,
    access_token: &str,
    pet_id: &str,
    food_item_id: &str,
) -> String {
    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/diet/staple"),
            access_token,
            json!({
                "food_item_id": food_item_id,
                "reason": "AI 契约测试设置"
            }),
        ))
        .await
        .expect("set current staple");

    let status = response.status();
    let body = response_json(response).await;
    assert_eq!(
        status,
        StatusCode::CREATED,
        "set_current_staple failed for pet {pet_id}: {body}"
    );
    body["data"]["id"]
        .as_str()
        .expect("assignment id")
        .to_owned()
}
