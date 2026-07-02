// chat_stream_runtime_tools Runtime 工具链路流式合同测试
// 核心职责：
// - 验证模型工具调用经 Tool Gateway 执行后回灌到二次模型
// - 验证工具进度在二次模型完成前通过 SSE 到达

use async_trait::async_trait;
use axum::http::StatusCode;
use futures_util::StreamExt;
use httpmock::{Mock, MockServer, prelude::HttpMockRequest};
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolGatewayObserver, AiToolMetadata, AiToolResult,
    AiToolRiskLevel, ToolGatewayExecutionContext, ToolRegistry,
};
use maohuoban_ai_domain::ai::{
    AiToolConfirmationRequirement, LlmToolCall, ToolExecutionAudit, ToolFailure, ToolProgressText,
    Toolset,
};
use maohuoban_diagnostics::{
    CapturePolicy, CleanupPolicy, Diagnostics, DiagnosticsConfig, FileSegmentStore, PrivacyPolicy,
};
use serde_json::{Value, json};
use std::sync::{Arc, Mutex};
use std::time::Duration;
use tower::ServiceExt;
use uuid::Uuid;

use super::{
    authorized_json_request, diagnostics_test_lock, login_and_get_token, response_json,
    response_text,
};

/// Provider 返回工具调用时 `/api/v1/ai/chat/stream` 通过自有 Agent Runtime 执行工具并回灌
#[tokio::test]
async fn ai_chat_stream_executes_runtime_tool_call_and_followup_model() {
    let _guard = diagnostics_test_lock().lock_owned().await;
    let server = MockServer::start();
    let app = spawn_runtime_tool_test_app(&server).await;
    let diagnostics = install_runtime_tool_test_diagnostics();
    app.reset().await;
    let access_token = login_and_get_token(&app, "13800139021", "ios-ai-runtime-tool").await;
    let pet = create_pet(&app, &access_token, "毛球").await;
    let pet_id = pet["id"].as_str().expect("pet id");
    let (first_mock, second_mock) = install_runtime_tool_call_mocks(&server, pet_id);

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &access_token,
            json!({
                "message": "读取毛球档案后告诉我状态",
                "surface": "home_private",
                "selected_pet_id": pet_id
            }),
        ))
        .await
        .expect("send runtime tool chat stream request");

    assert_eq!(response.status(), StatusCode::OK);
    let text = response_text(response).await;

    first_mock.assert();
    second_mock.assert();
    assert_runtime_tool_stream_contract(&text);
    diagnostics.flush().expect("flush diagnostics");
    let events = diagnostics.read_events().expect("diagnostics events");
    assert_runtime_tool_diagnostics(&events);
}

/// Runtime 工具进度在二次模型完成前通过 SSE 到达
#[tokio::test]
async fn ai_chat_stream_emits_runtime_tool_progress_before_followup_model_finishes() {
    let server = MockServer::start();
    let app = spawn_runtime_tool_test_app(&server).await;
    app.reset().await;
    let access_token =
        login_and_get_token(&app, "13800139022", "ios-ai-runtime-tool-progress").await;
    let pet = create_pet(&app, &access_token, "毛球").await;
    let pet_id = pet["id"].as_str().expect("pet id");
    let (first_mock, second_mock) = install_runtime_tool_call_mocks_with_followup_delay(
        &server,
        pet_id,
        Duration::from_secs(3),
    );

    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            &access_token,
            json!({
                "message": "读取毛球档案后告诉我状态",
                "surface": "home_private",
                "selected_pet_id": pet_id
            }),
        ))
        .await
        .expect("send runtime tool progress chat stream request");

    assert_eq!(response.status(), StatusCode::OK);
    let mut body_stream = response.into_body().into_data_stream();
    let partial_text = read_sse_until_contains(
        &mut body_stream,
        &[
            "event: execution_trace_started",
            "正在整理毛球的宠物档案",
            "event: execution_trace_completed",
            "\"status\":\"completed\"",
        ],
        Duration::from_millis(500),
    )
    .await;

    first_mock.assert();
    let started_events = sse_event_data_all(&partial_text, "execution_trace_started");
    assert!(
        started_events
            .iter()
            .any(|event| event["display_text"] == "正在整理毛球的宠物档案"),
        "SSE should stream runtime execution trace start before followup model finishes, got: {started_events:?}"
    );
    let completed_events = sse_event_data_all(&partial_text, "execution_trace_completed");
    assert!(
        completed_events.iter().any(|event| {
            event["display_text"] == "正在整理毛球的宠物档案" && event["status"] == "completed"
        }),
        "SSE should stream backend-provided execution trace completion text, got: {completed_events:?}"
    );
    let mut full_text = partial_text;
    while let Some(chunk) = body_stream.next().await {
        let chunk = chunk.expect("read remaining SSE chunk");
        full_text.push_str(&String::from_utf8_lossy(&chunk));
    }
    second_mock.assert();
    assert!(
        full_text.contains("已读取毛球档案，当前可以继续观察精神和食欲。"),
        "SSE should still complete with followup model answer, got: {full_text}"
    );
}

