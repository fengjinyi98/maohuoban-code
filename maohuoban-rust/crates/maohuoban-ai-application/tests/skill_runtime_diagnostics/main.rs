// skill_runtime_diagnostics WT09 Skill Runtime 诊断事件测试
// 核心职责：
// - 验证 Runtime 在本轮请求中记录 skill 匹配事件
// - 固定 active_skill_ids、layer 和关联键字段

use std::sync::{Arc, Mutex};

use futures_util::StreamExt;
use maohuoban_ai_application::ai::ports::LlmProvider;
use maohuoban_ai_application::ai::runtime::{AgentRuntimeLoopEngine, AgentSession};
use maohuoban_ai_application::ai::tools::{
    AiToolContext, ToolGatewayExecutionContext, ToolRegistry,
};
use maohuoban_ai_domain::ai::{
    AgentCapability, AgentDefinition, AgentId, AgentSessionWorkbench, AgentTurnId,
    AiConversationSurface, CapabilityCatalog, CapabilityDomain, ContextPack, LlmChatRequest,
    LlmChatResponse, LlmFinishReason, LlmStreamEvent, LlmUsage, MemoryPack, ModelLabel,
};
use maohuoban_diagnostics::{
    CapturePolicy, CleanupPolicy, Diagnostics, DiagnosticsConfig, FileSegmentStore, PrivacyPolicy,
};
use serde_json::json;
use uuid::Uuid;

#[tokio::test]
async fn runtime_records_skill_matched_diagnostics_event() {
    let diagnostics = install_test_diagnostics();
    let provider = CapturingProvider::default();
    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider),
        Arc::new(ToolRegistry::new()),
        AiToolContext {
            actor_user_id: Uuid::new_v4(),
            authorized_pet_id: Uuid::nil(),
            gateway_context: ToolGatewayExecutionContext::default(),
            gateway_observer: None,
        },
        None,
    );
    let session_id = Uuid::new_v4();
    let turn_id = AgentTurnId::new();
    let message_id = Uuid::new_v4();
    let mut session = AgentSession::new(
        session_id,
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    session
        .prompt_with_workbench_turn_and_diagnostics_message_id(
            "猫拉肚子一般要观察什么？",
            public_pet_domain_workbench(),
            turn_id,
            message_id,
        )
        .await
        .expect("prompt with workbench");

    diagnostics.flush().expect("flush diagnostics");
    let events = diagnostics.read_events().expect("read diagnostics");
    let event = events
        .iter()
        .find(|event| event.message == "ai.chat.skill.matched")
        .expect("missing skill matched diagnostics event");

    assert_eq!(event.metadata["session_id"], json!(session_id));
    assert_eq!(event.metadata["turn_id"], json!(turn_id.as_uuid()));
    assert_eq!(event.metadata["message_id"], json!(message_id));
    assert!(
        event.metadata["active_skill_ids"]
            .as_array()
            .is_some_and(|ids| ids.iter().any(|id| id == "system.tool_gateway_boundary")),
        "skill diagnostics should include built-in system boundary skill: {event:?}"
    );
    assert!(
        event.metadata["active_skill_layers"]
            .as_array()
            .is_some_and(|layers| layers.iter().any(|layer| layer == "system")),
        "skill diagnostics should include system layer: {event:?}"
    );
}

#[derive(Clone, Default)]
struct CapturingProvider {
    requests: Arc<Mutex<Vec<LlmChatRequest>>>,
}

impl LlmProvider for CapturingProvider {
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

fn install_test_diagnostics() -> Diagnostics {
    let root = std::env::temp_dir().join(format!(
        "maohuoban-skill-runtime-diagnostics-{}",
        Uuid::new_v4()
    ));
    let store = FileSegmentStore::new(root.join("segments"), 1024 * 1024).expect("store");
    Diagnostics::install(DiagnosticsConfig {
        service_name: "maohuoban-rust".to_owned(),
        environment: "test".to_owned(),
        privacy: PrivacyPolicy::default(),
        capture: CapturePolicy::default(),
        cleanup: CleanupPolicy::default(),
        store: Box::new(store),
    })
    .expect("install diagnostics")
}
