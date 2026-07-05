#[path = "provider/provider_mocks.rs"]
mod provider_mocks;

use axum::http::StatusCode;
use futures_util::StreamExt;
use httpmock::MockServer;
use maohuoban_diagnostics::{
    CapturePolicy, CleanupPolicy, Diagnostics, DiagnosticsConfig, FileSegmentStore,
};
pub use provider_mocks::{
    install_chained_runtime_tool_call_mocks, install_runtime_tool_call_mocks,
    install_runtime_tool_call_mocks_with_followup_delay, runtime_initial_model_request,
};
use serde_json::{Value, json};
use std::time::Duration;
use tower::ServiceExt;

use crate::{authorized_json_request, response_json};

/// `create_pet` 创建流式 Runtime 工具合同测试宠物
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

/// `sse_event_data_all` 读取指定 SSE 事件的所有 JSON 数据
/// 核心职责：
/// - 从完整 SSE 文本中按事件名提取 data
/// - 为合同测试提供结构化事件断言输入
pub fn sse_event_data_all(text: &str, event_name: &str) -> Vec<Value> {
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
pub async fn read_sse_until_contains(
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

/// `spawn_runtime_tool_test_app` 创建 Runtime 工具合同测试应用
/// 核心职责：
/// - 将测试应用的 LLM provider 指向本地 mock server
/// - 固定模型配置以验证工具调用和回灌链路
pub async fn spawn_runtime_tool_test_app(
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

/// `assert_runtime_tool_stream_contract` 断言 Runtime 工具 SSE 合同
/// 核心职责：
/// - 验证执行轨迹、骨架卡片和最终回答事件
/// - 验证内部工具名和调用 ID 不暴露到 SSE
pub fn assert_runtime_tool_stream_contract(text: &str) {
    assert!(
        text.contains("event: execution_trace_completed")
            && text.contains("正在整理毛球的宠物档案"),
        "SSE should contain runtime execution trace completion text, got: {text}"
    );
    let content_block_deltas = sse_event_data_all(text, "content_block_delta");
    assert!(
        content_block_deltas.iter().any(|event| {
            event["content_blocks"].as_array().is_some_and(|blocks| {
                blocks.len() >= 2
                    && blocks[0]["type"] == json!("section_heading")
                    && blocks[1]["type"] == json!("pet_profile_card_skeleton")
            })
        }),
        "identity tool should emit pet profile skeleton content blocks, got: {content_block_deltas:?}"
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

/// `assert_runtime_tool_profile_blocks` 断言宠物档案 UI blocks
/// 核心职责：
/// - 验证 `answer_completed` 携带结构化 `content_blocks`
/// - 验证宠物身份工具结果投影为宠物档案卡片
pub fn assert_runtime_tool_profile_blocks(text: &str) {
    let completed_events = sse_event_data_all(text, "answer_completed");
    assert!(
        completed_events.iter().any(|event| {
            event["content_blocks"]
                .as_array()
                .is_some_and(|blocks| blocks.len() >= 2)
        }),
        "identity tool followup should include structured content blocks, got: {completed_events:?}"
    );
    assert!(
        completed_events.iter().any(|event| {
            event["content_blocks"][0]["type"] == json!("section_heading")
                && event["content_blocks"][1]["type"] == json!("pet_profile_card")
        }),
        "identity tool followup should project pet profile UI blocks, got: {completed_events:?}"
    );
}

/// `assert_runtime_tool_diagnostics` 断言 Runtime 工具诊断事件
/// 核心职责：
/// - 验证 Tool Gateway 完成事件
/// - 验证身份工具成功后进入资料卡渲染计划
pub fn assert_runtime_tool_diagnostics(events: &[maohuoban_diagnostics::DiagnosticEvent]) {
    assert_tool_gateway_diagnostic(events, "load_pet_identity_context", "success", None);
    assert!(events.iter().any(|event| {
        event.message == "ai.chat.tool_gateway.completed"
            && event.metadata["tool_name"] == json!("load_pet_identity_context")
            && event.metadata["fact_count"]
                .as_u64()
                .is_some_and(|count| count > 0)
            && event.metadata["citation_ids"].is_array()
    }));
    assert!(events.iter().any(|event| {
        event.message == "ai.chat.render_plan.selected"
            && event.metadata["allowed_block_kinds"]
                .as_array()
                .is_some_and(|kinds| kinds.iter().any(|kind| kind == "pet_profile_card"))
    }));
    assert!(events.iter().any(|event| {
        event.message == "ai.chat.content_blocks.emitted"
            && event.metadata["block_count"]
                .as_u64()
                .is_some_and(|count| count >= 2)
            && event.metadata["block_kinds"]
                .as_array()
                .is_some_and(|kinds| kinds.iter().any(|kind| kind == "pet_profile_card"))
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

/// `install_runtime_tool_test_diagnostics` 安装 Runtime 工具诊断运行时
/// 核心职责：
/// - 为单个测试用例创建隔离的诊断存储目录
/// - 固定测试诊断运行时的服务名和环境
pub fn install_runtime_tool_test_diagnostics() -> Diagnostics {
    let root = std::env::temp_dir().join(format!(
        "maohuoban-ai-runtime-tool-diagnostics-{}",
        uuid::Uuid::new_v4()
    ));
    let store = FileSegmentStore::new(root.join("segments"), 1024 * 1024).expect("store");
    Diagnostics::install(DiagnosticsConfig {
        service_name: "maohuoban-rust".to_owned(),
        environment: "test".to_owned(),
        privacy: maohuoban_diagnostics::PrivacyPolicy::default(),
        capture: CapturePolicy::default(),
        cleanup: CleanupPolicy::default(),
        store: Box::new(store),
    })
    .expect("install diagnostics")
}
