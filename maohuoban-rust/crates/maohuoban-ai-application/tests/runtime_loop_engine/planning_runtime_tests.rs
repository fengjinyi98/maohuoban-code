//! `planning_runtime_tests` WT08 Runtime 规划执行测试
//! 核心职责：
//! - 验证模型规划、ReplanPolicy 和规划诊断进入真实 Runtime 路径
//! - 固定工具确认、重规划和 step transition 的可观测行为

use std::sync::{Arc, LazyLock};

use maohuoban_ai_application::ai::runtime::{AgentRuntimeLoopEngine, AgentSession};
use maohuoban_ai_application::ai::tools::ToolRegistry;
use maohuoban_ai_domain::ai::{
    AgentEvent, AgentId, AgentTurnId, AiConversationSurface, LlmChatResponse, LlmFinishReason,
    LlmMessage, LlmRole, LlmToolCall, LlmUsage,
};
use serde_json::json;
use uuid::Uuid;

use super::echo_tool::EchoIdentityTool;
use super::helpers::{AUTHORIZED_PET_ID, test_tool_context, tool_call_response};
use super::provider::ScriptedProvider;
use super::workbenches::{
    final_response, private_pet_context_workbench, public_pet_domain_workbench,
    workbench_with_recent_history,
};
use planning::{
    ContextLimitProvider, FailingIdentityFactTool, WriteObservationTool, install_test_diagnostics,
};

#[path = "planning/mod.rs"]
mod planning;

static DIAGNOSTICS_TEST_LOCK: LazyLock<tokio::sync::Mutex<()>> =
    LazyLock::new(|| tokio::sync::Mutex::new(()));

#[tokio::test]
async fn write_like_text_without_tool_call_is_model_answer() {
    let provider = ScriptedProvider::new(vec![LlmChatResponse {
        message: LlmMessage {
            role: LlmRole::Assistant,
            content: "我需要先确认要写入的宠物和记录内容，然后再帮你记录。".to_owned(),
            reasoning_content: None,
            tool_call_id: None,
            tool_calls: Vec::new(),
        },
        tool_calls: Vec::new(),
        usage: LlmUsage::default(),
        finish_reason: LlmFinishReason::Stop,
        provider: "scripted".to_owned(),
        model: "primary".to_owned(),
    }]);
    let mut registry = ToolRegistry::new();
    registry.register(WriteObservationTool);

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

    let events = session
        .prompt_with_workbench("帮我记录今天拉稀", private_pet_context_workbench())
        .await
        .expect("write-like model answer");

    assert!(
        events
            .iter()
            .any(|event| matches!(event, AgentEvent::MessageDelta { .. })),
        "runtime should not suppress model text through keyword planning: {events:?}"
    );
    assert!(
        events
            .iter()
            .any(|event| matches!(event, AgentEvent::TurnFinished { .. })),
        "model-planned answer without tool call should finish normally: {events:?}"
    );
    assert_eq!(provider.take_requests().len(), 1);
}

