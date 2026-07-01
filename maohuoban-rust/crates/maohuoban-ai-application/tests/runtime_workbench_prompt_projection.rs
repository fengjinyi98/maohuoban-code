// runtime_workbench_prompt_projection Workbench 模型可见投影测试
// 核心职责：
// - 验证 Runtime 给模型的 Workbench prompt 使用受控文本投影
// - 防止 domain struct 字段名和未来新增字段自动进入模型输入

use std::sync::{Arc, Mutex};

use async_trait::async_trait;
use futures_util::StreamExt;
use maohuoban_ai_application::ai::ports::LlmProvider;
use maohuoban_ai_application::ai::runtime::{AgentRuntimeLoopEngine, AgentSession};
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel,
    ToolGatewayExecutionContext, ToolRegistry,
};
use maohuoban_ai_domain::ai::{
    AgentCapability, AgentDefinition, AgentId, AgentSessionWorkbench, AiConversationSurface,
    CapabilityCatalog, CapabilityDomain, ContextPack, ContextPetSummary, LlmChatRequest,
    LlmChatResponse, LlmFinishReason, LlmStreamEvent, LlmUsage, MemoryPack, ModelLabel,
    ToolFactField, ToolFactSchema, ToolProgressText, Toolset,
};
use uuid::Uuid;

#[derive(Clone)]
struct CapturingProvider {
    requests: Arc<Mutex<Vec<LlmChatRequest>>>,
}

impl CapturingProvider {
    fn new() -> Self {
        Self {
            requests: Arc::new(Mutex::new(Vec::new())),
        }
    }

    fn take_requests(&self) -> Vec<LlmChatRequest> {
        self.requests.lock().expect("requests").clone()
    }
}

impl LlmProvider for CapturingProvider {
    fn complete<'a>(
        &'a self,
        _request: &LlmChatRequest,
    ) -> std::pin::Pin<
        Box<
            dyn std::future::Future<Output = maohuoban_ai_domain::ai::AiResult<LlmChatResponse>>
                + Send
                + 'a,
        >,
    > {
        Box::pin(async {
            Err(maohuoban_ai_domain::ai::AiError::Infrastructure(
                "runtime should use stream".to_owned(),
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
        futures_util::stream::iter(vec![
            Ok(LlmStreamEvent::Delta {
                content: "可以先观察精神、食欲和排便频次。".to_owned(),
            }),
            Ok(LlmStreamEvent::Finish {
                finish_reason: LlmFinishReason::Stop,
                usage: LlmUsage::default(),
            }),
        ])
        .boxed()
    }
}

fn test_tool_context(pet_id: Uuid) -> AiToolContext {
    AiToolContext {
        actor_user_id: Uuid::new_v4(),
        authorized_pet_id: pet_id,
        gateway_context: ToolGatewayExecutionContext::default(),
        gateway_observer: None,
    }
}

struct AppHelpTool;

#[async_trait]
impl AiToolDefinition for AppHelpTool {
    fn name(&self) -> &'static str {
        "explain_app_feature"
    }

    fn description(&self) -> &'static str {
        "解释毛伙伴 App 页面和流程"
    }

    fn parameters_schema(&self) -> serde_json::Value {
        serde_json::json!({
            "type": "object",
            "properties": {},
            "required": []
        })
    }

    fn metadata(&self) -> AiToolMetadata {
        AiToolMetadata {
            scope: "app.help.read".to_owned(),
            read_only: true,
            concurrency_safe: true,
            risk_level: AiToolRiskLevel::Low,
            requires_confirmation: false,
            domain_tags: vec!["app_help".to_owned()],
            toolset: Toolset::AppSupport,
            progress_text: ToolProgressText::default(),
            result_fact_schema: None,
        }
    }

    async fn execute(&self, _ctx: &AiToolContext, _args: &serde_json::Value) -> AiToolResult {
        AiToolResult::allowed(Vec::new())
    }
}

struct PetIdentityFactTool;

#[async_trait]
impl AiToolDefinition for PetIdentityFactTool {
    fn name(&self) -> &'static str {
        "load_pet_identity_context"
    }

    fn description(&self) -> &'static str {
        "读取目标宠物基础档案事实"
    }

    fn parameters_schema(&self) -> serde_json::Value {
        serde_json::json!({
            "type": "object",
            "properties": {},
            "required": []
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
                fact_keys: vec![
                    "pet_identity.birthday".to_owned(),
                    "pet_identity.world_days".to_owned(),
                    "pet_identity.companionship_days".to_owned(),
                ],
                description: "宠物基础档案事实".to_owned(),
                natural_language_summary:
                    "可回答宠物多大了、几岁了、生日、来到世界多少天、陪伴多久等问题".to_owned(),
                fields: vec![
                    ToolFactField {
                        key: "pet_identity.world_days".to_owned(),
                        label: "年龄/出生至今天数".to_owned(),
                        meaning: "宠物从生日到今天经过的天数，可用于回答多大了、几岁了、出生多久了"
                            .to_owned(),
                        example_queries: vec![
                            "多大了".to_owned(),
                            "几岁了".to_owned(),
                            "出生多久了".to_owned(),
                        ],
                    },
                    ToolFactField {
                        key: "pet_identity.companionship_days".to_owned(),
                        label: "陪伴天数".to_owned(),
                        meaning: "宠物从到家日期到今天陪伴用户的天数".to_owned(),
                        example_queries: vec!["陪伴我多久了".to_owned(), "到家多久了".to_owned()],
                    },
                ],
            }),
        }
    }

    async fn execute(&self, _ctx: &AiToolContext, _args: &serde_json::Value) -> AiToolResult {
        AiToolResult::allowed(Vec::new())
    }
}

