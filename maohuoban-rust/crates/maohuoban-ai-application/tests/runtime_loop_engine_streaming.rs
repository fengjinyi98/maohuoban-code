// runtime_loop_engine_streaming Agent Runtime 流式模型闭环测试
// 核心职责：
// - 验证工具调用后的二次模型也走 Provider stream
// - 验证工具进度先于延迟的二次模型内容到达

use std::collections::VecDeque;
use std::sync::{Arc, Mutex};
use std::time::Duration;

use async_trait::async_trait;
use futures_util::StreamExt;
use maohuoban_ai_application::ai::ports::LlmProvider;
use maohuoban_ai_application::ai::runtime::{AgentRuntimeLoopEngine, AgentSession};
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel, ToolRegistry,
};
use maohuoban_ai_domain::ai::{
    AgentEvent, AgentId, AiConversationSurface, AiFactEntry, AiFactStrength, LlmChatRequest,
    LlmChatResponse, LlmFinishReason, LlmMessage, LlmRole, LlmStreamEvent, LlmToolCall, LlmUsage,
};
use serde_json::json;
use uuid::Uuid;

#[derive(Clone)]
struct StreamingScriptedProvider {
    requests: Arc<Mutex<Vec<LlmChatRequest>>>,
    responses: Arc<Mutex<VecDeque<LlmChatResponse>>>,
    delays: Arc<Mutex<VecDeque<Duration>>>,
}

impl StreamingScriptedProvider {
    fn new(responses: Vec<LlmChatResponse>) -> Self {
        Self::with_delays(responses, Vec::new())
    }

    fn with_delays(responses: Vec<LlmChatResponse>, delays: Vec<Duration>) -> Self {
        Self {
            requests: Arc::new(Mutex::new(Vec::new())),
            responses: Arc::new(Mutex::new(VecDeque::from(responses))),
            delays: Arc::new(Mutex::new(VecDeque::from(delays))),
        }
    }

    fn take_requests(&self) -> Vec<LlmChatRequest> {
        self.requests.lock().expect("requests").clone()
    }
}

impl LlmProvider for StreamingScriptedProvider {
    fn complete<'a>(
        &'a self,
        _request: &'a LlmChatRequest,
    ) -> std::pin::Pin<
        Box<
            dyn std::future::Future<Output = maohuoban_ai_domain::ai::AiResult<LlmChatResponse>>
                + Send
                + 'a,
        >,
    > {
        Box::pin(async {
            Err(maohuoban_ai_domain::ai::AiError::Infrastructure(
                "streaming provider should not use complete".to_owned(),
            ))
        })
    }

    fn stream<'a>(
        &'a self,
        request: &'a LlmChatRequest,
    ) -> futures_util::stream::BoxStream<
        'a,
        maohuoban_ai_domain::ai::AiResult<maohuoban_ai_domain::ai::LlmStreamEvent>,
    > {
        self.requests
            .lock()
            .expect("requests")
            .push(request.clone());
        let delay = self
            .delays
            .lock()
            .expect("delays")
            .pop_front()
            .unwrap_or_default();
        let events = self
            .responses
            .lock()
            .expect("responses")
            .pop_front()
            .map_or_else(
                || {
                    vec![Err(maohuoban_ai_domain::ai::AiError::Infrastructure(
                        "missing scripted response".to_owned(),
                    ))]
                },
                response_to_stream_events,
            );

        async_stream::stream! {
            if !delay.is_zero() {
                tokio::time::sleep(delay).await;
            }
            for event in events {
                yield event;
            }
        }
        .boxed()
    }
}

fn response_to_stream_events(
    response: LlmChatResponse,
) -> Vec<maohuoban_ai_domain::ai::AiResult<LlmStreamEvent>> {
    let mut events = Vec::new();
    for tool_call in response.tool_calls {
        events.push(Ok(LlmStreamEvent::ToolCall { tool_call }));
    }
    if !response.message.content.is_empty() {
        events.push(Ok(LlmStreamEvent::Delta {
            content: response.message.content,
        }));
    }
    events.push(Ok(LlmStreamEvent::Finish {
        finish_reason: response.finish_reason,
        usage: response.usage,
    }));
    events
}

struct EchoIdentityTool;

