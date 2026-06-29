use axum::http::StatusCode;
use httpmock::{MockServer, prelude::HttpMockRequest};
use serde_json::json;
use tower::ServiceExt;

use super::{authorized_json_request, login_and_get_token, response_text};

/// 流式无宠物 Workbench 合同
/// 核心职责：
/// - 验证无 selected pet 的安全请求进入 `AgentSession Workbench`
/// - 验证公共工作台不会向模型暴露宠物私域工具
#[tokio::test]
async fn ai_chat_stream_identity_uses_workbench_runtime_without_private_tools() {
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
    let access_token = login_and_get_token(&app, "13800139030", "ios-ai-public-workbench").await;

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &access_token,
            json!({
                "message": "你是谁",
                "surface": "home_private"
            }),
        ))
        .await
        .expect("send identity chat stream request");

    assert_eq!(response.status(), StatusCode::OK);
    let text = response_text(response).await;

    mock.assert();
    assert!(
        text.contains("我是毛球，可以帮你聊宠物照护和毛伙伴 App 使用。"),
        "SSE should contain workbench runtime response, got: {text}"
    );
    assert!(
        text.contains("event: answer_completed"),
        "SSE should complete through AgentSession Workbench, got: {text}"
    );
}

fn public_workbench_model_request(req: &HttpMockRequest) -> bool {
    let body = request_body(req);
    body.contains("你是谁")
        && body.contains("公共宠物照护咨询")
        && body.contains("助手身份说明")
        && !body.contains("load_pet_identity_context")
        && !body.contains("\"role\":\"tool\"")
}

fn request_body(req: &HttpMockRequest) -> String {
    req.body
        .as_ref()
        .map(|body| String::from_utf8_lossy(body).into_owned())
        .unwrap_or_default()
}