#[tokio::test]
async fn workbench_prompt_hides_domain_struct_field_names() {
    let provider = CapturingProvider::new();
    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider.clone()),
        Arc::new(ToolRegistry::new()),
        test_tool_context(Uuid::nil()),
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
        .expect("prompt public workbench");

    let requests = provider.take_requests();
    let workbench_prompt = requests[0]
        .messages
        .iter()
        .find(|message| message.content.contains("AgentSession Workbench"))
        .expect("workbench prompt should be present")
        .content
        .as_str();

    assert!(workbench_prompt.contains("公共养宠咨询"));
    for forbidden in [
        "agent_definition",
        "context_pack",
        "capability_catalog",
        "default_model_label",
    ] {
        assert!(
            !workbench_prompt.contains(forbidden),
            "workbench prompt must not expose domain struct field {forbidden}: {workbench_prompt}"
        );
    }
}

#[tokio::test]
async fn workbench_prompt_discloses_empty_visible_tool_list() {
    let provider = CapturingProvider::new();
    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider.clone()),
        Arc::new(ToolRegistry::new()),
        test_tool_context(Uuid::nil()),
        None,
    );
    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    session
        .prompt_with_workbench("帮我把宠物名字改成梅鹿", public_pet_domain_workbench())
        .await
        .expect("prompt public workbench");

    let requests = provider.take_requests();
    let workbench_prompt = requests[0]
        .messages
        .iter()
        .find(|message| message.content.contains("AgentSession Workbench"))
        .expect("workbench prompt should be present")
        .content
        .as_str();

    assert!(
        workbench_prompt.contains("本轮可执行工具:\n- 无。"),
        "workbench prompt should disclose empty runtime tool list: {workbench_prompt}"
    );
    assert!(
        workbench_prompt.contains("用户询问工具或可执行能力时，只能基于“本轮可执行工具”回答"),
        "workbench prompt should bind tool disclosure to visible runtime tools: {workbench_prompt}"
    );
}

