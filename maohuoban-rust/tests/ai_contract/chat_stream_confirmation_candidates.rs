use axum::http::StatusCode;
use httpmock::MockServer;
use serde_json::{Value, json};
use tower::ServiceExt;

use super::{authorized_json_request, login_and_get_token, response_json, response_text};

/// AI stream 会把宠物饮食待确认候选作为 pending context 注入 Provider Prompt
#[tokio::test]
async fn ai_chat_stream_loads_diet_confirmation_candidates_as_pending_context() {
    let server = MockServer::start();
    let mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .body_contains("pending")
            .body_contains("possible_diet_change")
            .body_contains("最近新增的「渴望六种鱼」，饭团有吃过或正在换这款吗？");
        then.status(200)
            .header("content-type", "text/event-stream")
            .body(
                "data: {\"choices\":[{\"delta\":{\"content\":\"我需要确认饭团是否在吃渴望六种鱼。\"}}]}\n\n\
                 data: {\"choices\":[{\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":5,\"completion_tokens\":8,\"total_tokens\":13}}\n\n\
                 data: [DONE]\n\n",
            );
    });

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
    let access_token = login_and_get_token(&app, "13800139015", "ios-ai-confirm-candidates").await;
    let pet = create_pet(&app, &access_token, "饭团").await;
    let pet_id = pet["id"].as_str().expect("pet id");
    let food_item_id = create_food_inventory_item(&app, &access_token, "渴望六种鱼").await;

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &access_token,
            json!({
                "message": "饭团最近有什么饮食需要我确认？",
                "surface": "home_private",
                "selected_pet_id": pet_id
            }),
        ))
        .await
        .expect("send confirmation candidate chat stream request");

    assert_eq!(response.status(), StatusCode::OK);
    let text = response_text(response).await;

    mock.assert();
    assert!(
        text.contains("event: tool_call") && text.contains("load_pet_diet_confirmation_candidates"),
        "SSE should contain diet confirmation candidates tool_call, got: {text}"
    );

    let tool_log: (String, bool, Option<uuid::Uuid>, serde_json::Value) = sqlx::query_as(
        r"
        SELECT requested_scope, allowed, target_pet_id, returned_ref_ids
        FROM ai_tool_access_logs
        WHERE tool_name = 'load_pet_diet_confirmation_candidates'
        ORDER BY created_at DESC
        LIMIT 1
        ",
    )
    .fetch_one(app.pool())
    .await
    .expect("read latest confirmation candidates tool access log");

    let pet_uuid = uuid::Uuid::parse_str(pet_id).expect("parse pet id");
    let returned_ref_ids = tool_log.3.as_array().expect("returned ref ids");
    assert_eq!(tool_log.0, "pet_diet_confirmation_candidates");
    assert!(tool_log.1);
    assert_eq!(tool_log.2, Some(pet_uuid));
    assert!(returned_ref_ids.contains(&json!(food_item_id)));
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

    assert_eq!(response.status(), StatusCode::CREATED);
    response_json(response).await["data"].clone()
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
                "quantity": 1
            }),
        ))
        .await
        .expect("create food inventory item");

    assert_eq!(response.status(), StatusCode::CREATED);
    response_json(response).await["data"]["id"]
        .as_str()
        .expect("food item id")
        .to_owned()
}
