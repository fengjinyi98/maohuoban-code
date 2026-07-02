use std::sync::{Arc, Mutex};

use async_trait::async_trait;
use futures_util::StreamExt;
use maohuoban_ai_application::ai::ports::LlmProvider;
use maohuoban_ai_application::ai::runtime::{AgentRuntimeLoopEngine, AgentSession};
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel,
    DateCalculatorTool, ToolGatewayExecutionContext, ToolRegistry,
};
use maohuoban_ai_domain::ai::{
    AgentCapability, AgentDefinition, AgentId, AgentSessionWorkbench, AiConversationSurface,
    CapabilityCatalog, CapabilityDomain, ContextConfirmationTaskSummary, ContextPack,
    ContextPetSummary, LlmChatRequest, LlmChatResponse, LlmFinishReason, LlmStreamEvent, LlmUsage,
    MemoryPack, ModelLabel, ToolProgressText, Toolset,
};
use uuid::Uuid;

#[derive(Clone, Default)]
struct RecordingStreamProvider {
    requests: Arc<Mutex<Vec<LlmChatRequest>>>,
}

impl RecordingStreamProvider {
    fn take_requests(&self) -> Vec<LlmChatRequest> {
        self.requests.lock().expect("requests").clone()
    }
}

impl LlmProvider for RecordingStreamProvider {
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
                "complete should not be used".to_owned(),
            ))
        })
    }

    fn stream<'a>(
        &'a self,
        request: &'a LlmChatRequest,
    ) -> futures_util::stream::BoxStream<'a, maohuoban_ai_domain::ai::AiResult<LlmStreamEvent>>
    {
        self.requests
            .lock()
            .expect("requests")
            .push(request.clone());
        futures_util::stream::iter(vec![
            Ok(LlmStreamEvent::Delta {
                content: "公共回答".to_owned(),
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
        "加载宠物身份上下文"
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
            result_fact_schema: None,
        }
    }

    async fn execute(&self, _ctx: &AiToolContext, _args: &serde_json::Value) -> AiToolResult {
        AiToolResult::failed("unexpected")
    }
}

#[tokio::test]
async fn private_tools_hidden_without_selected_pet_even_if_catalog_mentions_private_context() {
    let provider = RecordingStreamProvider::default();
    let mut registry = ToolRegistry::new();
    registry.register(PrivateIdentityTool);
    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider.clone()),
        Arc::new(registry),
        AiToolContext {
            actor_user_id: Uuid::new_v4(),
            authorized_pet_id: Uuid::new_v4(),
            gateway_context: ToolGatewayExecutionContext::default(),
            gateway_observer: None,
        },
        None,
    );
    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    session
        .prompt_with_workbench("猫拉肚子一般要观察什么？", misleading_private_workbench())
        .await
        .expect("prompt workbench");

    let requests = provider.take_requests();
    assert_eq!(requests.len(), 1);
    assert!(
        requests[0].tools.is_empty(),
        "no selected pet means private tools must stay hidden, got {:?}",
        requests[0]
            .tools
            .iter()
            .map(|tool| tool.name.as_str())
            .collect::<Vec<_>>()
    );
}

/// `SneakyPrivateTool` scope 和 `domain_tags` 都不命中旧规则，但 toolset 是 `PrivatePetContext`
/// 核心职责：
/// - 验证 `toolset` 参与可见性决策，不能只靠 `scope`/`domain_tags`
struct SneakyPrivateTool;

#[async_trait]
impl AiToolDefinition for SneakyPrivateTool {
    fn name(&self) -> &'static str {
        "load_health_summary"
    }

    fn description(&self) -> &'static str {
        "加载宠物健康摘要"
    }

    fn parameters_schema(&self) -> serde_json::Value {
        serde_json::json!({"type": "object"})
    }

    fn metadata(&self) -> AiToolMetadata {
        AiToolMetadata {
            scope: "health.summary".to_owned(),
            read_only: true,
            concurrency_safe: true,
            risk_level: AiToolRiskLevel::Low,
            requires_confirmation: false,
            domain_tags: vec!["health".to_owned()],
            toolset: Toolset::PrivatePetContext,
            progress_text: ToolProgressText::default(),
            result_fact_schema: None,
        }
    }

    async fn execute(&self, _ctx: &AiToolContext, _args: &serde_json::Value) -> AiToolResult {
        AiToolResult::failed("unexpected")
    }
}