#[tokio::test]
async fn workbench_prompt_discloses_visible_runtime_tools() {
    let provider = CapturingProvider::new();
    let mut registry = ToolRegistry::new();
    registry.register(AppHelpTool);
    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider.clone()),
        Arc::new(registry),
        test_tool_context(Uuid::nil()),
        None,
    );
    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    session
        .prompt_with_workbench("你有哪些工具", public_pet_domain_workbench())
        .await
        .expect("prompt public workbench");

    let requests = provider.take_requests();
    let workbench_prompt = requests[0]
        .messages
        .iter()
        .find(|message| message.content.contains("AgentSession Workbench"))
        .expect("workbench prompt should be present")
        .content
        .as_str();

    assert!(
        workbench_prompt.contains("- explain_app_feature：解释毛伙伴 App 页面和流程"),
        "workbench prompt should list visible runtime tool schemas: {workbench_prompt}"
    );
    assert_eq!(requests[0].tools[0].name, "explain_app_feature");
}

#[tokio::test]
async fn workbench_prompt_discloses_tool_fact_schema_in_natural_language() {
    let provider = CapturingProvider::new();
    let mut registry = ToolRegistry::new();
    registry.register(PetIdentityFactTool);
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
        .prompt_with_workbench("工具说明", private_pet_context_workbench())
        .await
        .expect("prompt private workbench");

    let requests = provider.take_requests();
    let workbench_prompt = requests[0]
        .messages
        .iter()
        .find(|message| message.content.contains("AgentSession Workbench"))
        .expect("workbench prompt should be present")
        .content
        .as_str();

    assert!(
        workbench_prompt.contains("可返回事实: 宠物基础档案事实"),
        "workbench prompt should disclose fact schema description: {workbench_prompt}"
    );
    assert!(
        workbench_prompt.contains("年龄/出生至今天数"),
        "workbench prompt should disclose natural fact labels: {workbench_prompt}"
    );
    assert!(
        workbench_prompt.contains("多大了") && workbench_prompt.contains("陪伴我多久了"),
        "workbench prompt should disclose example queries from the tool protocol: {workbench_prompt}"
    );
    assert!(
        requests[0].tools[0].description.contains("多大了")
            && requests[0].tools[0].description.contains("陪伴多久"),
        "model-visible tool description should include natural fact schema: {:?}",
        requests[0].tools[0]
    );
}

fn public_pet_domain_workbench() -> AgentSessionWorkbench {
    AgentSessionWorkbench {
        agent_definition: AgentDefinition {
            agent_id: AgentId::main_pet_care_agent(),
            name: "毛球".to_owned(),
            purpose: "宠物垂直照护与用户宠物私域助手".to_owned(),
            default_model_label: ModelLabel::Primary,
            capability_domains: vec![CapabilityDomain::PublicPetDomain],
        },
        capability_catalog: CapabilityCatalog {
            capabilities: vec![AgentCapability {
                code: "public_pet_care".to_owned(),
                domain: CapabilityDomain::PublicPetDomain,
                title: "公共养宠咨询".to_owned(),
                when_to_use: "用户咨询通用照护、饮食、行为或常见症状观察时使用".to_owned(),
                requires_private_context: false,
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
        recent_conversation_pack: None,
    }
}

fn private_pet_context_workbench() -> AgentSessionWorkbench {
    let mut workbench = public_pet_domain_workbench();
    workbench
        .agent_definition
        .capability_domains
        .push(CapabilityDomain::PrivatePetContext);
    workbench
        .capability_catalog
        .capabilities
        .push(AgentCapability {
            code: "private_pet_context".to_owned(),
            domain: CapabilityDomain::PrivatePetContext,
            title: "授权宠物私域上下文".to_owned(),
            when_to_use: "用户询问已选宠物的档案、年龄、生日、陪伴、饮食或记录事实时使用"
                .to_owned(),
            requires_private_context: true,
        });
    workbench.context_pack.selected_pet = Some(ContextPetSummary {
        pet_id: Uuid::parse_str("11111111-1111-1111-1111-111111111111").expect("pet id"),
        name: "梅录".to_owned(),
        species: "cat".to_owned(),
    });
    workbench
}
