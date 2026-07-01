//! guardrail_tests Guardrail 集成测试
//! 核心职责：
//! - 验证连续失败时 HardStop 终止 turn 并写入 Gateway 审计
//! - 验证 structured failure 的 error_code / recoverable 回灌模型
//! - 验证空事实 Success 连续触发 SoftReminder

use std::sync::{Arc, Mutex};

use maohuoban_ai_application::ai::runtime::{AgentRuntimeLoopEngine, AgentSession};
use maohuoban_ai_application::ai::tools::ToolRegistry;
use maohuoban_ai_domain::ai::{AgentEvent, AgentId, AiConversationSurface, LlmRole};
use serde_json::json;
use uuid::Uuid;

use super::always_fail_tool::AlwaysFailTool;
use super::empty_facts_tool::EmptyFactsTool;
use super::helpers::{
    AUTHORIZED_PET_ID, find_tool_message, multi_tool_call_response, test_tool_context,
    test_tool_context_with_audits, tool_call_response,
};
use super::provider::ScriptedProvider;
use super::workbenches::final_response;

/// guardrail 在同工具连续失败 3 次时应 `HardStop` 终止 turn
#[tokio::test]
async fn guardrail_hard_stops_repeated_tool_failures() {
    let provider = ScriptedProvider::new(vec![multi_tool_call_response(
        "load_pet_identity_context",
        3,
    )]);
    let mut registry = ToolRegistry::new();
    registry.register(AlwaysFailTool);
    let audits = Arc::new(Mutex::new(Vec::new()));

    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider),
        Arc::new(registry),
        test_tool_context_with_audits(
            Uuid::parse_str(AUTHORIZED_PET_ID).expect("pet id"),
            audits.clone(),
        ),
        None,
    );

    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    let events = session.prompt("毛球吃什么").await.expect("prompt");

    let has_turn_failed = events
        .iter()
        .any(|event| matches!(event, AgentEvent::TurnFailed { .. }));
    assert!(
        has_turn_failed,
        "guardrail hard stop should produce TurnFailed event"
    );
    let audits = audits.lock().expect("audits");
    assert!(
        audits.iter().any(|audit| audit.policy_decision == "failed"
            && audit.failure_code.as_deref() == Some("guardrail.hard_stop")
            && audit.tool_name == "load_pet_identity_context"),
        "guardrail hard stop should produce Tool Gateway audit"
    );
}

/// 结构化失败信息应回灌到模型消息，包含 `error_code` 和 `recoverable`
#[tokio::test]
async fn structured_failure_propagates_to_model_message() {
    let provider = ScriptedProvider::new(vec![
        tool_call_response("load_pet_identity_context", json!({})),
        final_response(),
    ]);
    let mut registry = ToolRegistry::new();
    registry.register(AlwaysFailTool);

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

    assert!(content.contains("error_code"));
    assert!(content.contains("recoverable"));
    assert!(content.contains("tool.internal_error"));
}

/// 空事实成功工具连续调用 3 次后，guardrail 应检测到无进展并触发 `SoftReminder`
#[tokio::test]
async fn empty_facts_tool_triggers_soft_reminder_with_valid_json() {
    let provider = ScriptedProvider::new(vec![
        multi_tool_call_response("load_pet_identity_context", 3),
        final_response(),
    ]);
    let mut registry = ToolRegistry::new();
    registry.register(EmptyFactsTool);

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
    assert!(requests.len() >= 2);

    let tool_messages: Vec<&maohuoban_ai_domain::ai::LlmMessage> = requests
        .iter()
        .flat_map(|req| req.messages.iter())
        .filter(|m| m.role == LlmRole::Tool)
        .collect();
    assert!(!tool_messages.is_empty());

    // 每个 tool message 必须是合法 JSON
    for msg in &tool_messages {
        serde_json::from_str::<serde_json::Value>(&msg.content)
            .unwrap_or_else(|e| panic!("tool message must be valid JSON: {e}"));
    }

    let has_reminder = tool_messages
        .iter()
        .any(|msg| msg.content.contains("_guardrail_reminder"));
    assert!(
        has_reminder,
        "at least one tool message should contain _guardrail_reminder"
    );
}
