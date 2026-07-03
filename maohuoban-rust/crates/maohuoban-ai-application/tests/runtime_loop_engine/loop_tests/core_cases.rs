use std::sync::Arc;

use maohuoban_ai_application::ai::runtime::{AgentRuntimeLoopEngine, AgentSession};
use maohuoban_ai_application::ai::tools::ToolRegistry;
use maohuoban_ai_domain::ai::{
    AgentEvent, AgentId, AiConversationSurface, LlmChatResponse, LlmFinishReason, LlmMessage,
    LlmRole, LlmToolCall, LlmUsage,
};
use uuid::Uuid;

use super::super::echo_tool::EchoIdentityTool;
use super::super::helpers::{AUTHORIZED_PET_ID, test_tool_context, tool_call_response};
use super::super::provider::ScriptedProvider;
use super::super::workbenches::{
    final_response, json_final_response, private_pet_context_workbench, public_pet_domain_workbench,
};
use super::support::{EchoDietTool, LoopEchoTool, RetryOnceStreamProvider};

#[tokio::test]
async fn public_pet_domain_without_private_tools() {
    let provider = ScriptedProvider::new(vec![final_response()]);
    let mut registry = ToolRegistry::new();
    registry.register(EchoIdentityTool);

    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider.clone()),
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

    session
        .prompt_with_workbench("猫拉肚子一般要观察什么？", public_pet_domain_workbench())
        .await
        .expect("prompt public pet domain");

    let requests = provider.take_requests();
    assert_eq!(requests.len(), 1);
    assert!(
        requests[0].tools.is_empty(),
        "public pet domain without selected pet must not expose private tools"
    );
    assert!(
        requests[0].response_format.is_none(),
        "direct answer request should avoid DeepSeek JSON Output empty content risk"
    );
}

#[tokio::test]
async fn private_identity_question_uses_model_planned_fact_tool_before_answer() {
    let provider = ScriptedProvider::new(vec![
        tool_call_response(
            "load_pet_identity_context",
            &serde_json::json!({ "pet_id": AUTHORIZED_PET_ID }),
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

    let events = session
        .prompt_with_workbench("梅录多大了？", private_pet_context_workbench())
        .await
        .expect("prompt with private context");

    let names: Vec<&'static str> = events.iter().map(AgentEvent::event_name).collect();
    assert_eq!(
        names,
        vec![
            "turn_started",
            "model_call_started",
            "model_call_finished",
            "tool_started",
            "tool_finished",
            "message_delta",
            "model_call_started",
            "model_call_finished",
            "turn_finished",
        ],
        "private fact question should execute the model-planned evidence tool before final answer"
    );

    let requests = provider.take_requests();
    assert_eq!(requests.len(), 2);
    assert!(
        requests[0]
            .messages
            .iter()
            .all(|message| message.role != LlmRole::Tool),
        "initial model planning request must not contain tool-role history"
    );
    let tool_message = requests[1]
        .messages
        .iter()
        .find(|message| message.role == LlmRole::Tool)
        .expect("followup model request should include model-planned tool result");
    assert!(tool_message.content.contains("梅录"));
    assert!(tool_message.content.contains("420"));
}

#[tokio::test]
async fn followup_model_can_chain_second_tool_call_before_final_answer() {
    let provider = ScriptedProvider::new(vec![
        tool_call_response(
            "load_pet_identity_context",
            &serde_json::json!({ "pet_id": AUTHORIZED_PET_ID }),
        ),
        tool_call_response(
            "load_pet_current_diet_context",
            &serde_json::json!({ "pet_id": AUTHORIZED_PET_ID }),
        ),
        final_response(),
    ]);
    let mut registry = ToolRegistry::new();
    registry.register(EchoIdentityTool);
    registry.register(EchoDietTool);

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
            "梅录现在吃的粮和年龄一起告诉我",
            private_pet_context_workbench(),
        )
        .await
        .expect("prompt with chained fact tools");

    let names: Vec<&'static str> = events.iter().map(AgentEvent::event_name).collect();
    assert_eq!(
        names,
        vec![
            "turn_started",
            "model_call_started",
            "model_call_finished",
            "tool_started",
            "tool_finished",
            "model_call_started",
            "model_call_finished",
            "tool_started",
            "tool_finished",
            "message_delta",
            "model_call_started",
            "model_call_finished",
            "turn_finished",
        ],
        "runtime should allow followup model to issue another tool call before final answer"
    );

    let requests = provider.take_requests();
    assert_eq!(requests.len(), 3);
    let second_followup_tool_call = requests[1]
        .messages
        .iter()
        .find(|message| message.role == LlmRole::Tool)
        .expect("second request should include first tool result");
    assert!(second_followup_tool_call.content.contains("梅录"));
    let final_followup_tool_call = requests[2]
        .messages
        .iter()
        .find(|message| message.role == LlmRole::Tool)
        .expect("final request should include second tool result");
    assert!(final_followup_tool_call.content.contains("渴望六种鱼"));
    let termination_reason = events.iter().find_map(|event| match event {
        AgentEvent::TurnFinished {
            termination_reason, ..
        } => *termination_reason,
        _ => None,
    });
    assert_eq!(
        termination_reason,
        Some(maohuoban_ai_domain::ai::AgentTurnTerminationReason::ModelStop)
    );
}

#[tokio::test]
async fn runtime_stops_tool_chain_at_configured_round_limit() {
    let provider = ScriptedProvider::new(vec![
        tool_call_response("loop_echo_tool", &serde_json::json!({ "value": "r1" })),
        tool_call_response("loop_echo_tool", &serde_json::json!({ "value": "r2" })),
        tool_call_response("loop_echo_tool", &serde_json::json!({ "value": "r3" })),
        final_response(),
    ]);
    let mut registry = ToolRegistry::new();
    registry.register(LoopEchoTool);

    let mut engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider.clone()),
        Arc::new(registry),
        test_tool_context(Uuid::parse_str(AUTHORIZED_PET_ID).expect("pet id")),
        None,
    );
    engine.set_max_tool_rounds(2);

    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    let events = session
        .prompt_with_workbench("连续取证直到超出上限", private_pet_context_workbench())
        .await
        .expect("prompt with tool chain limit");

    let requests = provider.take_requests();
    assert_eq!(
        requests.len(),
        3,
        "runtime should stop after initial + 2 followup model rounds"
    );
    assert!(
        events
            .iter()
            .any(|event| matches!(event, AgentEvent::TurnFinished { .. })),
        "runtime should terminate the turn when max tool rounds is reached"
    );
    let termination_reason = events.iter().find_map(|event| match event {
        AgentEvent::TurnFinished {
            termination_reason, ..
        } => *termination_reason,
        _ => None,
    });
    assert_eq!(
        termination_reason,
        Some(maohuoban_ai_domain::ai::AgentTurnTerminationReason::MaxToolRounds)
    );
}

