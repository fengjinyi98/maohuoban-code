use axum::http::StatusCode;
use httpmock::MockServer;
use serde_json::{Value, json};
use tower::ServiceExt;

use super::{authorized_json_request, login_and_get_token, response_json};

/// `/api/v1/ai/chat` 未配置 Provider 时返回稳定错误
#[tokio::test]
async fn ai_chat_non_stream_returns_provider_not_configured() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139002", "ios-ai-chat-test").await;
    let pet = create_pet(&app, &access_token, "毛球").await;
    let pet_id = pet["id"].as_str().expect("pet id");

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat",
            &access_token,
            json!({
                "message": "毛球今天怎么样",
                "surface": "home_private",
                "selected_pet_id": pet_id
            }),
        ))
        .await
        .expect("send chat request");

    assert_eq!(response.status(), StatusCode::SERVICE_UNAVAILABLE);
    let body = response_json(response).await;
    assert_eq!(body["success"], false);
    assert_eq!(body["code"], "ai.provider_not_configured");
}

/// `/api/v1/ai/chat` 配置 Provider 后返回非流式聚合回答
#[tokio::test]
async fn ai_chat_non_stream_uses_configured_openai_provider() {
    let server = MockServer::start();
    let mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .body_contains("\"stream\":false")
            .body_contains("只能基于提供的事实包")
            .body_contains("## 目标宠物");
        then.status(200)
            .header("content-type", "application/json")
            .body(
                r#"{
                    "id": "chatcmpl-contract",
                    "model": "contract-model",
                    "choices": [
                        {
                            "message": {
                                "role": "assistant",
                                "content": "毛球今天可以先观察精神、食欲和排便变化。"
                            },
                            "finish_reason": "stop"
                        }
                    ],
                    "usage": {
                        "prompt_tokens": 6,
                        "completion_tokens": 12,
                        "total_tokens": 18
                    }
                }"#,
            );
    });

    let mut config = maohuoban_rust::BackendConfig::local_test();
    config.ai_llm_provider_config = Some(
        maohuoban_ai_infrastructure::provider::OpenAiCompatibleConfig {
            base_url: server.base_url(),
            api_key: "contract-api-key".to_owned(),
            model: "contract-model".to_owned(),
            timeout_secs: 5,
            temperature: 0.2,
            max_output_tokens: None,
        },
    );
    let app = maohuoban_rust::test_support::spawn_auth_test_app_with_config(config).await;
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139017", "ios-ai-chat-non-stream").await;
    let pet = create_pet(&app, &access_token, "毛球").await;
    let pet_id = pet["id"].as_str().expect("pet id");

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat",
            &access_token,
            json!({
                "message": "毛球今天怎么样？",
                "surface": "home_private",
                "selected_pet_id": pet_id
            }),
        ))
        .await
        .expect("send configured non-stream chat request");

    assert_eq!(response.status(), StatusCode::OK);
    let body = response_json(response).await;

    mock.assert();
    assert_eq!(body["success"], true);
    assert_eq!(body["code"], "ai.chat_completed");
    assert_eq!(
        body["data"]["final_text"],
        "毛球今天可以先观察精神、食欲和排便变化。"
    );
    assert_eq!(body["data"]["usage"]["input_tokens"], 6);
    assert_eq!(body["data"]["usage"]["output_tokens"], 12);
    assert_eq!(body["data"]["verification"]["status"], "passed");
    assert_eq!(body["data"]["target_pet"]["pet_name"], "毛球");

    let assistant_count: i64 = sqlx::query_scalar(
        r"
        SELECT COUNT(*)
        FROM ai_messages
        WHERE role = 'assistant'
          AND content = '毛球今天可以先观察精神、食欲和排便变化。'
          AND model = 'contract-model'
          AND provider = 'openai_compatible'
        ",
    )
    .fetch_one(app.pool())
    .await
    .expect("count persisted assistant message");

    assert_eq!(assistant_count, 1);
}

/// `/api/v1/ai/chat` 对 off-topic 请求跳过主 Provider
#[tokio::test]
async fn ai_chat_non_stream_off_topic_records_gate_log_and_skips_provider() {
    let server = MockServer::start();
    let mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions");
        then.status(200)
            .header("content-type", "application/json")
            .body(
                r#"{
                "model": "contract-model",
                "choices": [
                    {
                        "message": {
                            "role": "assistant",
                            "content": "不应调用"
                        },
                        "finish_reason": "stop"
                    }
                ]
            }"#,
            );
    });

    let mut config = maohuoban_rust::BackendConfig::local_test();
    config.ai_llm_provider_config = Some(
        maohuoban_ai_infrastructure::provider::OpenAiCompatibleConfig {
            base_url: server.base_url(),
            api_key: "contract-api-key".to_owned(),
            model: "contract-model".to_owned(),
            timeout_secs: 5,
            temperature: 0.2,
            max_output_tokens: None,
        },
    );
    let app = maohuoban_rust::test_support::spawn_auth_test_app_with_config(config).await;
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139018", "ios-ai-chat-off-topic").await;

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat",
            &access_token,
            json!({
                "message": "帮我写一首关于夏天的诗",
                "surface": "home_private"
            }),
        ))
        .await
        .expect("send off-topic non-stream chat request");

    assert_eq!(response.status(), StatusCode::OK);
    let body = response_json(response).await;

    mock.assert_hits(0);
    assert_eq!(body["success"], true);
    assert!(
        body["data"]["final_text"]
            .as_str()
            .is_some_and(|text| text.contains("只能处理宠物照护"))
    );

    let row: (String, bool, Option<String>) = sqlx::query_as(
        r"
        SELECT intent, context_loaded, risk_signal
        FROM ai_request_gate_logs
        ORDER BY created_at DESC
        LIMIT 1
        ",
    )
    .fetch_one(app.pool())
    .await
    .expect("read latest gate log");

    assert_eq!(row.0, "off_topic");
    assert!(!row.1);
    assert_eq!(row.2, None);
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
