// runtime_workbench_prompt_projection Workbench 模型可见投影测试
// 核心职责：
// - 验证 Runtime 给模型的 Workbench prompt 使用受控文本投影
// - 防止 domain struct 字段名和未来新增字段自动进入模型输入

use std::sync::{Arc, Mutex};

use futures_util::StreamExt;
use maohuoban_ai_application::ai::ports::LlmProvider;
use maohuoban_ai_application::ai::runtime::{AgentRuntimeLoopEngine, AgentSession};
use maohuoban_ai_application::ai::tools::{AiToolContext, ToolRegistry};
use maohuoban_ai_domain::ai::{
    AgentCapability, AgentDefinition, AgentId, AgentSessionWorkbench, AiConversationSurface,
    CapabilityCatalog, CapabilityDomain, ContextPack, LlmChatRequest, LlmChatResponse,
    LlmFinishReason, LlmStreamEvent, LlmUsage, MemoryPack, ModelLabel,
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

#[tokio::test]
async fn workbench_prompt_hides_domain_struct_field_names() {
    let provider = CapturingProvider::new();
    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider.clone()),
        Arc::new(ToolRegistry::new()),
        AiToolContext {
            actor_user_id: Uuid::new_v4(),
            authorized_pet_id: Uuid::nil(),
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
    }
}
