use std::time::Duration;

use futures_util::StreamExt;
use maohuoban_ai_application::ai::runtime::AgentSession;
use maohuoban_ai_application::ai::tools::ToolRegistry;
use maohuoban_ai_domain::ai::{AgentEvent, AgentId, AiConversationSurface, LlmRole};
use uuid::Uuid;

use super::support::{
    EchoDietTool, EchoIdentityTool, StreamingScriptedProvider, diet_tool_response, final_response,
    final_response_with_text, private_pet_workbench, runtime_engine, tool_response,
};

#[tokio::test]
async fn agent_session_stream_yields_tool_progress_before_followup_model_finishes() {
    let provider = StreamingScriptedProvider::with_delays(
        vec![tool_response(), final_response()],
        vec![Duration::ZERO, Duration::from_secs(5)],
    );
    let mut registry = ToolRegistry::new();
    registry.register(EchoIdentityTool::immediate());

    let engine = runtime_engine(provider, registry);
    let session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );
    let mut stream = Box::pin(
        session
            .into_prompt_stream_with_workbench("查看毛球档案".to_owned(), private_pet_workbench()),
    );

    let mut names = Vec::new();
    let tool_finished = tokio::time::timeout(Duration::from_millis(200), async {
        loop {
            let event = stream
                .next()
                .await
                .expect("runtime stream event")
                .expect("runtime event ok");
            names.push(event.event_name());
            if event.event_name() == "tool_finished" {
                break;
            }
        }
    })
    .await;

    assert!(
        tool_finished.is_ok(),
        "tool progress should arrive before delayed followup model completes, got {names:?}"
    );
    assert_eq!(
        names,
        vec![
            "turn_started",
            "model_call_started",
            "model_call_finished",
            "tool_started",
            "tool_finished",
        ]
    );

    let followup_event = tokio::time::timeout(Duration::from_millis(50), stream.next()).await;
    assert!(
        followup_event.is_err(),
        "followup model event should still be pending while provider stream is delayed"
    );
}

#[tokio::test]
async fn agent_session_stream_yields_tool_started_before_delayed_tool_finishes() {
    let provider = StreamingScriptedProvider::new(vec![tool_response(), final_response()]);
    let mut registry = ToolRegistry::new();
    registry.register(EchoIdentityTool::delayed(Duration::from_secs(5)));

    let engine = runtime_engine(provider, registry);
    let session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );
    let mut stream = Box::pin(
        session
            .into_prompt_stream_with_workbench("查看毛球档案".to_owned(), private_pet_workbench()),
    );

    let mut names = Vec::new();
    let tool_started = tokio::time::timeout(Duration::from_millis(200), async {
        loop {
            let event = stream
                .next()
                .await
                .expect("runtime stream event")
                .expect("runtime event ok");
            names.push(event.event_name());
            if event.event_name() == "tool_started" {
                break;
            }
        }
    })
    .await;

    assert!(
        tool_started.is_ok(),
        "tool_started should arrive before delayed tool execute finishes, got {names:?}"
    );
    assert_eq!(
        names,
        vec![
            "turn_started",
            "model_call_started",
            "model_call_finished",
            "tool_started",
        ]
    );

    let tool_finished = tokio::time::timeout(Duration::from_millis(50), stream.next()).await;
    assert!(
        tool_finished.is_err(),
        "tool_finished should still be pending while delayed tool is executing"
    );
}

#[tokio::test]
async fn agent_runtime_executes_tool_loop_with_streaming_followup() {
    let provider = StreamingScriptedProvider::new(vec![tool_response(), final_response()]);
    let mut registry = ToolRegistry::new();
    registry.register(EchoIdentityTool::immediate());

    let engine = runtime_engine(provider.clone(), registry);
    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    let events = session
        .prompt_with_workbench("查看毛球档案", private_pet_workbench())
        .await
        .expect("prompt");
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
        ]
    );

    let requests = provider.take_requests();
    assert_eq!(requests.len(), 2);
    assert!(requests.iter().all(|request| request.stream));
    assert_eq!(requests[0].tools.len(), 1);
    assert_eq!(requests[0].tools[0].name, "load_pet_identity_context");
    assert!(
        requests[0].response_format.is_none(),
        "initial tool planning request must keep native tool calling unconstrained"
    );
    assert_eq!(
        requests[1].tools.len(),
        1,
        "followup request must keep tool visibility so model can continue chaining tools"
    );
    assert!(
        requests[1].response_format.is_none(),
        "followup final answer request should avoid DeepSeek JSON Output empty content risk"
    );
    assert_eq!(
        requests[1].diagnostics_correlation.tool_call_id.as_deref(),
        Some("call_1"),
        "followup request diagnostics must correlate back to the executed tool call"
    );
}

