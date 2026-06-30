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
    AgentCapability, AgentDefinition, AgentEvent, AgentId, AgentSessionWorkbench, AgentToolStatus,
    AiConversationSurface, AiFactEntry, AiFactStrength, AiResult, CapabilityCatalog,
    CapabilityDomain, ContextPack, ContextPetSummary, LlmChatRequest, LlmChatResponse,
    LlmFinishReason, LlmMessage, LlmRole, LlmStreamEvent, LlmToolCall, LlmUsage, MemoryPack,
    ModelLabel, ToolFactField, ToolFactSchema, ToolProgressText, Toolset,
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

    fn stream<'a>(
        &'a self,
        request: &'a LlmChatRequest,
    ) -> BoxStream<'a, AiResult<LlmStreamEvent>> {
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
                    content: "<think>internal rig reasoning</think>{\"answer_text\":\"Rig followup answer\",\"json_draft\":{\"internal\":true}}".to_owned(),
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

#[derive(Clone)]
struct FinalOnlyRigProvider {
    requests: Arc<Mutex<Vec<LlmChatRequest>>>,
}

impl FinalOnlyRigProvider {
    fn new() -> Self {
        Self {
            requests: Arc::new(Mutex::new(Vec::new())),
        }
    }

    fn requests(&self) -> Vec<LlmChatRequest> {
        self.requests.lock().expect("requests").clone()
    }
}

impl LlmProvider for FinalOnlyRigProvider {
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

    fn stream<'a>(
        &'a self,
        request: &'a LlmChatRequest,
    ) -> BoxStream<'a, AiResult<LlmStreamEvent>> {
        self.requests
            .lock()
            .expect("requests")
            .push(request.clone());
        futures_util::stream::iter(vec![
            Ok(LlmStreamEvent::Delta {
                content: "梅录出生至今 420 天。".to_owned(),
            }),
            Ok(LlmStreamEvent::Finish {
                finish_reason: LlmFinishReason::Stop,
                usage: LlmUsage::default(),
            }),
        ])
        .boxed()
    }
}

struct PrivateIdentityTool;

#[async_trait]
impl AiToolDefinition for PrivateIdentityTool {
    fn name(&self) -> &'static str {
        "load_pet_identity_context"
    }

    fn description(&self) -> &'static str {
        "读取目标宠物基础档案事实"
    }

    fn parameters_schema(&self) -> serde_json::Value {
        serde_json::json!({
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
            toolset: Toolset::PrivatePetContext,
            progress_text: ToolProgressText::default(),
            result_fact_schema: Some(ToolFactSchema {
                fact_keys: vec!["pet_identity.world_days".to_owned()],
                description: "宠物基础档案事实".to_owned(),
                natural_language_summary: "可回答宠物多大了、几岁了、来到世界多少天等问题"
                    .to_owned(),
                fields: vec![ToolFactField {
                    key: "pet_identity.world_days".to_owned(),
                    label: "年龄/出生至今天数".to_owned(),
                    meaning: "宠物从出生到今天经过的天数，可用于回答多大了、几岁了".to_owned(),
                    example_queries: vec!["多大了".to_owned(), "几岁了".to_owned()],
                }],
            }),
        }
    }

    async fn execute(&self, _ctx: &AiToolContext, _args: &serde_json::Value) -> AiToolResult {
        AiToolResult::allowed_with_facts(
            vec![
                AiFactEntry {
                    key: "pet_identity.name".to_owned(),
                    value: "梅录".to_owned(),
                    strength: AiFactStrength::Strong,
                    citation_id: None,
                },
                AiFactEntry {
                    key: "pet_identity.world_days".to_owned(),
                    value: "420".to_owned(),
                    strength: AiFactStrength::Strong,
                    citation_id: None,
                },
            ],
            Vec::new(),
        )
    }
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
    fn name(&self) -> &'static str {
        "test.pet_fact"
    }

    fn description(&self) -> &'static str {
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

