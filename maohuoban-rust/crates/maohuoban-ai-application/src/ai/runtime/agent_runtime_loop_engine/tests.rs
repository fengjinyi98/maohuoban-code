use std::sync::Arc;

use crate::ai::ports::FakeLlmProvider;
use crate::ai::runtime::LoopEngine;
use crate::ai::tools::{AiToolContext, ToolRegistry};
use maohuoban_ai_domain::ai::{
    AgentId, AgentSessionState, AiConversationSurface, LlmChatResponse, LlmFinishReason,
    LlmMessage, LlmRole, LlmStreamEvent, LlmUsage, LoopStep,
};

use super::AgentRuntimeLoopEngine;

#[tokio::test]
async fn whitespace_only_stream_returns_invalid_response_error() {
    let response = LlmChatResponse {
        message: LlmMessage {
            role: LlmRole::Assistant,
            content: String::new(),
            reasoning_content: None,
            tool_call_id: None,
            tool_calls: Vec::new(),
        },
        tool_calls: Vec::new(),
        usage: LlmUsage::default(),
        finish_reason: LlmFinishReason::Stop,
        provider: "fake".to_owned(),
        model: "fake".to_owned(),
    };
    let provider = Arc::new(FakeLlmProvider::new(
        response,
        vec![
            LlmStreamEvent::Delta {
                content: "                                               ".to_owned(),
            },
            LlmStreamEvent::Finish {
                finish_reason: LlmFinishReason::Stop,
                usage: LlmUsage {
                    input_tokens: 10,
                    output_tokens: 71,
                    total_tokens: 81,
                },
            },
        ],
    ));
    let registry = Arc::new(ToolRegistry::new());
    let tool_context = AiToolContext {
        actor_user_id: uuid::Uuid::new_v4(),
        authorized_pet_id: uuid::Uuid::nil(),
        gateway_context: crate::ai::tools::ToolGatewayExecutionContext::default(),
        gateway_observer: None,
    };
    let mut engine = AgentRuntimeLoopEngine::new(provider, registry, tool_context, None);
    let mut state = AgentSessionState::new(
        uuid::Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
    );
    state.begin_turn("我问你的第一个问题是什么".to_owned());

    let error = loop {
        match engine.next(&mut state).await {
            Ok(Some(LoopStep::MessageDelta { text })) => {
                panic!("空白流不应输出可见 delta: {text:?}");
            }
            Ok(Some(_)) => {}
            Ok(None) => panic!("空白流不应正常结束"),
            Err(error) => break error,
        }
    };

    assert_eq!(error.stable_code(), "ai.provider.invalid_response");
}