#[tokio::test]
async fn tool_unauthorized_terminates_via_replan_policy_without_followup_model() {
    let provider = ScriptedProvider::new(vec![
        LlmChatResponse {
            message: LlmMessage {
                role: LlmRole::Assistant,
                content: String::new(),
                reasoning_content: None,
                tool_call_id: None,
                tool_calls: Vec::new(),
            },
            tool_calls: vec![LlmToolCall {
                id: "call_denied".to_owned(),
                name: "load_pet_identity_context".to_owned(),
                arguments: json!({
                    "pet_id": "22222222-2222-2222-2222-222222222222"
                })
                .to_string(),
            }],
            usage: LlmUsage::default(),
            finish_reason: LlmFinishReason::ToolCalls,
            provider: "scripted".to_owned(),
            model: "primary".to_owned(),
        },
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

    let events = session
        .prompt_with_workbench("猫拉肚子一般要观察什么？", public_pet_domain_workbench())
        .await
        .expect("tool unauthorized");

    assert_eq!(
        provider.take_requests().len(),
        1,
        "tool unauthorized should terminate before followup model: {events:?}"
    );
    assert!(
        events
            .iter()
            .any(|event| matches!(event, AgentEvent::TurnFailed { .. })),
        "tool unauthorized should produce failed turn: {events:?}"
    );
    assert!(
        events
            .iter()
            .all(|event| !matches!(event, AgentEvent::TurnFinished { .. })),
        "tool unauthorized must not complete as a normal answer: {events:?}"
    );
}

#[tokio::test]
async fn model_planned_evidence_failure_is_returned_to_followup_model() {
    let provider = ScriptedProvider::new(vec![
        tool_call_response(
            "load_pet_identity_context",
            &json!({ "pet_id": AUTHORIZED_PET_ID }),
        ),
        final_response(),
    ]);
    let mut registry = ToolRegistry::new();
    registry.register(FailingIdentityFactTool);

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

    let events = session
        .prompt_with_workbench("梅录多大了？", private_pet_context_workbench())
        .await
        .expect("evidence failure followup");

    assert!(
        events
            .iter()
            .any(|event| matches!(event, AgentEvent::TurnFinished { .. })),
        "model-planned evidence failure should be returned to followup model: {events:?}"
    );
    let requests = provider.take_requests();
    assert_eq!(requests.len(), 2);
    assert!(
        requests[1].messages.iter().any(|message| {
            message.role == LlmRole::Tool && message.content.contains("tool.internal_error")
        }),
        "followup model should receive structured tool failure: {requests:?}"
    );
}

#[tokio::test]
async fn tool_invalid_arguments_replans_to_clarification_without_followup_model() {
    let provider = ScriptedProvider::new(vec![
        LlmChatResponse {
            message: LlmMessage {
                role: LlmRole::Assistant,
                content: String::new(),
                reasoning_content: None,
                tool_call_id: None,
                tool_calls: Vec::new(),
            },
            tool_calls: vec![LlmToolCall {
                id: "call_invalid_args".to_owned(),
                name: "load_pet_identity_context".to_owned(),
                arguments: "{bad json".to_owned(),
            }],
            usage: LlmUsage::default(),
            finish_reason: LlmFinishReason::ToolCalls,
            provider: "scripted".to_owned(),
            model: "primary".to_owned(),
        },
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

    let events = session
        .prompt_with_workbench("猫拉肚子一般要观察什么？", public_pet_domain_workbench())
        .await
        .expect("tool invalid arguments");

    assert_eq!(
        provider.take_requests().len(),
        1,
        "invalid tool arguments should stop before followup model: {events:?}"
    );
    assert!(
        events
            .iter()
            .any(|event| matches!(event, AgentEvent::NeedsClarification { .. })),
        "invalid tool arguments should replan to clarification: {events:?}"
    );
    let termination_reason = events.iter().find_map(|event| match event {
        AgentEvent::TurnFinished {
            termination_reason, ..
        } => *termination_reason,
        _ => None,
    });
    assert_eq!(
        termination_reason,
        Some(maohuoban_ai_domain::ai::AgentTurnTerminationReason::AwaitingClarification),
        "clarification branch must terminate with awaiting_clarification"
    );
}

#[tokio::test]
async fn context_limit_provider_error_compresses_context_then_retries() {
    let _diagnostics_guard = DIAGNOSTICS_TEST_LOCK.lock().await;
    let diagnostics = install_test_diagnostics();
    let provider = ContextLimitProvider::new();
    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider.clone()),
        Arc::new(ToolRegistry::new()),
        test_tool_context(Uuid::parse_str(AUTHORIZED_PET_ID).expect("pet id")),
        None,
    );
    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    let events = session
        .prompt_with_workbench("那要不要停罐头？", workbench_with_recent_history())
        .await
        .expect("context limit should compress context and retry");

    assert!(
        events
            .iter()
            .any(|event| matches!(event, AgentEvent::TurnFinished { .. })),
        "context limit retry should finish turn: {events:?}"
    );
    let requests = provider.take_requests();
    assert_eq!(requests.len(), 2);
    assert!(
        requests[1].messages.len() < requests[0].messages.len(),
        "retry request should use compressed context: {requests:?}"
    );
    diagnostics.flush().expect("flush diagnostics");
    let events = diagnostics.read_events().expect("read diagnostics");
    assert!(
        events.iter().any(|event| {
            event.message == "ai.runtime.planning.decided"
                && event.metadata["replan_reason"] == json!("context_limit_exceeded")
        }),
        "context limit error should be recorded as replan decision: {events:?}"
    );
}

#[tokio::test]
async fn planning_diagnostics_records_real_step_transition() {
    let _diagnostics_guard = DIAGNOSTICS_TEST_LOCK.lock().await;
    let diagnostics = install_test_diagnostics();
    let provider = ScriptedProvider::new(vec![
        tool_call_response(
            "load_pet_identity_context",
            &json!({ "pet_id": AUTHORIZED_PET_ID }),
        ),
        final_response(),
    ]);
    let mut registry = ToolRegistry::new();
    registry.register(EchoIdentityTool);

    let session_id = Uuid::new_v4();
    let turn_id = AgentTurnId::new();
    let message_id = Uuid::new_v4();
    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider),
        Arc::new(registry),
        test_tool_context(Uuid::parse_str(AUTHORIZED_PET_ID).expect("pet id")),
        None,
    );
    let mut session = AgentSession::new(
        session_id,
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    session
        .prompt_with_workbench_turn_and_diagnostics_message_id(
            "梅录多大了？",
            private_pet_context_workbench(),
            turn_id,
            message_id,
        )
        .await
        .expect("prompt with diagnostics");

    diagnostics.flush().expect("flush diagnostics");
    let events = diagnostics.read_events().expect("read diagnostics");
    let planning_events: Vec<_> = events
        .iter()
        .filter(|event| {
            event.message == "ai.runtime.planning.decided"
                && event.metadata["session_id"] == json!(session_id)
                && event.metadata["turn_id"] == json!(turn_id.as_uuid())
                && event.metadata["message_id"] == json!(message_id)
        })
        .collect();

    assert!(
        planning_events.iter().any(|event| {
            event.metadata["current_step"] == json!("tool_read")
                && event.metadata["step_transition"] == json!("model_reason->tool_read")
        }),
        "planning diagnostics should include real step transition: {planning_events:?}"
    );
}