#[async_trait]
impl AiToolDefinition for EchoIdentityTool {
    fn name(&self) -> &'static str {
        "load_pet_identity_context"
    }

    fn description(&self) -> &'static str {
        "加载宠物身份上下文"
    }

    fn parameters_schema(&self) -> serde_json::Value {
        json!({
            "type": "object",
            "properties": {
                "pet_id": { "type": "string", "format": "uuid" }
            },
            "required": ["pet_id"]
        })
    }

    fn metadata(&self) -> AiToolMetadata {
        AiToolMetadata {
            scope: "pet.identity.read".to_owned(),
            read_only: true,
            concurrency_safe: true,
            risk_level: AiToolRiskLevel::Low,
            requires_confirmation: false,
            domain_tags: vec!["identity".to_owned()],
        }
    }

    async fn execute(&self, ctx: &AiToolContext, args: &serde_json::Value) -> AiToolResult {
        let pet_id = args
            .get("pet_id")
            .and_then(|value| value.as_str())
            .and_then(|value| Uuid::parse_str(value).ok());

        match pet_id {
            Some(id) if id == ctx.authorized_pet_id => AiToolResult::allowed_with_facts(
                vec![AiFactEntry {
                    key: "current_staple".to_owned(),
                    value: "渴望六种鱼".to_owned(),
                    strength: AiFactStrength::Strong,
                    citation_id: Some(Uuid::new_v4()),
                }],
                Vec::new(),
            ),
            Some(_) => AiToolResult::denied("pet not authorized"),
            None => AiToolResult::failed("missing pet_id"),
        }
    }
}

#[tokio::test]
async fn agent_session_stream_yields_tool_progress_before_followup_model_finishes() {
    let provider = StreamingScriptedProvider::with_delays(
        vec![tool_response(), final_response()],
        vec![Duration::ZERO, Duration::from_secs(5)],
    );
    let mut registry = ToolRegistry::new();
    registry.register(EchoIdentityTool);

    let engine = runtime_engine(provider, registry);
    let session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );
    let mut stream = Box::pin(session.into_prompt_stream("查看毛球档案".to_owned()));

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
async fn agent_runtime_executes_tool_loop_with_streaming_followup() {
    let provider = StreamingScriptedProvider::new(vec![tool_response(), final_response()]);
    let mut registry = ToolRegistry::new();
    registry.register(EchoIdentityTool);

    let engine = runtime_engine(provider.clone(), registry);
    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    let events = session.prompt("查看毛球档案").await.expect("prompt");
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
    assert!(
        requests[1].tools.is_empty(),
        "followup final answer request should not expose private tools again"
    );
    assert_eq!(
        requests[1].response_format,
        Some(json!({ "type": "json_object" })),
        "followup final answer request should opt into structured JSON output"
    );
}

#[tokio::test]
async fn agent_runtime_pairs_assistant_tool_call_message_before_tool_results() {
    let provider = StreamingScriptedProvider::new(vec![tool_response(), final_response()]);
    let mut registry = ToolRegistry::new();
    registry.register(EchoIdentityTool);

    let engine = runtime_engine(provider.clone(), registry);
    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    session.prompt("查看毛球档案").await.expect("prompt");

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

fn runtime_engine(
    provider: StreamingScriptedProvider,
    registry: ToolRegistry,
) -> AgentRuntimeLoopEngine {
    AgentRuntimeLoopEngine::new(
        Arc::new(provider),
        Arc::new(registry),
        AiToolContext {
            actor_user_id: Uuid::new_v4(),
            authorized_pet_id: Uuid::parse_str("11111111-1111-1111-1111-111111111111")
                .expect("pet id"),
        },
        None,
    )
}

fn tool_response() -> LlmChatResponse {
    LlmChatResponse {
        message: LlmMessage {
            role: LlmRole::Assistant,
            content: String::new(),
            tool_call_id: None,
            tool_calls: Vec::new(),
        },
        tool_calls: vec![LlmToolCall {
            id: "call_1".to_owned(),
            name: "load_pet_identity_context".to_owned(),
            arguments: json!({
                "pet_id": "11111111-1111-1111-1111-111111111111"
            })
            .to_string(),
        }],
        usage: LlmUsage {
            input_tokens: 8,
            output_tokens: 2,
            total_tokens: 10,
        },
        finish_reason: LlmFinishReason::ToolCalls,
        provider: "scripted".to_owned(),
        model: "primary".to_owned(),
    }
}

fn final_response() -> LlmChatResponse {
    LlmChatResponse {
        message: LlmMessage {
            role: LlmRole::Assistant,
            content: "毛球当前状态正常".to_owned(),
            tool_call_id: None,
            tool_calls: Vec::new(),
        },
        tool_calls: vec![],
        usage: LlmUsage {
            input_tokens: 12,
            output_tokens: 6,
            total_tokens: 18,
        },
        finish_reason: LlmFinishReason::Stop,
        provider: "scripted".to_owned(),
        model: "primary".to_owned(),
    }
}
