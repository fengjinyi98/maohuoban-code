use axum::http::StatusCode;
use httpmock::{MockServer, prelude::HttpMockRequest};
use serde_json::json;
use tower::ServiceExt;

use super::{authorized_json_request, login_and_get_token, response_json};

/// 非流式无宠物 Workbench 合同
/// 核心职责：
/// - 验证 app_support / identity 这类非私域请求不再被 context_loaded 早退
/// - 验证非流式接口同样携带 AgentSession Workbench 能力目录
#[tokio::test]
async fn ai_chat_non_stream_identity_uses_workbench_runtime_without_private_tools() {
    let server = MockServer::start();
    let mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .matches(public_workbench_model_request);
        then.status(200)
            .header("content-type", "text/event-stream")
            .body(
                "data: {\"choices\":[{\"delta\":{\"content\":\"我是毛球，可以帮你聊宠物照护和毛伙伴 App 使用。\"}}]}\n\n\
                 data: {\"choices\":[{\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":8,\"completion_tokens\":6,\"total_tokens\":14}}\n\n\
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
    let access_token =
        login_and_get_token(&app, "13800139031", "ios-ai-non-stream-workbench").await;

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat",
            &access_token,
            json!({
                "message": "你是谁",
                "surface": "home_private"
            }),
        ))
        .await
        .expect("send identity non-stream chat request");

    assert_eq!(response.status(), StatusCode::OK);
    let body = response_json(response).await;

    mock.assert();
    assert_eq!(body["success"], true);
    assert_eq!(
        body["data"]["final_text"],
        "我是毛球，可以帮你聊宠物照护和毛伙伴 App 使用。"
    );
}

fn public_workbench_model_request(req: &HttpMockRequest) -> bool {
    let body = request_body(req);
    body.contains("你是谁")
        && body.contains("public_pet_domain")
        && body.contains("assistant_identity")
        && !body.contains("load_pet_identity_context")
        && !body.contains("\"role\":\"tool\"")
}

fn request_body(req: &HttpMockRequest) -> String {
    req.body
        .as_ref()
        .map(|body| String::from_utf8_lossy(body).into_owned())
        .unwrap_or_default()
}
