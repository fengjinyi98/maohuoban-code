use maohuoban_ai_domain::ai::{
    AgentSessionWorkbench, CapabilityDomain, SkillDefinition, SkillLayer, SkillMatchConditions,
    SkillToolsetHints, Toolset,
};
use uuid::Uuid;

use super::{SkillBundle, SkillMatchInput, SkillMatcher};

/// BuiltinSkillRuntime 内置 Skill Runtime
/// 核心职责：
/// - 提供工程内置 skill 定义
/// - 基于 Workbench 生成本轮 SkillBundle
pub struct BuiltinSkillRuntime;

impl BuiltinSkillRuntime {
    /// definitions 返回内置 skill 定义
    /// 核心职责：
    /// - 固定当前阶段系统和领域 skill
    /// - 不加载用户自定义 skill 平台
    #[must_use]
    pub fn definitions() -> Vec<SkillDefinition> {
        vec![
            system_tool_gateway_boundary(),
            system_safety_boundary(),
            temporal_reasoning(),
            domain_public_pet_care(),
            domain_private_pet_context(),
            domain_app_support(),
            workflow_abnormal_episode_proactive_followup_planning(),
        ]
    }

    /// match_workbench 基于 Workbench 匹配内置 skill
    #[must_use]
    pub fn match_workbench(
        workbench: &AgentSessionWorkbench,
        available_toolsets: Vec<Toolset>,
    ) -> SkillBundle {
        let input = SkillMatchInput::from_workbench(workbench, available_toolsets);
        SkillMatcher::match_skills(&Self::definitions(), &input)
    }

    /// match_runtime 基于 Runtime 当前 turn 匹配内置 skill
    /// 核心职责：
    /// - 将 planner task type 纳入 workflow skill 匹配
    /// - 将 actor_user_id 纳入 personalization skill 匹配
    #[must_use]
    pub fn match_runtime(
        workbench: &AgentSessionWorkbench,
        available_toolsets: Vec<Toolset>,
        task_type: Option<&str>,
        actor_user_id: Option<Uuid>,
    ) -> SkillBundle {
        let input =
            SkillMatchInput::from_runtime(workbench, available_toolsets, task_type, actor_user_id);
        SkillMatcher::match_skills(&Self::definitions(), &input)
    }
}

fn system_tool_gateway_boundary() -> SkillDefinition {
    SkillDefinition {
        skill_id: "system.tool_gateway_boundary".to_owned(),
        layer: SkillLayer::System,
        title: "Tool Gateway 边界".to_owned(),
        match_conditions: SkillMatchConditions::default(),
        instruction_block:
            "skill 只提供规则和流程模板，不直接执行副作用；所有工具调用必须通过 Runtime Tool Gateway 与 PolicyGuard。"
                .to_owned(),
        toolset_hints: SkillToolsetHints::default(),
        priority: 1_000,
        mutable: false,
    }
}

fn system_safety_boundary() -> SkillDefinition {
    SkillDefinition {
        skill_id: "system.safety_boundary".to_owned(),
        layer: SkillLayer::System,
        title: "平台硬安全边界".to_owned(),
        match_conditions: SkillMatchConditions::default(),
        instruction_block:
            "医疗、隐私和写入边界优先于领域流程；需要写入或高风险动作时必须进入确认路径。"
                .to_owned(),
        toolset_hints: SkillToolsetHints::default(),
        priority: 900,
        mutable: false,
    }
}

fn temporal_reasoning() -> SkillDefinition {
    SkillDefinition {
        skill_id: "temporal.reasoning".to_owned(),
        layer: SkillLayer::System,
        title: "时间推理边界".to_owned(),
        match_conditions: SkillMatchConditions::default(),
        instruction_block:
            "涉及今天、昨天、明天、生日、年龄、到家天数、提醒日期或周期时，必须优先使用本轮可信时间上下文和日期派生事实；缺少可信时间或事实时直接说明无法确定，不能自造当前日期。"
                .to_owned(),
        toolset_hints: SkillToolsetHints {
            allowed_toolsets: Vec::new(),
            preferred_toolsets: vec![Toolset::Temporal],
            preferred_tools: vec!["date_calculator".to_owned()],
        },
        priority: 850,
        mutable: false,
    }
}