#[tokio::test]
async fn agent_runtime_streams_followup_deltas_after_tool_fact_package_is_available() {
    let provider = StreamingScriptedProvider::new(vec![
        tool_response(),
        final_response_with_text("第一段"),
        final_response_with_text("第二段"),
    ]);
    let mut registry = ToolRegistry::new();
    registry.register(EchoIdentityTool::immediate());

    let engine = runtime_engine(provider, registry);
    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    let events = session
        .prompt_with_workbench("查看毛球档案", private_pet_workbench())
        .await
        .expect("prompt");
    let deltas: Vec<&str> = events
        .iter()
        .filter_map(|event| match event {
            AgentEvent::MessageDelta { text, .. } => Some(text.as_str()),
            _ => None,
        })
        .collect();

    assert_eq!(
        deltas,
        vec!["第一段"],
        "followup visible text should stream after a read tool returns facts"
    );
}

#[tokio::test]
async fn agent_runtime_streaming_followup_can_chain_second_tool_call_before_final_answer() {
    let provider = StreamingScriptedProvider::new(vec![
        tool_response(),
        diet_tool_response(),
        final_response(),
    ]);
    let mut registry = ToolRegistry::new();
    registry.register(EchoIdentityTool::immediate());
    registry.register(EchoDietTool);

    let engine = runtime_engine(provider.clone(), registry);
    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    let events = session
        .prompt_with_workbench("查看毛球年龄和当前主粮", private_pet_workbench())
        .await
        .expect("prompt");
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
        ]
    );

    let requests = provider.take_requests();
    assert_eq!(requests.len(), 3);
    assert!(
        requests[1]
            .tools
            .iter()
            .any(|tool| tool.name == "load_pet_current_diet_context")
    );
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
async fn agent_runtime_pairs_assistant_tool_call_message_before_tool_results() {
    let provider = StreamingScriptedProvider::new(vec![tool_response(), final_response()]);
    let mut registry = ToolRegistry::new();
    registry.register(EchoIdentityTool::immediate());

    let engine = runtime_engine(provider.clone(), registry);
    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    session
        .prompt_with_workbench("查看毛球档案", private_pet_workbench())
        .await
        .expect("prompt");

    let requests = provider.take_requests();
    let followup_messages = &requests.get(1).expect("followup model request").messages;
    let assistant_tool_call_index = followup_messages
        .iter()
        .position(|message| {
            message.role == LlmRole::Assistant
                && message
                    .tool_calls
                    .iter()
                    .any(|tool_call| tool_call.id == "call_1")
        })
        .expect("assistant tool_call message should be replayed");
    let tool_result_index = followup_messages
        .iter()
        .position(|message| {
            message.role == LlmRole::Tool && message.tool_call_id.as_deref() == Some("call_1")
        })
        .expect("tool result message should be present");

    assert!(
        assistant_tool_call_index < tool_result_index,
        "assistant tool_calls message must precede matching tool result message"
    );

    let tool_result_content = &followup_messages[tool_result_index].content;
    assert!(tool_result_content.contains("渴望六种鱼"));
    assert!(
        !tool_result_content.contains("current_staple"),
        "tool result content sent back to model must not expose internal fact keys"
    );
}

#[tokio::test]
async fn agent_session_refreshes_diagnostics_message_id_per_turn() {
    let provider = StreamingScriptedProvider::new(vec![final_response(), final_response()]);
    let engine = runtime_engine(provider.clone(), ToolRegistry::new());
    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );
    let first_message_id =
        Uuid::parse_str("11111111-2222-3333-4444-555555555555").expect("first message id");
    let second_message_id =
        Uuid::parse_str("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee").expect("second message id");

    session
        .prompt_with_diagnostics_message_id("第一轮", first_message_id)
        .await
        .expect("first prompt");
    session
        .prompt_with_diagnostics_message_id("第二轮", second_message_id)
        .await
        .expect("second prompt");

    let requests = provider.take_requests();
    assert_eq!(requests.len(), 2);
    assert_eq!(
        requests[0].diagnostics_correlation.message_id,
        Some(first_message_id)
    );
    assert_eq!(
        requests[1].diagnostics_correlation.message_id,
        Some(second_message_id)
    );
}
