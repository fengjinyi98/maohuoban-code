use maohuoban_ai_application::ai::skill::SkillMatchInput;
use maohuoban_ai_application::ai::tools::{AiToolRiskLevel, ToolDefinitionInfo};
use maohuoban_ai_domain::ai::{
    AgentCapability, AgentDefinition, AgentId, AgentSessionWorkbench, AiConversationSurface,
    AiIntent, CapabilityCatalog, CapabilityDomain, ContextPack, ContextPetSummary, MemoryEntry,
    MemoryPack, MemoryScope, ModelLabel, SkillDefinition, SkillLayer, SkillMatchConditions,
    SkillToolsetHints, ToolProgressText, Toolset,
};
use serde_json::json;
use uuid::Uuid;

/// `system_skill` 构造系统层测试 skill
/// 核心职责：
/// - 固定系统层默认匹配条件
/// - 为排序和诊断合同测试提供最小 SkillDefinition
pub fn system_skill(id: &str, priority: i32, instruction: &str) -> SkillDefinition {
    SkillDefinition {
        skill_id: id.to_owned(),
        layer: SkillLayer::System,
        title: id.to_owned(),
        match_conditions: SkillMatchConditions::default(),
        instruction_block: instruction.to_owned(),
        toolset_hints: SkillToolsetHints::default(),
        priority,
        mutable: false,
    }
}

/// `domain_skill` 构造领域层测试 skill
/// 核心职责：
/// - 固定领域能力匹配条件
/// - 为分层顺序和能力命中测试提供输入
pub fn domain_skill(
    id: &str,
    domain: CapabilityDomain,
    priority: i32,
    instruction: &str,
) -> SkillDefinition {
    let mut conditions = SkillMatchConditions::default();
    conditions.capability_domains.push(domain);
    SkillDefinition {
        skill_id: id.to_owned(),
        layer: SkillLayer::Domain,
        title: id.to_owned(),
        match_conditions: conditions,
        instruction_block: instruction.to_owned(),
        toolset_hints: SkillToolsetHints::default(),
        priority,
        mutable: false,
    }
}

/// `workflow_skill` 构造流程层测试 skill
/// 核心职责：
/// - 固定任务类型匹配条件
/// - 为 workflow policy 合同测试提供输入
pub fn workflow_skill(
    id: &str,
    task_type: &str,
    priority: i32,
    instruction: &str,
) -> SkillDefinition {
    let mut conditions = SkillMatchConditions::default();
    conditions.task_types.push(task_type.to_owned());
    SkillDefinition {
        skill_id: id.to_owned(),
        layer: SkillLayer::Workflow,
        title: id.to_owned(),
        match_conditions: conditions,
        instruction_block: instruction.to_owned(),
        toolset_hints: SkillToolsetHints::default(),
        priority,
        mutable: false,
    }
}

/// `personalization_skill` 构造个性化层测试 skill
/// 核心职责：
/// - 固定 actor_user_id 匹配条件
/// - 为授权边界和层级顺序测试提供输入
pub fn personalization_skill(
    id: &str,
    actor_user_id: Uuid,
    priority: i32,
    instruction: &str,
) -> SkillDefinition {
    let mut conditions = SkillMatchConditions::default();
    conditions.actor_user_ids.push(actor_user_id);
    SkillDefinition {
        skill_id: id.to_owned(),
        layer: SkillLayer::Personalization,
        title: id.to_owned(),
        match_conditions: conditions,
        instruction_block: instruction.to_owned(),
        toolset_hints: SkillToolsetHints::default(),
        priority,
        mutable: true,
    }
}

/// `public_direct_input` 构造公共直答 skill 匹配输入
/// 核心职责：
/// - 固定公共宠物领域和 App 支持 toolset
/// - 为 matcher 合同测试提供无选中宠物输入
pub fn public_direct_input(actor_user_id: Option<Uuid>) -> SkillMatchInput {
    SkillMatchInput {
        intent: Some(AiIntent::Allowed),
        task_type: Some("direct_answer".to_owned()),
        surface: AiConversationSurface::HomePrivate,
        capability_domains: vec![CapabilityDomain::PublicPetDomain],
        capability_codes: vec!["public_pet_care".to_owned()],
        available_toolsets: vec![Toolset::PublicPetDomain, Toolset::AppSupport],
        actor_user_id,
        household_id: None,
        selected_pet_present: false,
    }
}

/// `tool_info` 构造工具定义快照
/// 核心职责：
/// - 固定测试工具元数据字段
/// - 为 toolset policy 过滤合同提供输入
pub fn tool_info(name: &str, toolset: Toolset, read_only: bool) -> ToolDefinitionInfo {
    ToolDefinitionInfo {
        name: name.to_owned(),
        description: name.to_owned(),
        parameters: json!({"type": "object"}),
        scope: format!("{name}.scope"),
        declared_requires_confirmation: !read_only,
        read_only,
        concurrency_safe: true,
        risk_level: AiToolRiskLevel::Low,
        requires_confirmation: !read_only,
        domain_tags: Vec::new(),
        toolset,
        progress_text: ToolProgressText::default(),
        result_fact_schema: None,
    }
}

/// `contract_workbench_with_household_memory` 构造带家庭记忆的 workbench
/// 核心职责：
/// - 固定私域宠物上下文和 household memory
/// - 为 runtime skill match 输入合同提供上下文
pub fn contract_workbench_with_household_memory(household_id: Uuid) -> AgentSessionWorkbench {
    AgentSessionWorkbench {
        agent_definition: AgentDefinition {
            agent_id: AgentId::main_pet_care_agent(),
            name: "毛球".to_owned(),
            purpose: "宠物垂直照护与用户宠物私域助手".to_owned(),
            default_model_label: ModelLabel::Primary,
            capability_domains: vec![CapabilityDomain::PrivatePetContext],
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
                pet_id: Uuid::new_v4(),
                name: "梅录".to_owned(),
                species: "cat".to_owned(),
            }),
            authorized_pets: Vec::new(),
            session_summary: None,
            pending_confirmation_task: None,
        },
        memory_pack: MemoryPack {
            entries: vec![MemoryEntry {
                scope: MemoryScope::Household,
                subject_id: Some(household_id),
                summary: "家庭有两只猫。".to_owned(),
            }],
        },
        recent_conversation_pack: None,
    }
}
