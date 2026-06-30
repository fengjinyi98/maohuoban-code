// rig_agent_run_engine Rig AgentRun 引擎测试
// 核心职责：
// - 验证 rig_poc 通过真实 provider 与 ToolRegistry 驱动工具闭环
// - 固定 Rig 只输出自有 AgentEvent 的边界

use std::pin::Pin;
use std::sync::{Arc, Mutex};

use async_trait::async_trait;
use futures_util::{StreamExt, stream::BoxStream};
use maohuoban_ai_application::ai::ports::LlmProvider;
use maohuoban_ai_application::ai::runtime::{
    AgentRuntimeEngineFactory, AgentRuntimeEngineInput, AgentRuntimeEngineMode, AgentSession,
};
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel, ToolRegistry,
};
use maohuoban_ai_domain::ai::{
    AgentEvent, AgentId, AgentToolStatus, AiConversationSurface, AiResult, LlmChatRequest,
    LlmChatResponse, LlmFinishReason, LlmMessage, LlmRole, LlmStreamEvent, LlmToolCall, LlmUsage,
    ToolProgressText, Toolset,
};
use uuid::Uuid;

#[derive(Clone)]
struct ScriptedRigProvider {
    requests: Arc<Mutex<Vec<LlmChatRequest>>>,
}

impl ScriptedRigProvider {
    fn new() -> Self {
        Self {
            requests: Arc::new(Mutex::new(Vec::new())),
        }
    }

    fn request_count(&self) -> usize {
        self.requests.lock().expect("requests").len()
    }

    fn request_at(&self, index: usize) -> LlmChatRequest {
        self.requests.lock().expect("requests")[index].clone()
    }
}

impl LlmProvider for ScriptedRigProvider {
    fn complete<'a>(
        &'a self,
        _request: &'a LlmChatRequest,
    ) -> Pin<Box<dyn Future<Output = AiResult<LlmChatResponse>> + Send + 'a>> {
        Box::pin(async {
            Err(maohuoban_ai_domain::ai::AiError::Infrastructure(
                "rig engine test uses stream".to_owned(),
            ))
        })
    }

    fn stream<'a>(&'a self, request: &'a LlmChatRequest) -> BoxStream<'a, AiResult<LlmStreamEvent>> {
        let request_index = {
            let mut requests = self.requests.lock().expect("requests");
            requests.push(request.clone());
            requests.len()
        };

        let events = if request_index == 1 {
            vec![
                Ok(LlmStreamEvent::ToolCall {
                    tool_call: LlmToolCall {
                        id: "call_rig_fact".to_owned(),
                        name: "test.pet_fact".to_owned(),
                        arguments: serde_json::json!({ "pet": "maomao" }).to_string(),
                    },
                }),
                Ok(LlmStreamEvent::Finish {
                    finish_reason: LlmFinishReason::ToolCalls,
                    usage: LlmUsage {
                        input_tokens: 10,
                        output_tokens: 4,
                        total_tokens: 14,
                    },
                }),
            ]
        } else {
            vec![
                Ok(LlmStreamEvent::Delta {
                    content: "Rig followup answer".to_owned(),
                }),
                Ok(LlmStreamEvent::Finish {
                    finish_reason: LlmFinishReason::Stop,
                    usage: LlmUsage {
                        input_tokens: 12,
                        output_tokens: 6,
                        total_tokens: 18,
                    },
                }),
            ]
        };

        futures_util::stream::iter(events).boxed()
    }
}

#[derive(Clone)]
struct RecordingTool {
    calls: Arc<Mutex<u32>>,
}

impl RecordingTool {
    fn new() -> Self {
        Self {
            calls: Arc::new(Mutex::new(0)),
        }
    }

    fn call_count(&self) -> u32 {
        *self.calls.lock().expect("tool calls")
    }
}

#[async_trait]
impl AiToolDefinition for RecordingTool {
    fn name(&self) -> &str {
        "test.pet_fact"
    }

    fn description(&self) -> &str {
        "读取测试宠物事实"
    }

    fn parameters_schema(&self) -> serde_json::Value {
        serde_json::json!({
            "type": "object",
            "properties": {
                "pet": { "type": "string" }
            },
            "required": ["pet"]
        })
    }

    fn metadata(&self) -> AiToolMetadata {
        AiToolMetadata {
            scope: "public.pet_fact".to_owned(),
            read_only: true,
            concurrency_safe: true,
            risk_level: AiToolRiskLevel::Low,
            requires_confirmation: false,
            domain_tags: vec!["test".to_owned()],
            toolset: Toolset::PublicPetDomain,
            progress_text: ToolProgressText::default(),
            result_fact_schema: None,
        }
    }

    async fn execute(&self, _ctx: &AiToolContext, _args: &serde_json::Value) -> AiToolResult {
        *self.calls.lock().expect("tool calls") += 1;
        AiToolResult::allowed(vec!["test-ref".to_owned()])
    }
}

fn build_input(provider: Arc<dyn LlmProvider>, registry: Arc<ToolRegistry>) -> AgentRuntimeEngineInput {
    AgentRuntimeEngineInput {
        provider,
        registry,
        tool_context: AiToolContext {
            actor_user_id: Uuid::new_v4(),
            authorized_pet_id: Uuid::new_v4(),
        },
        fact_package: None,
    }
}

fn event_names(events: &[AgentEvent]) -> Vec<&'static str> {
    events.iter().map(AgentEvent::event_name).collect()
}

fn final_text(events: &[AgentEvent]) -> Option<&str> {
    events.iter().find_map(|event| match event {
        AgentEvent::TurnFinished { final_text, .. } => Some(final_text.as_str()),
        _ => None,
    })
}

#[tokio::test]
async fn rig_poc_engine_drives_agent_run_with_provider_and_tool_registry() {
    let provider = ScriptedRigProvider::new();
    let observed_provider = provider.clone();
    let tool = RecordingTool::new();
    let observed_tool = tool.clone();
    let mut registry = ToolRegistry::new();
    registry.register(tool);

    let engine = AgentRuntimeEngineFactory::new(AgentRuntimeEngineMode::RigPoc)
        .build(build_input(Arc::new(provider), Arc::new(registry)));
    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    let events = session.prompt("查一下毛毛的状态").await.expect("rig run");

    assert_eq!(
        event_names(&events),
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
    assert_eq!(final_text(&events), Some("Rig followup answer"));
    assert_eq!(observed_provider.request_count(), 2);
    assert_eq!(observed_tool.call_count(), 1);

    let first_request = observed_provider.request_at(0);
    assert_eq!(first_request.tools.len(), 1);
    assert_eq!(first_request.tools[0].name, "test.pet_fact");

    let second_request = observed_provider.request_at(1);
    assert!(second_request.messages.iter().any(|message| matches!(
        message,
        LlmMessage {
            role: LlmRole::Tool,
            tool_call_id: Some(id),
            ..
        } if id == "call_rig_fact"
    )));
    assert!(events.iter().any(|event| matches!(
        event,
        AgentEvent::ToolFinished {
            tool_call_id,
            status: AgentToolStatus::Succeeded,
            ..
        } if tool_call_id == "call_rig_fact"
    )));
}
