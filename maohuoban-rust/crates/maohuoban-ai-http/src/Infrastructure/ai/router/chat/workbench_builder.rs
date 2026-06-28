use maohuoban_ai_domain::ai::{
    AgentCapability, AgentDefinition, AgentId, AgentSessionWorkbench, AiConversationSurface,
    AiPetDisplaySnapshot, CapabilityCatalog, CapabilityDomain, ContextPack, ContextPetSummary,
    MemoryPack, ModelLabel,
};

/// build_agent_session_workbench 构建本轮 Agent 工作台
/// 核心职责：
/// - 为 HTTP 主链路提供统一 Workbench 输入
/// - 只在已解析目标宠物时暴露私域宠物能力
pub(super) fn build_agent_session_workbench(
    surface: AiConversationSurface,
    target_pet: Option<&AiPetDisplaySnapshot>,
) -> AgentSessionWorkbench {
    let mut capability_domains = vec![
        CapabilityDomain::PublicPetDomain,
        CapabilityDomain::AppProductSupport,
        CapabilityDomain::AssistantIdentity,
    ];
    let mut capabilities = vec![
        AgentCapability {
            code: "public_pet_domain".to_owned(),
            domain: CapabilityDomain::PublicPetDomain,
            title: "公共养宠咨询".to_owned(),
            when_to_use: "用户咨询通用照护、饮食、行为或常见症状观察时使用".to_owned(),
            requires_private_context: false,
        },
        AgentCapability {
            code: "app_product_support".to_owned(),
            domain: CapabilityDomain::AppProductSupport,
            title: "毛伙伴 App 使用帮助".to_owned(),
            when_to_use: "用户询问添加宠物、记录、提醒、历史和 App 操作时使用".to_owned(),
            requires_private_context: false,
        },
        AgentCapability {
            code: "assistant_identity".to_owned(),
            domain: CapabilityDomain::AssistantIdentity,
            title: "助手身份说明".to_owned(),
            when_to_use: "用户询问毛球是谁、能做什么、能力边界是什么时使用".to_owned(),
            requires_private_context: false,
        },
    ];

    if target_pet.is_some() {
        capability_domains.push(CapabilityDomain::PrivatePetContext);
        capabilities.push(AgentCapability {
            code: "private_pet_context".to_owned(),
            domain: CapabilityDomain::PrivatePetContext,
            title: "授权宠物上下文".to_owned(),
            when_to_use: "用户询问自己宠物档案、饮食、异常、提醒或记录时使用".to_owned(),
            requires_private_context: true,
        });
    }

    let selected_pet = target_pet.map(context_pet_summary);
    let authorized_pets = selected_pet.iter().cloned().collect();

    AgentSessionWorkbench {
        agent_definition: AgentDefinition {
            agent_id: AgentId::main_pet_care_agent(),
            name: "毛球".to_owned(),
            purpose: "宠物垂直照护、毛伙伴 App 帮助与用户宠物私域助手".to_owned(),
            default_model_label: ModelLabel::Primary,
            capability_domains,
        },
        capability_catalog: CapabilityCatalog { capabilities },
        context_pack: ContextPack {
            surface,
            locale: "zh-Hans".to_owned(),
            timezone: "Asia/Shanghai".to_owned(),
            selected_pet,
            authorized_pets,
            session_summary: None,
        },
        memory_pack: MemoryPack {
            entries: Vec::new(),
        },
    }
}

fn context_pet_summary(pet: &AiPetDisplaySnapshot) -> ContextPetSummary {
    ContextPetSummary {
        pet_id: pet.pet_id,
        name: pet.pet_name.clone(),
        species: pet.pet_species.clone(),
    }
}
