use maohuoban_ai_domain::ai::{
    AgentSessionWorkbench, AiConversationSurface, AiIntent, CapabilityDomain, MemoryScope, Toolset,
};
use uuid::Uuid;

/// SkillMatchInput Skill 匹配输入
/// 核心职责：
/// - 将 gate、planner、workbench 和工具集上下文收敛为匹配视图
/// - 保持 SkillMatcher 不读取外部状态和不执行副作用
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SkillMatchInput {
    pub intent: Option<AiIntent>,
    pub task_type: Option<String>,
    pub surface: AiConversationSurface,
    pub capability_domains: Vec<CapabilityDomain>,
    pub capability_codes: Vec<String>,
    pub available_toolsets: Vec<Toolset>,
    pub actor_user_id: Option<Uuid>,
    pub household_id: Option<Uuid>,
    pub selected_pet_present: bool,
}

impl SkillMatchInput {
    /// from_workbench 从 Workbench 构建 Skill 匹配输入
    /// 核心职责：
    /// - 复用本轮能力目录和上下文，不额外加载私域数据
    /// - 将已注册可见工具集作为 skill policy 的输入
    #[must_use]
    pub fn from_workbench(
        workbench: &AgentSessionWorkbench,
        available_toolsets: Vec<Toolset>,
    ) -> Self {
        Self::from_runtime(workbench, available_toolsets, None, None)
    }

    /// from_runtime 从 Runtime 当前 turn 构建 Skill 匹配输入
    /// 核心职责：
    /// - 接收 planner 已判定 task type，支撑 workflow skill 命中
    /// - 接收执行上下文 actor，支撑 personalization skill 命中
    /// - 仅从已进入 workbench 的 household 记忆推导家庭上下文
    #[must_use]
    pub fn from_runtime(
        workbench: &AgentSessionWorkbench,
        available_toolsets: Vec<Toolset>,
        task_type: Option<&str>,
        actor_user_id: Option<Uuid>,
    ) -> Self {
        Self {
            intent: None,
            task_type: task_type.map(str::to_owned),
            surface: workbench.context_pack.surface,
            capability_domains: workbench.agent_definition.capability_domains.clone(),
            capability_codes: workbench
                .capability_catalog
                .capabilities
                .iter()
                .map(|capability| capability.code.clone())
                .collect(),
            available_toolsets,
            actor_user_id,
            household_id: household_id_from_workbench(workbench),
            selected_pet_present: workbench.context_pack.selected_pet.is_some(),
        }
    }
}

fn household_id_from_workbench(workbench: &AgentSessionWorkbench) -> Option<Uuid> {
    workbench
        .memory_pack
        .entries
        .iter()
        .find(|entry| entry.scope == MemoryScope::Household)
        .and_then(|entry| entry.subject_id)
}
