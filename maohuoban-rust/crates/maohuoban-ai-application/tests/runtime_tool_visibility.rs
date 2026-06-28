use std::sync::{Arc, Mutex};

use async_trait::async_trait;
use futures_util::StreamExt;
use maohuoban_ai_application::ai::ports::LlmProvider;
use maohuoban_ai_application::ai::runtime::{AgentRuntimeLoopEngine, AgentSession};
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel, ToolRegistry,
};
use maohuoban_ai_domain::ai::{
    AgentCapability, AgentDefinition, AgentId, AgentSessionWorkbench, AiConversationSurface,
    CapabilityCatalog, CapabilityDomain, ContextPack, LlmChatRequest, LlmChatResponse,
    LlmFinishReason, LlmStreamEvent, LlmUsage, MemoryPack, ModelLabel,
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
            selected_pet: None,
            authorized_pets: Vec::new(),
            session_summary: None,
        },
        memory_pack: MemoryPack {
            entries: Vec::new(),
        },
    }
}
