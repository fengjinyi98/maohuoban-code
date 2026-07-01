use std::fmt::Write as _;

use maohuoban_ai_domain::ai::{
    AgentSessionWorkbench, AiConversationSurface, CapabilityDomain, LlmToolSchema, MemoryScope,
};

use crate::ai::skill::SkillBundle;

/// workbench_context_prompt 构建模型可见工作台上下文
/// 核心职责：
/// - 将 Workbench 投影为受控自然语言上下文
/// - 避免 domain struct 字段和新增内部字段自动进入模型输入
pub(super) fn workbench_context_prompt(
    workbench: &AgentSessionWorkbench,
    visible_tools: &[LlmToolSchema],
    skill_bundle: Option<&SkillBundle>,
) -> String {
    let mut prompt = String::new();
    prompt.push_str("## AgentSession Workbench\n");
    prompt.push_str("这是本轮可见能力、上下文和记忆摘要。只能在这些边界内回答、追问或申请工具。\n");
    write_agent_identity(&mut prompt, workbench);
    write_capability_boundaries(&mut prompt, workbench);
    write_capabilities(&mut prompt, workbench);
    write_skill_instructions(&mut prompt, skill_bundle);
    write_context_pack(&mut prompt, workbench);
    write_memory_pack(&mut prompt, workbench);
    write_visible_tools(&mut prompt, visible_tools);
    write_execution_boundaries(&mut prompt);

    prompt
}

/// write_agent_identity 写入助手身份
/// 核心职责：
/// - 投影 Agent 名称和职责
/// - 避免暴露 AgentDefinition 内部字段名
fn write_agent_identity(prompt: &mut String, workbench: &AgentSessionWorkbench) {
    writeln!(
        prompt,
        "助手: {}。职责: {}。",
        workbench.agent_definition.name, workbench.agent_definition.purpose
    )
    .expect("write workbench prompt");
}

/// write_capability_boundaries 写入能力边界
/// 核心职责：
/// - 投影本轮允许模型认知的能力域
/// - 使用自然语言描述替代枚举字段名
fn write_capability_boundaries(prompt: &mut String, workbench: &AgentSessionWorkbench) {
    prompt.push_str("能力边界:\n");
    for domain in &workbench.agent_definition.capability_domains {
        writeln!(prompt, "- {}", display_capability_domain(*domain))
            .expect("write workbench prompt");
    }
}

/// write_capabilities 写入可用能力
/// 核心职责：
/// - 投影能力目录的标题和使用边界
/// - 标明能力是否需要已选宠物上下文
fn write_capabilities(prompt: &mut String, workbench: &AgentSessionWorkbench) {
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
}

/// write_skill_instructions 写入 Skill 指令
/// 核心职责：
/// - 将内置 skill runtime 的匹配结果注入 prompt
/// - 保持 system/domain/workflow/personalization 固定顺序
fn write_skill_instructions(prompt: &mut String, skill_bundle: Option<&SkillBundle>) {
    prompt.push_str("Skill 指令:\n");
    let Some(skill_bundle) = skill_bundle else {
        prompt.push_str("- 无。\n");
        return;
    };
    if skill_bundle.active_skills.is_empty() {
        prompt.push_str("- 无。\n");
    } else {
        prompt.push_str(&skill_bundle.merged_instruction);
    }
}

/// write_context_pack 写入本轮上下文
/// 核心职责：
/// - 投影入口、语言、时区和已选宠物摘要
/// - 只输出白名单上下文字段
fn write_context_pack(prompt: &mut String, workbench: &AgentSessionWorkbench) {
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
}

/// write_memory_pack 写入记忆摘要
/// 核心职责：
/// - 投影已经过 scope 过滤的记忆摘要
/// - 避免输出记忆内部 payload
fn write_memory_pack(prompt: &mut String, workbench: &AgentSessionWorkbench) {
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
}

/// write_visible_tools 写入本轮可执行工具
/// 核心职责：
/// - 只投影 Runtime 已判定可见的工具 schema
/// - 支撑用户询问工具能力时的边界说明
fn write_visible_tools(prompt: &mut String, visible_tools: &[LlmToolSchema]) {
    prompt.push_str("本轮可执行工具:\n");
    if visible_tools.is_empty() {
        prompt.push_str("- 无。\n");
    } else {
        for tool in visible_tools {
            writeln!(prompt, "- {}：{}", tool.name, tool.description)
                .expect("write workbench prompt");
        }
    }
}

/// write_execution_boundaries 写入执行边界
/// 核心职责：
/// - 固定模型与 Tool Gateway 的职责边界
/// - 防止无工具结果时声称执行了副作用
fn write_execution_boundaries(prompt: &mut String) {
    prompt.push_str("执行边界:\n");
    prompt.push_str("- 工具只能由 Runtime Gateway 执行；模型只申请工具或基于已投影信息回答。\n");
    prompt.push_str("- 用户询问工具或可执行能力时，只能基于“本轮可执行工具”回答；工具列表为无时，说明本轮没有可执行工具。\n");
    prompt.push_str("- 没有工具成功结果时，不能声称已执行数据变更。\n");
}

fn display_capability_domain(domain: CapabilityDomain) -> &'static str {
    match domain {
        CapabilityDomain::PublicPetDomain => "公共宠物照护咨询",
        CapabilityDomain::PrivatePetContext => "授权宠物私域上下文",
        CapabilityDomain::AppProductSupport => "毛伙伴产品帮助",
        CapabilityDomain::AssistantIdentity => "助手身份说明",
        CapabilityDomain::HardSafety => "硬安全边界",
    }
}

fn display_surface(surface: AiConversationSurface) -> &'static str {
    match surface {
        AiConversationSurface::HomePrivate => "首页私域对话",
        AiConversationSurface::PetProfile => "宠物档案",
        AiConversationSurface::AbnormalDetail => "异常记录详情",
        AiConversationSurface::ConfirmationTask => "确认任务",
        AiConversationSurface::UgcComment => "社区评论",
    }
}

fn display_memory_scope(scope: MemoryScope) -> &'static str {
    match scope {
        MemoryScope::User => "用户记忆",
        MemoryScope::Pet => "宠物记忆",
        MemoryScope::Household => "家庭记忆",
        MemoryScope::Session => "会话记忆",
    }
}

fn display_species(species: &str) -> &str {
    match species {
        "cat" => "猫",
        "dog" => "狗",
        "other" => "其他",
        value => value,
    }
}
