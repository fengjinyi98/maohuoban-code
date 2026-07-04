use axum::http::StatusCode;
use httpmock::{Mock, MockServer, prelude::HttpMockRequest};
use maohuoban_diagnostics::{
    CapturePolicy, CleanupPolicy, Diagnostics, DiagnosticsConfig, FileSegmentStore, PrivacyPolicy,
};
use serde_json::{Map, Value, json};
use tower::ServiceExt;

use crate::{authorized_json_request, response_json};

/// `assert_diagnostics_field_present` 断言诊断 metadata 字段存在
/// 核心职责：
/// - 固定规划和 gate 诊断字段存在性断言格式
/// - 保持合同测试中的字段缺失提示一致
pub fn assert_diagnostics_field_present(metadata: &Map<String, Value>, field: &str, label: &str) {
    assert!(
        !metadata[field].is_null(),
        "{label} diagnostics missing required field: {field}"
    );
}

/// `assert_gate_decision_metadata_complete` 断言 gate 决策诊断字段完整
/// 核心职责：
/// - 验证 gate 决策中的字符串字段非空
/// - 验证 gate 决策中的布尔字段类型正确
pub fn assert_gate_decision_metadata_complete(metadata: &Map<String, Value>) {
    assert!(
        metadata["intent"].as_str().is_some_and(|v| !v.is_empty()),
        "gate diagnostics missing intent field"
    );
    assert!(
        metadata["gate_decision"]
            .as_str()
            .is_some_and(|v| !v.is_empty()),
        "gate diagnostics missing gate_decision field"
    );
    assert!(
        metadata["context_loaded"].is_boolean(),
        "gate diagnostics missing context_loaded bool field"
    );
    assert!(
        metadata["risk_signal_present"].is_boolean(),
        "gate diagnostics missing risk_signal_present bool field"
    );
    assert!(
        metadata["allow_processing"].is_boolean(),
        "gate diagnostics missing allow_processing bool field"
    );
}

/// `install_ai_test_diagnostics` 安装 AI 合同测试诊断运行时
/// 核心职责：
/// - 为单个测试用例创建隔离的诊断存储目录
/// - 固定测试诊断运行时的服务名、环境和隐私策略
pub fn install_ai_test_diagnostics() -> Diagnostics {
    let root =
        std::env::temp_dir().join(format!("maohuoban-ai-diagnostics-{}", uuid::Uuid::new_v4()));
    let store = FileSegmentStore::new(root.join("segments"), 1024 * 1024).expect("store");
    Diagnostics::install(DiagnosticsConfig {
        service_name: "maohuoban-rust".to_owned(),
        environment: "test".to_owned(),
        privacy: PrivacyPolicy::default(),
        capture: CapturePolicy::default(),
        cleanup: CleanupPolicy::default(),
        store: Box::new(store),
    })
    .expect("install diagnostics")
}

/// `spawn_runtime_tool_render_test_app` 创建工具渲染诊断测试应用
/// 核心职责：
/// - 将测试应用的 LLM provider 指向本地 mock server
/// - 固定模型配置以验证流式工具调用诊断链路
pub async fn spawn_runtime_tool_render_test_app(
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

/// `install_runtime_tool_render_mocks` 安装工具渲染诊断模型响应
/// 核心职责：
/// - 固定首轮模型工具调用响应
/// - 固定工具回灌后的 followup 模型响应
pub fn install_runtime_tool_render_mocks<'a>(
    server: &'a MockServer,
    pet_id: &str,
) -> (Mock<'a>, Mock<'a>) {
    let first_body = runtime_tool_call_response_body(pet_id, "load_pet_identity_context");
    let first_mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .matches(runtime_first_model_request)
            .body_contains("\"stream\":true")
            .body_contains("\"tools\"")
            .body_contains("load_pet_identity_context")
            .body_contains("我的宠物多大了")
            .body_contains("\"role\":\"user\"");
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
            .body(
                "data: {\"choices\":[{\"delta\":{\"content\":\"已读取梅录档案，当前可以继续观察精神和食欲。\"}}]}\n\n\
                 data: {\"choices\":[{\"finish_reason\":\"stop\"}],\"usage\":{\"prompt_tokens\":12,\"completion_tokens\":8,\"total_tokens\":20}}\n\n\
                 data: [DONE]\n\n",
            );
    });
    (first_mock, second_mock)
}

fn runtime_tool_call_response_body(pet_id: &str, tool_name: &str) -> String {
    let arguments = serde_json::json!({ "pet_id": pet_id }).to_string();
    format!(
        "data: {{\"choices\":[{{\"delta\":{{\"tool_calls\":[{{\"id\":\"call_1\",\"function\":{{\"name\":{tool_name:?},\"arguments\":{arguments:?}}}}}]}}}}]}}\n\n\
         data: {{\"choices\":[{{\"finish_reason\":\"tool_calls\"}}],\"usage\":{{\"prompt_tokens\":8,\"completion_tokens\":2,\"total_tokens\":10}}}}\n\n\
         data: [DONE]\n\n"
    )
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

/// `create_pet` 创建流式诊断合同测试宠物
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

fn request_body(req: &HttpMockRequest) -> String {
    req.body
        .as_ref()
        .map(|body| String::from_utf8_lossy(body).into_owned())
        .unwrap_or_default()
}
