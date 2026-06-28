use axum::http::StatusCode;
use httpmock::MockServer;
use serde_json::{Value, json};
use tower::ServiceExt;

use super::{authorized_json_request, login_and_get_token, response_json, response_text};

/// AI stream 会把储物柜变化作为弱线索注入 Provider Prompt
#[tokio::test]
async fn ai_chat_stream_loads_food_inventory_change_hints_as_weak_context() {
    let server = MockServer::start();
    let mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .body_contains("\"stream\":true")
            .body_contains("弱线索")
            .body_contains("不能作为已发生事实")
            .body_contains("巅峰牛肉罐头");
        then.status(200)
            .header("content-type", "text/event-stream")
            .body(
                "data: {\"choices\":[{\"delta\":{\"content\":\"我看到储物柜里有巅峰牛肉罐头的变化线索，需要你确认毛球是否在吃。\"}}]}\n\n\
                 data: {\"choices\":[{\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":5,\"completion_tokens\":10,\"total_tokens\":15}}\n\n\
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
    let access_token = login_and_get_token(&app, "13800139014", "ios-ai-inventory-hints").await;
    let pet = create_pet(&app, &access_token, "毛球").await;
    let pet_id = pet["id"].as_str().expect("pet id");
    let food_item_id = create_food_inventory_item(&app, &access_token, "巅峰牛肉罐头").await;

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &access_token,
            json!({
                "message": "毛球最近有什么新食物需要确认？",
                "surface": "home_private",
                "selected_pet_id": pet_id
            }),
        ))
        .await
        .expect("send inventory hint chat stream request");

    assert_eq!(response.status(), StatusCode::OK);
    let text = response_text(response).await;

    mock.assert();
    assert!(
        text.contains("event: tool_call") && text.contains("load_food_inventory_change_hints"),
        "SSE should contain food inventory hints tool_call, got: {text}"
    );

    let tool_log: (String, bool, Option<uuid::Uuid>, serde_json::Value) = sqlx::query_as(
        r"
        SELECT requested_scope, allowed, target_pet_id, returned_ref_ids
        FROM ai_tool_access_logs
        WHERE tool_name = 'load_food_inventory_change_hints'
        ORDER BY created_at DESC
        LIMIT 1
        ",
    )
    .fetch_one(app.pool())
    .await
    .expect("read latest food inventory hints tool access log");

    let pet_uuid = uuid::Uuid::parse_str(pet_id).expect("parse pet id");
    let returned_ref_ids = tool_log.3.as_array().expect("returned ref ids");
    assert_eq!(tool_log.0, "food_inventory_change_hints");
    assert!(tool_log.1);
    assert_eq!(tool_log.2, Some(pet_uuid));
    assert!(returned_ref_ids.contains(&json!(food_item_id)));
}

/// AI stream 校验器会阻断把储物柜弱线索当作已确认饮食事实的回答
#[tokio::test]
async fn ai_chat_stream_blocks_confirmed_claim_from_food_inventory_weak_hint() {
    let server = MockServer::start();
    let mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .body_contains("\"stream\":true");
        then.status(200)
            .header("content-type", "text/event-stream")
            .body(
                "data: {\"choices\":[{\"delta\":{\"content\":\"毛球已经换成巅峰牛肉罐头了。\"}}]}\n\n\
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
    let access_token = login_and_get_token(&app, "13800139016", "ios-ai-weak-verify").await;
    let pet = create_pet(&app, &access_token, "毛球").await;
    let pet_id = pet["id"].as_str().expect("pet id");
    create_food_inventory_item(&app, &access_token, "巅峰牛肉罐头").await;

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &access_token,
            json!({
                "message": "毛球最近是不是换粮了？",
                "surface": "home_private",
                "selected_pet_id": pet_id
            }),
        ))
        .await
        .expect("send weak hint verification chat stream request");

    assert_eq!(response.status(), StatusCode::OK);
    let text = response_text(response).await;

    mock.assert();
    assert!(
        !text.contains("已经换成巅峰牛肉罐头"),
        "unsafe weak hint claim should not be streamed, got: {text}"
    );
    assert!(
        text.contains("该信息尚为待确认线索")
            && text.contains("\"blocked_reason\":\"weak_hint_misuse\""),
        "message_completed should include weak_hint_misuse block, got: {text}"
    );
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
                "brand": "Ziwi",
                "category": "wet_food",
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
