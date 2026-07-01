//! projection_tests ToolFactProjector 接入测试
//! 核心职责：
//! - 验证工具成功结果通过 ToolFactProjector 投影，隐藏内部字段
//! - 验证拒绝/失败结果投影为通用安全文案
//! - 验证 structured failure 回灌模型

use std::sync::Arc;

use maohuoban_ai_application::ai::runtime::{AgentRuntimeLoopEngine, AgentSession};
use maohuoban_ai_application::ai::tools::ToolRegistry;
use maohuoban_ai_domain::ai::{AgentId, AiConversationSurface};
use serde_json::json;
use uuid::Uuid;

use super::echo_tool::EchoIdentityTool;
use super::helpers::{AUTHORIZED_PET_ID, find_tool_message, test_tool_context, tool_call_response};
use super::provider::ScriptedProvider;
use super::workbenches::final_response;

/// 工具成功结果应通过 `ToolFactProjector` 投影，输出 `reference_ids` 并隐藏内部字段
#[tokio::test]
async fn tool_success_projects_reference_ids_and_hides_internal_fields() {
    let provider = ScriptedProvider::new(vec![
        tool_call_response(
            "load_pet_identity_context",
            json!({ "pet_id": AUTHORIZED_PET_ID }),
        ),
        final_response(),
    ]);
    let mut registry = ToolRegistry::new();
    registry.register(EchoIdentityTool);

    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider.clone()),
        Arc::new(registry),
        test_tool_context(Uuid::parse_str(AUTHORIZED_PET_ID).expect("pet id")),
        None,
    );

    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    session.prompt("毛球吃什么").await.expect("prompt");

    let requests = provider.take_requests();
    assert_eq!(requests.len(), 2, "should have initial + followup requests");

    let tool_message = find_tool_message(&requests);
    let content = &tool_message.content;

    assert!(
        content.contains("reference_ids"),
        "tool result should contain reference_ids, got: {content}"
    );
    assert!(
        !content.contains("current_staple"),
        "tool result should not expose internal key"
    );
    assert!(
        !content.contains("citation_id"),
        "tool result should not expose citation_id field"
    );
}

/// 工具拒绝结果应通过 `ToolFactProjector::project_denied` 投影为通用安全文案
#[tokio::test]
async fn tool_denied_projects_safe_message_not_raw_reason() {
    let provider = ScriptedProvider::new(vec![
        tool_call_response(
            "load_pet_identity_context",
            json!({ "pet_id": "22222222-2222-2222-2222-222222222222" }),
        ),
        final_response(),
    ]);
    let mut registry = ToolRegistry::new();
    registry.register(EchoIdentityTool);

    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider.clone()),
        Arc::new(registry),
        test_tool_context(Uuid::parse_str(AUTHORIZED_PET_ID).expect("pet id")),
        None,
    );

    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    session.prompt("毛球吃什么").await.expect("prompt");

    let requests = provider.take_requests();
    assert_eq!(requests.len(), 2);

    let tool_message = find_tool_message(&requests);
    let content = &tool_message.content;

    assert!(
        content.contains("工具无法执行"),
        "denied tool result should contain safe message"
    );
    assert!(
        !content.contains("pet not authorized"),
        "denied tool result should not expose raw reason"
    );
}

/// 工具失败结果应投影为结构化安全失败 JSON
#[tokio::test]
async fn tool_failed_projects_safe_message_not_raw_reason() {
    let provider = ScriptedProvider::new(vec![
        tool_call_response("load_pet_identity_context", json!({})),
        final_response(),
    ]);
    let mut registry = ToolRegistry::new();
    registry.register(EchoIdentityTool);

    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider.clone()),
        Arc::new(registry),
        test_tool_context(Uuid::parse_str(AUTHORIZED_PET_ID).expect("pet id")),
        None,
    );

    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    session.prompt("毛球吃什么").await.expect("prompt");

    let requests = provider.take_requests();
    assert_eq!(requests.len(), 2);

    let tool_message = find_tool_message(&requests);
    let content = &tool_message.content;

    assert!(
        content.contains("\"status\":\"failed\"")
            && content.contains("\"error_code\":\"tool.execution_failed\"")
            && content.contains("\"message\":\"missing pet_id\""),
        "failed tool result should contain structured safe failure payload"
    );
    assert!(!content.contains("internal_reason"));
}
