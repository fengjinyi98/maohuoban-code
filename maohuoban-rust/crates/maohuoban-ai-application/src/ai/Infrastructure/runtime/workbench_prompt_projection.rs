use std::fmt::Write as _;

use maohuoban_ai_domain::ai::{
    AgentSessionWorkbench, AiConversationSurface, CapabilityDomain, MemoryScope,
};

/// workbench_context_prompt 构建模型可见工作台上下文
/// 核心职责：
/// - 将 Workbench 投影为受控自然语言上下文
/// - 避免 domain struct 字段和新增内部字段自动进入模型输入
pub(super) fn workbench_context_prompt(workbench: &AgentSessionWorkbench) -> String {
    let mut prompt = String::new();
    prompt.push_str("## AgentSession Workbench\n");
    prompt.push_str("这是本轮可见能力、上下文和记忆摘要。只能在这些边界内回答、追问或申请工具。\n");
    writeln!(
        prompt,
        "助手: {}。职责: {}。",
        workbench.agent_definition.name, workbench.agent_definition.purpose
    )
    .expect("write workbench prompt");

    prompt.push_str("能力边界:\n");
    for domain in &workbench.agent_definition.capability_domains {
        writeln!(prompt, "- {}", display_capability_domain(*domain))
            .expect("write workbench prompt");
    }

    prompt.push_str("可用能力:\n");
    if workbench.capability_catalog.capabilities.is_empty() {
        prompt.push_str("- 无额外能力。\n");
    } else {
        for capability in &workbench.capability_catalog.capabilities {
            let private_requirement = if capability.requires_private_context {
                "需要已选宠物上下文"
            } else {
                "无需已选宠物上下文"
            };
            writeln!(
                prompt,
                "- {}：{}（{}）。",
                capability.title, capability.when_to_use, private_requirement
            )
            .expect("write workbench prompt");
        }
    }

    prompt.push_str("本轮上下文:\n");
    writeln!(
        prompt,
        "- 入口: {}；语言: {}；时区: {}。",
        display_surface(workbench.context_pack.surface),
        workbench.context_pack.locale,
        workbench.context_pack.timezone
    )
    .expect("write workbench prompt");
    match &workbench.context_pack.selected_pet {
        Some(pet) => {
            writeln!(
                prompt,
                "- 已选宠物: {}（{}）。",
                pet.name,
                display_species(&pet.species)
            )
            .expect("write workbench prompt");
        }
        None => prompt.push_str("- 已选宠物: 无。\n"),
    }
    if !workbench.context_pack.authorized_pets.is_empty() {
        prompt.push_str("- 授权宠物候选: ");
        for (index, pet) in workbench.context_pack.authorized_pets.iter().enumerate() {
            if index > 0 {
                prompt.push('、');
            }
            write!(prompt, "{}（{}）", pet.name, display_species(&pet.species))
                .expect("write workbench prompt");
        }
        prompt.push_str("。\n");
    }
    if let Some(summary) = &workbench.context_pack.session_summary {
        writeln!(prompt, "- 会话摘要: {summary}。").expect("write workbench prompt");
    }

    prompt.push_str("记忆摘要:\n");
    if workbench.memory_pack.entries.is_empty() {
        prompt.push_str("- 无。\n");
    } else {
        for memory in &workbench.memory_pack.entries {
            writeln!(
                prompt,
                "- {}: {}",
                display_memory_scope(memory.scope),
                memory.summary
            )
            .expect("write workbench prompt");
        }
    }
    prompt.push_str("执行边界:\n");
    prompt.push_str("- 工具只能由 Runtime Gateway 执行；模型只申请工具或基于已投影信息回答。\n");

    prompt
}

/// display_capability_domain 返回模型可读能力域名称
/// 核心职责：
/// - 避免把领域枚举名直接暴露给模型
/// - 保留能力边界的自然语言含义
fn display_capability_domain(domain: CapabilityDomain) -> &'static str {
    match domain {
        CapabilityDomain::PublicPetDomain => "公共宠物照护咨询",
        CapabilityDomain::PrivatePetContext => "授权宠物私域上下文",
        CapabilityDomain::AppProductSupport => "毛伙伴产品帮助",
        CapabilityDomain::AssistantIdentity => "助手身份说明",
        CapabilityDomain::HardSafety => "硬安全边界",
    }
}

/// display_surface 返回模型可读入口名称
/// 核心职责：
/// - 将产品入口枚举转换为自然语言场景
fn display_surface(surface: AiConversationSurface) -> &'static str {
    match surface {
        AiConversationSurface::HomePrivate => "首页私域对话",
        AiConversationSurface::PetProfile => "宠物档案",
        AiConversationSurface::AbnormalDetail => "异常记录详情",
        AiConversationSurface::ConfirmationTask => "确认任务",
        AiConversationSurface::UgcComment => "社区评论",
    }
}

/// display_memory_scope 返回模型可读记忆作用域
/// 核心职责：
/// - 用自然语言表达记忆归属范围
fn display_memory_scope(scope: MemoryScope) -> &'static str {
    match scope {
        MemoryScope::User => "用户记忆",
        MemoryScope::Pet => "宠物记忆",
        MemoryScope::Household => "家庭记忆",
        MemoryScope::Session => "会话记忆",
    }
}

/// display_species 返回模型可读宠物物种
/// 核心职责：
/// - 将常见物种编码转换为中文语义
fn display_species(species: &str) -> &str {
    match species {
        "cat" => "猫",
        "dog" => "狗",
        "other" => "其他",
        value => value,
    }
}