/// Tool Gateway 合同记录未知工具拒绝态
#[tokio::test]
async fn ai_contract_tool_gateway_records_denied_diagnostics() {
    let audits = Arc::new(Mutex::new(Vec::new()));
    let registry = ToolRegistry::new();
    let ctx = test_gateway_context_with_audits(audits.clone());

    let result = registry
        .execute_tool_call(
            &ctx,
            &LlmToolCall {
                id: "call_denied".to_owned(),
                name: "missing_runtime_tool".to_owned(),
                arguments: "{}".to_owned(),
            },
        )
        .await
        .audit;

    assert_eq!(result.tool_name, "missing_runtime_tool");
    assert_eq!(result.policy_decision, "denied");
    assert!(result.failure_code.is_none());
    assert_eq!(result.risk_level, "low");
    assert_eq!(result.toolset, "unknown");
    assert!(result.session_id.is_some());
    assert!(result.turn_id.is_some());
    assert!(result.message_id.is_some());
    assert_recorded_audit(&audits, "missing_runtime_tool", "denied", None);
}

/// Tool Gateway 合同记录工具执行失败态
#[tokio::test]
async fn ai_contract_tool_gateway_records_failed_diagnostics() {
    let audits = Arc::new(Mutex::new(Vec::new()));
    let mut registry = ToolRegistry::new();
    registry.register(FailedContractTool);
    let ctx = test_gateway_context_with_audits(audits.clone());

    let result = registry
        .execute_tool_call(
            &ctx,
            &LlmToolCall {
                id: "call_failed".to_owned(),
                name: "load_pet_current_diet_context".to_owned(),
                arguments: "{}".to_owned(),
            },
        )
        .await
        .audit;

    assert_eq!(result.tool_name, "load_pet_current_diet_context");
    assert_eq!(result.policy_decision, "failed");
    assert_eq!(
        result.failure_code.as_deref(),
        Some("ai.provider_not_configured")
    );
    assert_eq!(result.risk_level, "low");
    assert_eq!(result.toolset, "private_pet_context");
    assert!(result.session_id.is_some());
    assert!(result.turn_id.is_some());
    assert!(result.message_id.is_some());
    assert_recorded_audit(
        &audits,
        "load_pet_current_diet_context",
        "failed",
        Some("ai.provider_not_configured"),
    );
}