struct PrepareObservationWriteTool;

#[async_trait]
impl AiToolDefinition for PrepareObservationWriteTool {
    fn name(&self) -> &'static str {
        "prepare_pet_observation_write"
    }

    fn description(&self) -> &'static str {
        "准备写入宠物观察记录"
    }

    fn parameters_schema(&self) -> serde_json::Value {
        serde_json::json!({"type": "object"})
    }

    fn metadata(&self) -> AiToolMetadata {
        AiToolMetadata {
            scope: "pet.observation.write_prepare".to_owned(),
            read_only: false,
            concurrency_safe: false,
            risk_level: AiToolRiskLevel::High,
            requires_confirmation: true,
            domain_tags: vec!["observation".to_owned()],
            toolset: Toolset::PrivatePetContext,
            progress_text: ToolProgressText::default(),
            result_fact_schema: None,
        }
    }

    async fn execute(&self, _ctx: &AiToolContext, _args: &serde_json::Value) -> AiToolResult {
        AiToolResult::failed("unexpected")
    }
}

struct CommitObservationWriteTool;

#[async_trait]
impl AiToolDefinition for CommitObservationWriteTool {
    fn name(&self) -> &'static str {
        "commit_pet_observation_write"
    }

    fn description(&self) -> &'static str {
        "确认后写入宠物观察记录"
    }

    fn parameters_schema(&self) -> serde_json::Value {
        serde_json::json!({"type": "object"})
    }

    fn metadata(&self) -> AiToolMetadata {
        AiToolMetadata {
            scope: "pet.observation.write_commit".to_owned(),
            read_only: false,
            concurrency_safe: false,
            risk_level: AiToolRiskLevel::High,
            requires_confirmation: false,
            domain_tags: vec!["observation".to_owned()],
            toolset: Toolset::Confirmation,
            progress_text: ToolProgressText::default(),
            result_fact_schema: None,
        }
    }

    async fn execute(&self, _ctx: &AiToolContext, _args: &serde_json::Value) -> AiToolResult {
        AiToolResult::failed("unexpected")
    }
}

#[tokio::test]
async fn private_toolset_hidden_without_selected_pet_even_if_scope_and_tags_miss_old_rules() {
    // 旧规则只检查 scope.starts_with("pet.") 和 domain_tags in [identity, diet, inventory, diet_confirmation]
    // SneakyPrivateTool 的 scope="health.summary"、domain_tags=["health"]，旧规则不会隐藏它
    // 但 toolset=PrivatePetContext，应该被隐藏
    let provider = RecordingStreamProvider::default();
    let mut registry = ToolRegistry::new();
    registry.register(SneakyPrivateTool);
    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider.clone()),
        Arc::new(registry),
        AiToolContext {
            actor_user_id: Uuid::new_v4(),
            authorized_pet_id: Uuid::new_v4(),
            gateway_context: ToolGatewayExecutionContext::default(),
            gateway_observer: None,
        },
        None,
    );
    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    session
        .prompt_with_workbench("猫拉肚子一般要观察什么？", misleading_private_workbench())
        .await
        .expect("prompt workbench");

    let requests = provider.take_requests();
    assert_eq!(requests.len(), 1);
    assert!(
        requests[0].tools.is_empty(),
        "toolset=PrivatePetContext must be hidden without selected pet even if scope/tags miss old rules, got {:?}",
        requests[0]
            .tools
            .iter()
            .map(|tool| tool.name.as_str())
            .collect::<Vec<_>>()
    );
}

#[tokio::test]
async fn temporal_toolset_visible_without_selected_pet() {
    let provider = RecordingStreamProvider::default();
    let mut registry = ToolRegistry::new();
    registry.register(DateCalculatorTool);
    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider.clone()),
        Arc::new(registry),
        AiToolContext {
            actor_user_id: Uuid::new_v4(),
            authorized_pet_id: Uuid::new_v4(),
            gateway_context: ToolGatewayExecutionContext::default(),
            gateway_observer: None,
        },
        None,
    );
    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    session
        .prompt_with_workbench("明天是几号？", misleading_private_workbench())
        .await
        .expect("prompt workbench");

    let requests = provider.take_requests();
    assert_eq!(requests.len(), 1);
    assert_eq!(
        requests[0]
            .tools
            .iter()
            .map(|tool| tool.name.as_str())
            .collect::<Vec<_>>(),
        vec!["date_calculator"]
    );
}

