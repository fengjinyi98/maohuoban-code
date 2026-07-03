use std::sync::Arc;

use maohuoban_ai_application::ai::runtime::{AgentRuntimeLoopEngine, AgentSession};
use maohuoban_ai_application::ai::tools::ToolRegistry;
use maohuoban_ai_domain::ai::{
    AgentEvent, AgentId, AiConversationSurface, LlmChatResponse, LlmFinishReason, LlmMessage,
    LlmRole, LlmToolCall, LlmUsage,
};
use serde_json::json;
use uuid::Uuid;

use super::super::helpers::{AUTHORIZED_PET_ID, test_tool_context, tool_call_response};
use super::super::provider::ScriptedProvider;
use super::super::workbenches::{
    final_response, private_pet_context_workbench, workbench_with_recent_history,
};
use super::support::{ConfirmTool, WriteObservationTool};

#[tokio::test]
async fn agent_runtime_reports_confirmation_requests() {
    let provider = ScriptedProvider::new(vec![LlmChatResponse {
        message: LlmMessage {
            role: LlmRole::Assistant,
            content: String::new(),
            reasoning_content: None,
            tool_call_id: None,
            tool_calls: Vec::new(),
        },
        tool_calls: vec![LlmToolCall {
            id: "call_1".to_owned(),
            name: "create_pet_reminder".to_owned(),
            arguments: json!({ "pet_id": "11111111-1111-1111-1111-111111111111" }).to_string(),
        }],
        usage: LlmUsage::default(),
        finish_reason: LlmFinishReason::ToolCalls,
        provider: "scripted".to_owned(),
        model: "primary".to_owned(),
    }]);
    let mut registry = ToolRegistry::new();
    registry.register(ConfirmTool);

    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider),
        Arc::new(registry),
        test_tool_context(Uuid::parse_str("11111111-1111-1111-1111-111111111111").expect("pet id")),
        None,
    );

    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    let events = session.prompt("给毛球建个提醒").await.expect("prompt");
    let names: Vec<&'static str> = events.iter().map(AgentEvent::event_name).collect();

    assert_eq!(
        names,
        vec![
            "turn_started",
            "model_call_started",
            "model_call_finished",
            "tool_started",
            "tool_finished",
            "needs_confirmation",
        ]
    );
}

#[tokio::test]
async fn unconfirmed_write_tool_stops_at_confirmation_without_final_answer() {
    let provider = ScriptedProvider::new(vec![
        tool_call_response(
            "write_pet_observation",
            &serde_json::json!({
                "pet_id": AUTHORIZED_PET_ID,
                "note": "体重 5kg"
            }),
        ),
        final_response(),
    ]);
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
        .prompt_with_workbench(
            "帮我直接把体重改成 5kg 不用问我",
            private_pet_context_workbench(),
        )
        .await
        .expect("prompt unconfirmed write");

    let names: Vec<&'static str> = events.iter().map(AgentEvent::event_name).collect();
    assert_eq!(
        names,
        vec![
            "turn_started",
            "model_call_started",
            "model_call_finished",
            "tool_started",
            "tool_finished",
            "needs_confirmation",
        ],
        "unconfirmed write must stop at confirmation boundary: {events:?}"
    );
    assert_eq!(
        provider.take_requests().len(),
        1,
        "runtime must not ask the model for a final answer after a confirmation request"
    );
    assert!(
        events
            .iter()
            .all(|event| !matches!(event, AgentEvent::TurnFinished { .. })),
        "confirmation boundary must not be projected as a completed turn: {events:?}"
    );
}

#[tokio::test]
async fn build_messages_includes_recent_conversation_history() {
    let provider = ScriptedProvider::new(vec![final_response()]);
    let registry = ToolRegistry::new();

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

    let workbench = workbench_with_recent_history();

    session
        .prompt_with_workbench("那要不要停罐头？", workbench)
        .await
        .expect("prompt with history");

    let requests = provider.take_requests();
    assert_eq!(requests.len(), 1);

    let messages = &requests[0].messages;

    let history_user = messages
        .iter()
        .find(|m| m.role == LlmRole::User && m.content == "豆包今天拉肚子怎么办");
    assert!(
        history_user.is_some(),
        "request must include previous user message"
    );

    let history_assistant = messages
        .iter()
        .find(|m| m.role == LlmRole::Assistant && m.content.contains("先观察精神和食欲"));
    assert!(
        history_assistant.is_some(),
        "request must include previous assistant message"
    );

    let current_msg = messages
        .iter()
        .find(|m| m.role == LlmRole::User && m.content == "那要不要停罐头？");
    assert!(
        current_msg.is_some(),
        "request must include current user message"
    );

    let history_index = messages
        .iter()
        .position(|m| m.role == LlmRole::User && m.content == "豆包今天拉肚子怎么办");
    let current_index = messages
        .iter()
        .position(|m| m.role == LlmRole::User && m.content == "那要不要停罐头？");
    assert!(
        history_index.expect("history index") < current_index.expect("current index"),
        "history must appear before current user message"
    );
}
