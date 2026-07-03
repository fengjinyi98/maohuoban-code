use std::sync::Arc;

use maohuoban_ai_application::ai::runtime::AgentRuntimeLoopEngine;
use maohuoban_ai_application::ai::tools::{
    AiToolContext, ToolGatewayExecutionContext, ToolRegistry,
};
use maohuoban_ai_domain::ai::{
    AgentCapability, AgentDefinition, AgentId, AgentSessionWorkbench, AiConversationSurface,
    CapabilityCatalog, CapabilityDomain, ContextPack, ContextPetSummary, MemoryPack, ModelLabel,
};
use uuid::Uuid;

use super::provider::StreamingScriptedProvider;

pub fn runtime_engine(
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
            gateway_context: ToolGatewayExecutionContext::default(),
            gateway_observer: None,
        },
        None,
    )
}

pub fn private_pet_workbench() -> AgentSessionWorkbench {
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
            temporal_context: None,
            selected_pet: Some(ContextPetSummary {
                pet_id: Uuid::parse_str("11111111-1111-1111-1111-111111111111").expect("pet id"),
                name: "毛球".to_owned(),
                species: "cat".to_owned(),
            }),
            authorized_pets: vec![ContextPetSummary {
                pet_id: Uuid::parse_str("11111111-1111-1111-1111-111111111111").expect("pet id"),
                name: "毛球".to_owned(),
                species: "cat".to_owned(),
            }],
            session_summary: None,
            pending_confirmation_task: None,
        },
        memory_pack: MemoryPack {
            entries: Vec::new(),
        },
        recent_conversation_pack: None,
    }
}