#[tokio::test]
async fn prepare_write_tool_visible_with_private_context() {
    let provider = RecordingStreamProvider::default();
    let mut registry = ToolRegistry::new();
    registry.register(PrepareObservationWriteTool);
    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider.clone()),
        Arc::new(registry),
        AiToolContext {
            actor_user_id: Uuid::new_v4(),
            authorized_pet_id: Uuid::new_v4(),
            gateway_context: ToolGatewayExecutionContext::default(),
            gateway_observer: None,
        },
        None,
    );
    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    session
        .prompt_with_workbench("帮我记一下今天拉稀", selected_private_workbench())
        .await
        .expect("prompt workbench");

    let requests = provider.take_requests();
    assert_eq!(requests.len(), 1);
    assert!(
        requests[0]
            .tools
            .iter()
            .any(|tool| tool.name == "prepare_pet_observation_write")
    );
}

#[tokio::test]
async fn commit_write_tool_visible_with_private_context() {
    let provider = RecordingStreamProvider::default();
    let mut registry = ToolRegistry::new();
    registry.register(CommitObservationWriteTool);
    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider.clone()),
        Arc::new(registry),
        AiToolContext {
            actor_user_id: Uuid::new_v4(),
            authorized_pet_id: Uuid::new_v4(),
            gateway_context: ToolGatewayExecutionContext::default(),
            gateway_observer: None,
        },
        None,
    );
    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    session
        .prompt_with_workbench("确认写入上一条观察记录", selected_private_workbench())
        .await
        .expect("prompt workbench");

    let requests = provider.take_requests();
    assert_eq!(requests.len(), 1);
    assert!(
        requests[0]
            .tools
            .iter()
            .any(|tool| tool.name == "commit_pet_observation_write")
    );
}

#[tokio::test]
async fn commit_write_tool_visible_with_pending_confirmation_task() {
    let provider = RecordingStreamProvider::default();
    let mut registry = ToolRegistry::new();
    registry.register(CommitObservationWriteTool);
    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider.clone()),
        Arc::new(registry),
        AiToolContext {
            actor_user_id: Uuid::new_v4(),
            authorized_pet_id: Uuid::new_v4(),
            gateway_context: ToolGatewayExecutionContext {
                session_id: None,
                turn_id: None,
                message_id: None,
                confirmation_task_id: Some(
                    Uuid::parse_str("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")
                        .expect("task id")
                        .to_string(),
                ),
            },
            gateway_observer: None,
        },
        None,
    );
    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::ConfirmationTask,
        engine,
    );

    let mut workbench = selected_private_workbench();
    workbench.context_pack.pending_confirmation_task = Some(ContextConfirmationTaskSummary {
        confirmation_task_id: Uuid::parse_str("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")
            .expect("task id"),
        tool_name: "commit_pet_observation_write".to_owned(),
        question_text: "是否确认写入这条观察记录？".to_owned(),
    });

    session
        .prompt_with_workbench("确认写入这条观察记录", workbench)
        .await
        .expect("prompt workbench");

    let requests = provider.take_requests();
    assert_eq!(requests.len(), 1);
    assert!(
        requests[0]
            .tools
            .iter()
            .any(|tool| tool.name == "commit_pet_observation_write")
    );
}

fn misleading_private_workbench() -> AgentSessionWorkbench {
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
                title: "授权宠物上下文".to_owned(),
                when_to_use: "用户询问自己宠物档案时使用".to_owned(),
                requires_private_context: true,
            }],
        },
        context_pack: ContextPack {
            surface: AiConversationSurface::HomePrivate,
            locale: "zh-Hans".to_owned(),
            timezone: "Asia/Shanghai".to_owned(),
            temporal_context: None,
            selected_pet: None,
            authorized_pets: Vec::new(),
            session_summary: None,
            pending_confirmation_task: None,
        },
        memory_pack: MemoryPack {
            entries: Vec::new(),
        },
        recent_conversation_pack: None,
    }
}

fn selected_private_workbench() -> AgentSessionWorkbench {
    let mut workbench = misleading_private_workbench();
    workbench.context_pack.selected_pet = Some(ContextPetSummary {
        pet_id: Uuid::parse_str("11111111-1111-1111-1111-111111111111").expect("pet id"),
        name: "毛球".to_owned(),
        species: "cat".to_owned(),
    });
    workbench
}
