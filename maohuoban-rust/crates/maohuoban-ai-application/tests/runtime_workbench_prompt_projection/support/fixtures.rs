use maohuoban_ai_application::ai::tools::{AiToolContext, ToolGatewayExecutionContext};
use maohuoban_ai_domain::ai::{
    AgentCapability, AgentDefinition, AgentId, AgentSessionWorkbench, AiConversationSurface,
    CapabilityCatalog, CapabilityDomain, ContextPack, ContextPetSummary, MemoryPack, ModelLabel,
    TemporalContext,
};
use uuid::Uuid;

pub fn test_tool_context(pet_id: Uuid) -> AiToolContext {
    AiToolContext {
        actor_user_id: Uuid::new_v4(),
        authorized_pet_id: pet_id,
        gateway_context: ToolGatewayExecutionContext::default(),
        gateway_observer: None,
    }
}

pub fn public_pet_domain_workbench() -> AgentSessionWorkbench {
    AgentSessionWorkbench {
        agent_definition: AgentDefinition {
            agent_id: AgentId::main_pet_care_agent(),
            name: "毛球".to_owned(),
            purpose: "宠物垂直照护与用户宠物私域助手".to_owned(),
            default_model_label: ModelLabel::Primary,
            capability_domains: vec![
                CapabilityDomain::PublicPetDomain,
                CapabilityDomain::TemporalReasoning,
            ],
        },
        capability_catalog: CapabilityCatalog {
            capabilities: vec![
                AgentCapability {
                    code: "public_pet_care".to_owned(),
                    domain: CapabilityDomain::PublicPetDomain,
                    title: "公共养宠咨询".to_owned(),
                    when_to_use: "用户咨询通用照护、饮食、行为或常见症状观察时使用".to_owned(),
                    requires_private_context: false,
                },
                AgentCapability {
                    code: "temporal_date_calculation".to_owned(),
                    domain: CapabilityDomain::TemporalReasoning,
                    title: "日期与时间计算".to_owned(),
                    when_to_use:
                        "用户询问今天、明天、昨天、生日、年龄、相差天数、提前或延后日期时使用"
                            .to_owned(),
                    requires_private_context: false,
                },
            ],
        },
        context_pack: ContextPack {
            surface: AiConversationSurface::HomePrivate,
            locale: "zh-Hans".to_owned(),
            timezone: "Asia/Shanghai".to_owned(),
            temporal_context: Some(TemporalContext {
                local_date: "2026-07-02".to_owned(),
                local_datetime: "2026-07-02T04:30:29+08:00".to_owned(),
                timezone: "Asia/Shanghai".to_owned(),
            }),
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

pub fn private_pet_context_workbench() -> AgentSessionWorkbench {
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