#[tokio::test]
async fn runtime_completes_answer_after_high_token_tool_planning() {
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
                id: "call_budget".to_owned(),
                name: "loop_echo_tool".to_owned(),
                arguments: serde_json::json!({ "value": "r1" }).to_string(),
            }],
            usage: LlmUsage {
                input_tokens: 3000,
                output_tokens: 302,
                total_tokens: 3302,
            },
            finish_reason: LlmFinishReason::ToolCalls,
            provider: "scripted".to_owned(),
            model: "primary".to_owned(),
        },
        LlmChatResponse {
            message: LlmMessage {
                role: LlmRole::Assistant,
                content: "梅录今年的生日已经过啦。".to_owned(),
                reasoning_content: None,
                tool_call_id: None,
                tool_calls: Vec::new(),
            },
            tool_calls: Vec::new(),
            usage: LlmUsage {
                input_tokens: 3000,
                output_tokens: 814,
                total_tokens: 3814,
            },
            finish_reason: LlmFinishReason::Stop,
            provider: "scripted".to_owned(),
            model: "primary".to_owned(),
        },
    ]);
    let mut registry = ToolRegistry::new();
    registry.register(LoopEchoTool);

    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider),
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
        .prompt_with_workbench("高 token 观测测试", private_pet_context_workbench())
        .await
        .expect("prompt with high token usage");

    let final_text = events.iter().find_map(|event| match event {
        AgentEvent::TurnFinished {
            final_text,
            termination_reason,
            ..
        } if *termination_reason
            == Some(maohuoban_ai_domain::ai::AgentTurnTerminationReason::ModelStop) =>
        {
            Some(final_text.as_str())
        }
        _ => None,
    });
    assert_eq!(
        final_text,
        Some("梅录今年的生日已经过啦。"),
        "runtime should deliver the model answer even when observed token usage is high"
    );
}

#[tokio::test]
async fn ambiguous_pet_context_text_is_sent_to_model_for_planning() {
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

    let events = session
        .prompt_with_workbench("它今天不舒服", private_pet_context_workbench())
        .await
        .expect("ambiguous private context text");

    let names: Vec<&'static str> = events.iter().map(AgentEvent::event_name).collect();
    assert_eq!(
        names,
        vec![
            "turn_started",
            "message_delta",
            "model_call_started",
            "model_call_finished",
            "turn_finished"
        ]
    );
    assert!(
        provider.take_requests().len() == 1,
        "runtime should let model decide whether to answer, ask, or call tools"
    );
}

#[tokio::test]
async fn provider_timeout_retries_same_model_step_before_failing_turn() {
    let provider = RetryOnceStreamProvider::new();
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

    let events = session
        .prompt_with_workbench("猫拉肚子一般要观察什么？", public_pet_domain_workbench())
        .await
        .expect("provider timeout should retry and then succeed");

    assert!(
        events
            .iter()
            .any(|event| matches!(event, AgentEvent::TurnFinished { .. })),
        "retry should allow turn to finish"
    );
    assert_eq!(
        provider.take_requests().len(),
        2,
        "timeout should retry the same model step once"
    );
}

#[tokio::test]
async fn agent_runtime_uses_answer_text_from_json_output() {
    let provider = ScriptedProvider::new(vec![json_final_response()]);
    let registry = ToolRegistry::new();

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

    let events = session.prompt("毛球今天怎么样").await.expect("prompt");
    let final_text = events.iter().find_map(|event| match event {
        AgentEvent::TurnFinished { final_text, .. } => Some(final_text.as_str()),
        _ => None,
    });

    assert_eq!(
        final_text,
        Some("毛球当前状态正常，可以继续观察精神和食欲。")
    );
}