/// Tool Gateway diagnostics 记录确认需求态
#[tokio::test]
async fn ai_contract_tool_gateway_records_requires_confirmation_diagnostics() {
    let audits = Arc::new(Mutex::new(Vec::new()));
    let mut registry = ToolRegistry::new();
    registry.register(ConfirmationContractTool);
    let ctx = test_gateway_context_with_audits(audits.clone());

    let result = registry
        .execute_tool_call(
            &ctx,
            &LlmToolCall {
                id: "call_requires_confirmation".to_owned(),
                name: "create_pet_reminder".to_owned(),
                arguments: json!({ "title": "吃药" }).to_string(),
            },
        )
        .await;

    assert_eq!(result.audit.policy_decision, "requires_confirmation");
    assert!(result.audit.failure_code.is_none());
    assert_eq!(result.audit.risk_level, "high");
    assert_eq!(result.audit.toolset, "confirmation");
    assert_recorded_audit(
        &audits,
        "create_pet_reminder",
        "requires_confirmation",
        None,
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

fn sse_event_data_all(text: &str, event_name: &str) -> Vec<Value> {
    let mut values = Vec::new();
    let mut lines = text.lines();
    while let Some(line) = lines.next() {
        if line.trim() == format!("event: {event_name}") {
            for data_line in lines.by_ref() {
                if let Some(data) = data_line.strip_prefix("data: ") {
                    values.push(serde_json::from_str(data).expect("parse sse data"));
                    break;
                }
            }
        }
    }
    values
}

/// `read_sse_until_contains` 逐块读取 SSE 直到命中目标片段
/// 核心职责：
/// - 验证 SSE 事件在 body 未完成前可被消费
/// - 为工具进度实时性测试保留已读取文本
async fn read_sse_until_contains(
    body_stream: &mut axum::body::BodyDataStream,
    expected_fragments: &[&str],
    timeout: Duration,
) -> String {
    tokio::time::timeout(timeout, async {
        let mut text = String::new();
        while !expected_fragments
            .iter()
            .all(|fragment| text.contains(fragment))
        {
            let chunk = body_stream
                .next()
                .await
                .unwrap_or_else(|| {
                    panic!(
                        "SSE stream ended before expected fragments {expected_fragments:?}, partial text: {text}"
                    )
                })
                .expect("read SSE chunk");
            text.push_str(&String::from_utf8_lossy(&chunk));
        }
        text
    })
    .await
    .expect("SSE should emit expected fragments before timeout")
}

fn install_runtime_tool_call_mocks<'a>(
    server: &'a MockServer,
    pet_id: &str,
) -> (Mock<'a>, Mock<'a>) {
    install_runtime_tool_call_mocks_with_followup_delay(server, pet_id, Duration::ZERO)
}

async fn spawn_runtime_tool_test_app(
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

fn assert_runtime_tool_stream_contract(text: &str) {
    assert!(
        text.contains("event: execution_trace_started")
            && text.contains("event: execution_trace_completed")
            && text.contains("正在整理毛球的宠物档案"),
        "SSE should contain runtime execution trace events, got: {text}"
    );
    let started_events = sse_event_data_all(text, "execution_trace_started");
    assert!(
        started_events.iter().any(|event| {
            event["display_text"]
                .as_str()
                .is_some_and(|text| text.contains("正在整理毛球的宠物档案"))
        }),
        "SSE should contain runtime execution trace start text, got: {started_events:?}"
    );
    let completed_events = sse_event_data_all(text, "execution_trace_completed");
    assert!(
        completed_events.iter().any(|event| {
            event["display_text"]
                .as_str()
                .is_some_and(|text| text.contains("正在整理毛球的宠物档案"))
                && event["status"] == "completed"
        }),
        "SSE should contain runtime execution trace completion text, got: {completed_events:?}"
    );
    assert!(
        !text.contains("runtime_tool") && !text.contains("load_pet_identity_context"),
        "SSE should not expose internal runtime tool names, got: {text}"
    );
    assert!(
        started_events
            .iter()
            .chain(completed_events.iter())
            .all(|event| event.get("tool_name").is_none()),
        "execution trace should not expose internal tool names"
    );
    assert!(
        completed_events
            .iter()
            .all(|event| event.get("tool_call_id").is_none()),
        "execution trace should not expose internal tool call ids"
    );
    assert!(
        text.contains("已读取毛球档案，当前可以继续观察精神和食欲。"),
        "SSE should contain followup model final text, got: {text}"
    );
    assert!(
        text.contains("event: answer_completed"),
        "SSE should contain answer_completed event, got: {text}"
    );
}

fn assert_runtime_tool_diagnostics(events: &[maohuoban_diagnostics::DiagnosticEvent]) {
    assert_tool_gateway_diagnostic(events, "load_pet_identity_context", "success", None);
    assert!(events.iter().any(|event| {
        event.message == "ai.chat.tool_gateway.completed"
            && event.metadata["tool_name"] == json!("load_pet_identity_context")
            && event.metadata["fact_count"]
                .as_u64()
                .is_some_and(|count| count > 0)
            && event.metadata["citation_ids"].is_array()
    }));
}

fn assert_tool_gateway_diagnostic(
    events: &[maohuoban_diagnostics::DiagnosticEvent],
    tool_name: &str,
    policy_decision: &str,
    failure_code: Option<&str>,
) {
    assert!(events.iter().any(|event| {
        event.message == "ai.chat.tool_gateway.completed"
            && event.metadata["session_id"].is_string()
            && event.metadata["turn_id"].is_string()
            && event.metadata["message_id"].is_string()
            && event.metadata["tool_name"] == json!(tool_name)
            && event.metadata["policy_decision"] == json!(policy_decision)
            && event.metadata["duration_ms"].as_u64().is_some()
            && event.metadata["failure_code"] == json!(failure_code)
    }));
}

fn install_runtime_tool_test_diagnostics() -> Diagnostics {
    let root = std::env::temp_dir().join(format!(
        "maohuoban-ai-runtime-tool-diagnostics-{}",
        uuid::Uuid::new_v4()
    ));
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

fn install_runtime_tool_call_mocks_with_followup_delay<'a>(
    server: &'a MockServer,
    pet_id: &str,
    followup_delay: Duration,
) -> (Mock<'a>, Mock<'a>) {
    let first_body = runtime_tool_call_response_body(pet_id, "load_pet_identity_context");
    let first_mock = server.mock(|when, then| {
        when.method(httpmock::Method::POST)
            .path("/v1/chat/completions")
            .header("authorization", "Bearer contract-api-key")
            .matches(runtime_first_model_request)
            .body_contains("\"stream\":true")
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
            .delay(followup_delay)
            .header("content-type", "text/event-stream")
            .body(runtime_tool_followup_response_body());
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

fn request_body(req: &HttpMockRequest) -> String {
    req.body
        .as_ref()
        .map(|body| String::from_utf8_lossy(body).into_owned())
        .unwrap_or_default()
}

struct CapturingGatewayObserver {
    audits: Arc<Mutex<Vec<ToolExecutionAudit>>>,
}

#[async_trait]
impl AiToolGatewayObserver for CapturingGatewayObserver {
    async fn record(&self, audit: &ToolExecutionAudit) {
        self.audits.lock().expect("audits").push(audit.clone());
    }
}

fn test_gateway_context_with_audits(audits: Arc<Mutex<Vec<ToolExecutionAudit>>>) -> AiToolContext {
    AiToolContext {
        actor_user_id: Uuid::new_v4(),
        authorized_pet_id: Uuid::new_v4(),
        gateway_context: ToolGatewayExecutionContext {
            session_id: Some(Uuid::new_v4()),
            turn_id: Some(Uuid::new_v4()),
            message_id: Some(Uuid::new_v4()),
        },
        gateway_observer: Some(Arc::new(CapturingGatewayObserver { audits })),
    }
}

fn assert_recorded_audit(
    audits: &Arc<Mutex<Vec<ToolExecutionAudit>>>,
    tool_name: &str,
    policy_decision: &str,
    failure_code: Option<&str>,
) {
    let recorded = audits.lock().expect("audits");
    assert_eq!(recorded.len(), 1);
    assert_eq!(recorded[0].tool_name, tool_name);
    assert_eq!(recorded[0].policy_decision, policy_decision);
    assert_eq!(recorded[0].failure_code.as_deref(), failure_code);
    assert!(recorded[0].session_id.is_some());
    assert!(recorded[0].turn_id.is_some());
    assert!(recorded[0].message_id.is_some());
}

/// `FailedContractTool` 合同测试用失败工具
/// 核心职责：
/// - 固定返回结构化失败
/// - 验证 Tool Gateway 失败审计字段
struct FailedContractTool;

#[async_trait]
impl AiToolDefinition for FailedContractTool {
    fn name(&self) -> &'static str {
        "load_pet_current_diet_context"
    }

    fn description(&self) -> &'static str {
        "加载宠物饮食上下文"
    }

    fn parameters_schema(&self) -> serde_json::Value {
        json!({"type": "object", "properties": {}, "required": []})
    }

    fn metadata(&self) -> AiToolMetadata {
        AiToolMetadata {
            scope: "pet.diet.read".to_owned(),
            read_only: true,
            concurrency_safe: true,
            risk_level: AiToolRiskLevel::Low,
            requires_confirmation: false,
            domain_tags: vec!["diet".to_owned()],
            toolset: Toolset::PrivatePetContext,
            progress_text: ToolProgressText::default(),
            result_fact_schema: None,
        }
    }

    async fn execute(&self, _ctx: &AiToolContext, _args: &serde_json::Value) -> AiToolResult {
        AiToolResult::failed_with_failure(ToolFailure::new(
            "ai.provider_not_configured",
            false,
            "工具执行失败",
            "provider is not configured",
        ))
    }
}

/// `ConfirmationContractTool` 合同测试用确认工具
/// 核心职责：
/// - 固定返回确认需求
/// - 验证 Tool Gateway 确认审计字段
struct ConfirmationContractTool;

#[async_trait]
impl AiToolDefinition for ConfirmationContractTool {
    fn name(&self) -> &'static str {
        "create_pet_reminder"
    }

    fn description(&self) -> &'static str {
        "创建宠物提醒"
    }

    fn parameters_schema(&self) -> serde_json::Value {
        json!({
            "type": "object",
            "properties": {
                "title": { "type": "string" }
            },
            "required": ["title"]
        })
    }

    fn metadata(&self) -> AiToolMetadata {
        AiToolMetadata {
            scope: "pet.reminder.write".to_owned(),
            read_only: false,
            concurrency_safe: false,
            risk_level: AiToolRiskLevel::High,
            requires_confirmation: true,
            domain_tags: vec!["reminder".to_owned()],
            toolset: Toolset::Confirmation,
            progress_text: ToolProgressText::default(),
            result_fact_schema: None,
        }
    }

    async fn execute(&self, _ctx: &AiToolContext, _args: &serde_json::Value) -> AiToolResult {
        AiToolResult::requires_confirmation(AiToolConfirmationRequirement {
            confirmation_task_id: "confirmation-contract".to_owned(),
            tool_name: "create_pet_reminder".to_owned(),
            question_text: "是否确认创建提醒？".to_owned(),
            args: json!({ "title": "吃药" }),
        })
    }
}