fn build_input(
    provider: Arc<dyn LlmProvider>,
    registry: Arc<ToolRegistry>,
) -> AgentRuntimeEngineInput {
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

fn private_pet_context_workbench() -> AgentSessionWorkbench {
    AgentSessionWorkbench {
        agent_definition: AgentDefinition {
            agent_id: AgentId::main_pet_care_agent(),
            name: "毛球".to_owned(),
            purpose: "宠物垂直照护与用户宠物私域助手".to_owned(),
            default_model_label: ModelLabel::Primary,
            capability_domains: vec![
                CapabilityDomain::PublicPetDomain,
                CapabilityDomain::PrivatePetContext,
            ],
        },
        capability_catalog: CapabilityCatalog {
            capabilities: vec![AgentCapability {
                code: "private_pet_context".to_owned(),
                domain: CapabilityDomain::PrivatePetContext,
                title: "授权宠物私域上下文".to_owned(),
                when_to_use: "用户询问已选宠物的档案、年龄、生日、陪伴、饮食或记录事实时使用"
                    .to_owned(),
                requires_private_context: true,
            }],
        },
        context_pack: ContextPack {
            surface: AiConversationSurface::HomePrivate,
            locale: "zh-Hans".to_owned(),
            timezone: "Asia/Shanghai".to_owned(),
            selected_pet: Some(ContextPetSummary {
                pet_id: Uuid::parse_str("11111111-1111-1111-1111-111111111111").expect("pet id"),
                name: "梅录".to_owned(),
                species: "cat".to_owned(),
            }),
            authorized_pets: Vec::new(),
            session_summary: None,
        },
        memory_pack: MemoryPack {
            entries: Vec::new(),
        },
        recent_conversation_pack: None,
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
    assert!(first_request.stream);
    assert_eq!(first_request.tools.len(), 1);
    assert_eq!(first_request.tools[0].name, "test.pet_fact");
    assert!(
        first_request.response_format.is_none(),
        "Rig + DeepSeek compatible tool planning must not force JSON output"
    );

    let second_request = observed_provider.request_at(1);
    assert!(second_request.stream);
    assert!(
        second_request.tools.is_empty(),
        "followup answer must not keep tool calling enabled"
    );
    assert!(
        second_request.response_format.is_none(),
        "Rig + DeepSeek compatible followup must not force JSON output"
    );
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

#[tokio::test]
async fn rig_poc_prefetches_private_fact_tool_before_model() {
    let provider = FinalOnlyRigProvider::new();
    let observed_provider = provider.clone();
    let mut registry = ToolRegistry::new();
    registry.register(PrivateIdentityTool);

    let engine = AgentRuntimeEngineFactory::new(AgentRuntimeEngineMode::RigPoc).build(
        AgentRuntimeEngineInput {
            provider: Arc::new(provider),
            registry: Arc::new(registry),
            tool_context: AiToolContext {
                actor_user_id: Uuid::new_v4(),
                authorized_pet_id: Uuid::parse_str("11111111-1111-1111-1111-111111111111")
                    .expect("pet id"),
            },
            fact_package: None,
        },
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
        .expect("rig prefetch run");

    assert_eq!(
        event_names(&events),
        vec![
            "turn_started",
            "tool_started",
            "tool_finished",
            "message_delta",
            "model_call_started",
            "model_call_finished",
            "turn_finished",
        ]
    );

    let requests = observed_provider.requests();
    assert_eq!(requests.len(), 1);
    assert!(
        requests[0]
            .messages
            .iter()
            .all(|message| message.role != LlmRole::Tool),
        "prefetched evidence must not be sent as OpenAI tool-role history"
    );
    assert!(
        requests[0]
            .messages
            .iter()
            .all(|message| message.tool_calls.is_empty()),
        "prefetched evidence must not be sent as assistant tool_calls"
    );
    let tool_message = requests[0]
        .messages
        .iter()
        .find(|message| {
            message.role == LlmRole::System && message.content.contains("prefetched_tool_context")
        })
        .expect(
            "prefetched tool result should be injected as system context before rig model call",
        );
    assert!(
        tool_message.content.contains("梅录") && tool_message.content.contains("420"),
        "rig prefetch tool result should contain identity facts, got: {}",
        tool_message.content
    );
}

#[tokio::test]
async fn rig_poc_events_expose_engine_mode_for_runtime_observability() {
    let provider = ScriptedRigProvider::new();
    let tool = RecordingTool::new();
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
    let engine_modes: Vec<&str> = events
        .iter()
        .filter_map(|event| match event {
            AgentEvent::TurnStarted { engine_mode, .. }
            | AgentEvent::ModelCallStarted { engine_mode, .. }
            | AgentEvent::ModelCallFinished { engine_mode, .. } => Some(engine_mode.as_str()),
            _ => None,
        })
        .collect();

    assert!(
        engine_modes.iter().all(|mode| *mode == "rig_poc"),
        "all runtime observable events should carry rig_poc engine mode: {engine_modes:?}"
    );
}