fn domain_public_pet_care() -> SkillDefinition {
    domain_skill(
        "domain.public_pet_care",
        "公共宠物照护",
        CapabilityDomain::PublicPetDomain,
        "公共养宠问题只基于通用照护知识和已投影上下文回答；不能声称读取了私域记录。",
        100,
        SkillToolsetHints::default(),
        None,
    )
}

fn domain_private_pet_context() -> SkillDefinition {
    domain_skill(
        "domain.private_pet_context",
        "授权宠物私域上下文",
        CapabilityDomain::PrivatePetContext,
        "私域宠物事实必须来自已授权 workbench、工具结果或记忆摘要；弱线索只能作为提示或确认候选。",
        100,
        SkillToolsetHints {
            allowed_toolsets: Vec::new(),
            preferred_toolsets: vec![Toolset::PrivatePetContext, Toolset::Confirmation],
            preferred_tools: Vec::new(),
        },
        Some(true),
    )
}

fn domain_app_support() -> SkillDefinition {
    domain_skill(
        "domain.app_support",
        "毛伙伴 App 帮助",
        CapabilityDomain::AppProductSupport,
        "App 帮助问题只说明产品页面、流程和入口；不顺手加载或泄露宠物私域事实。",
        80,
        SkillToolsetHints {
            allowed_toolsets: Vec::new(),
            preferred_toolsets: vec![Toolset::AppSupport],
            preferred_tools: Vec::new(),
        },
        None,
    )
}

fn workflow_abnormal_episode_proactive_followup_planning() -> SkillDefinition {
    let mut conditions = SkillMatchConditions::default();
    conditions
        .task_types
        .push("abnormal_episode_followup_planning".to_owned());
    conditions.requires_selected_pet = Some(true);

    SkillDefinition {
        skill_id: "workflow.abnormal_episode_proactive_followup_planning".to_owned(),
        layer: SkillLayer::Workflow,
        title: "异常 episode 主动追踪规划".to_owned(),
        match_conditions: conditions,
        instruction_block:
            "异常主动追踪 planning 必须先读取异常 episode、近期便便/精神/食欲、饮食和储物柜线索，再输出 due_at、追问文案、规划理由和推荐动作；skill 只产出计划草稿，保存计划必须交给受控 tool 和 application service 校验。"
                .to_owned(),
        toolset_hints: SkillToolsetHints {
            allowed_toolsets: Vec::new(),
            preferred_toolsets: vec![Toolset::PrivatePetContext, Toolset::Temporal],
            preferred_tools: vec![
                "load_pet_abnormal_episode_facts".to_owned(),
                "load_pet_recent_health_facts".to_owned(),
                "load_pet_current_diet_context".to_owned(),
                "load_food_inventory_change_hints".to_owned(),
                "date_calculator".to_owned(),
            ],
        },
        priority: 200,
        mutable: false,
    }
}

fn domain_skill(
    id: &str,
    title: &str,
    domain: CapabilityDomain,
    instruction: &str,
    priority: i32,
    toolset_hints: SkillToolsetHints,
    requires_selected_pet: Option<bool>,
) -> SkillDefinition {
    let mut conditions = SkillMatchConditions::default();
    conditions.capability_domains.push(domain);
    conditions.requires_selected_pet = requires_selected_pet;
    SkillDefinition {
        skill_id: id.to_owned(),
        layer: SkillLayer::Domain,
        title: title.to_owned(),
        match_conditions: conditions,
        instruction_block: instruction.to_owned(),
        toolset_hints,
        priority,
        mutable: false,
    }
}
