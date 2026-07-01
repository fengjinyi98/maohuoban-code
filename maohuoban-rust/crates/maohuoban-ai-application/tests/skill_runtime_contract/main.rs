// skill_runtime_contract WT09 Skill Runtime 合同测试
// 核心职责：
// - 固定 SkillDefinition、SkillMatcher 和 SkillBundle 的协议边界
// - 验证 skill 与 tool/planner/prompt 的分层关系

use maohuoban_ai_application::ai::planning::TaskType;
use maohuoban_ai_application::ai::skill::{
    BuiltinSkillRuntime, SkillDiagnosticsSnapshot, SkillMatchInput, SkillMatcher,
};
use maohuoban_ai_application::ai::tools::{AiToolRiskLevel, ToolDefinitionInfo};
use maohuoban_ai_domain::ai::{
    AgentCapability, AgentDefinition, AgentId, AgentSessionWorkbench, AgentTurnId,
    AiConversationSurface, AiIntent, CapabilityCatalog, CapabilityDomain, ContextPack,
    ContextPetSummary, MemoryEntry, MemoryPack, MemoryScope, ModelLabel, SkillDefinition,
    SkillLayer, SkillMatchConditions, SkillToolsetHints, ToolProgressText, Toolset,
};
use serde_json::json;
use uuid::Uuid;

#[test]
fn skill_definition_roundtrips_with_contract_fields() {
    let definition = SkillDefinition {
        skill_id: "system.medical_boundary".to_owned(),
        layer: SkillLayer::System,
        title: "医疗边界".to_owned(),
        match_conditions: SkillMatchConditions {
            intents: vec![AiIntent::PetHealthRisk],
            capability_domains: vec![CapabilityDomain::HardSafety],
            capability_codes: vec!["hard_safety".to_owned()],
            task_types: vec!["clarification_task".to_owned()],
            surfaces: vec![AiConversationSurface::HomePrivate],
            toolsets: vec![Toolset::PublicPetDomain],
            actor_user_ids: Vec::new(),
            household_ids: Vec::new(),
            requires_selected_pet: Some(false),
        },
        instruction_block: "不能替代兽医诊断；涉及症状风险时给出观察边界和就医建议。".to_owned(),
        toolset_hints: SkillToolsetHints {
            allowed_toolsets: vec![Toolset::PublicPetDomain],
            preferred_toolsets: vec![Toolset::PublicPetDomain],
            preferred_tools: vec!["load_public_pet_care_guidance".to_owned()],
        },
        priority: 100,
        mutable: false,
    };

    let value = serde_json::to_value(&definition).expect("serialize skill definition");

    assert_eq!(value["skill_id"], json!("system.medical_boundary"));
    assert_eq!(value["layer"], json!("system"));
    assert_eq!(
        value["match_conditions"]["intents"],
        json!(["pet_health_risk"])
    );
    assert_eq!(
        value["toolset_hints"]["allowed_toolsets"],
        json!(["public_pet_domain"])
    );
    assert_eq!(value["mutable"], json!(false));

    let decoded =
        serde_json::from_value::<SkillDefinition>(value).expect("deserialize skill definition");
    assert_eq!(decoded, definition);
}

#[test]
fn skill_matcher_hits_system_domain_workflow_and_personalization_layers() {
    let actor_user_id = Uuid::new_v4();
    let skills = vec![
        system_skill("system.boundary", 1, "系统边界。"),
        domain_skill(
            "domain.private_pet_context",
            CapabilityDomain::PrivatePetContext,
            10,
            "私域宠物上下文规则。",
        ),
        workflow_skill(
            "workflow.evidence_read",
            "evidence_read_task",
            20,
            "先取证再回答。",
        ),
        personalization_skill(
            "personalization.user_tone",
            actor_user_id,
            30,
            "使用用户偏好的简短口吻。",
        ),
    ];
    let input = SkillMatchInput {
        intent: Some(AiIntent::PetFood),
        task_type: Some("evidence_read_task".to_owned()),
        surface: AiConversationSurface::HomePrivate,
        capability_domains: vec![CapabilityDomain::PrivatePetContext],
        capability_codes: vec!["private_pet_context".to_owned()],
        available_toolsets: vec![Toolset::PrivatePetContext],
        actor_user_id: Some(actor_user_id),
        household_id: None,
        selected_pet_present: true,
    };

    let bundle = SkillMatcher::match_skills(&skills, &input);

    assert_eq!(
        bundle
            .active_skills
            .iter()
            .map(|skill| skill.skill_id.as_str())
            .collect::<Vec<_>>(),
        vec![
            "system.boundary",
            "domain.private_pet_context",
            "workflow.evidence_read",
            "personalization.user_tone",
        ]
    );
    assert!(
        bundle.merged_instruction.find("系统边界。")
            < bundle.merged_instruction.find("私域宠物上下文规则。")
    );
    assert!(
        bundle.merged_instruction.find("私域宠物上下文规则。")
            < bundle.merged_instruction.find("先取证再回答。")
    );
    assert!(
        bundle.merged_instruction.find("先取证再回答。")
            < bundle.merged_instruction.find("使用用户偏好的简短口吻。")
    );
}

#[test]
fn skill_bundle_orders_by_layer_before_numeric_priority() {
    let skills = vec![
        personalization_skill(
            "personalization.high_priority",
            Uuid::nil(),
            10_000,
            "个性化高数值优先级。",
        ),
        domain_skill(
            "domain.low",
            CapabilityDomain::PublicPetDomain,
            1,
            "低优先级领域规则。",
        ),
        domain_skill(
            "domain.high",
            CapabilityDomain::PublicPetDomain,
            10,
            "高优先级领域规则。",
        ),
        workflow_skill("workflow.middle", "direct_answer", 100, "流程规则。"),
        system_skill("system.zero", 0, "系统规则。"),
    ];
    let input = public_direct_input(Some(Uuid::nil()));

    let bundle = SkillMatcher::match_skills(&skills, &input);

    assert_eq!(
        bundle
            .active_skills
            .iter()
            .map(|skill| skill.skill_id.as_str())
            .collect::<Vec<_>>(),
        vec![
            "system.zero",
            "domain.high",
            "domain.low",
            "workflow.middle",
            "personalization.high_priority",
        ]
    );
}

#[test]
fn toolset_policy_can_only_shrink_or_order_visible_tools() {
    let mut skill = workflow_skill(
        "workflow.app_help_only",
        "direct_answer",
        10,
        "只使用 App 帮助工具。",
    );
    skill.toolset_hints = SkillToolsetHints {
        allowed_toolsets: vec![Toolset::AppSupport],
        preferred_toolsets: vec![Toolset::AppSupport],
        preferred_tools: vec!["explain_app_feature".to_owned()],
    };
    let bundle = SkillMatcher::match_skills(&[skill], &public_direct_input(None));

    let filtered = bundle.toolset_policy.apply_to_tool_definitions(vec![
        tool_info(
            "load_pet_identity_context",
            Toolset::PrivatePetContext,
            true,
        ),
        tool_info("public_pet_answer", Toolset::PublicPetDomain, true),
        tool_info("explain_app_feature", Toolset::AppSupport, true),
    ]);

    assert_eq!(
        filtered
            .iter()
            .map(|tool| tool.name.as_str())
            .collect::<Vec<_>>(),
        vec!["explain_app_feature"]
    );

    let not_authorized = bundle
        .toolset_policy
        .apply_to_tool_definitions(vec![tool_info(
            "public_pet_answer",
            Toolset::PublicPetDomain,
            true,
        )]);
    assert!(
        not_authorized.is_empty(),
        "skill policy may remove base-visible tools but cannot synthesize newly authorized tools"
    );
}

#[test]
fn personalization_skill_only_changes_expression_not_authorization_boundary() {
    let actor_user_id = Uuid::new_v4();
    let mut skill = personalization_skill(
        "personalization.try_private_tool",
        actor_user_id,
        999,
        "用更短的称呼回复。",
    );
    skill.toolset_hints = SkillToolsetHints {
        allowed_toolsets: vec![Toolset::PrivatePetContext],
        preferred_toolsets: vec![Toolset::PrivatePetContext],
        preferred_tools: vec!["load_pet_identity_context".to_owned()],
    };
    let bundle = SkillMatcher::match_skills(&[skill], &public_direct_input(Some(actor_user_id)));

    assert!(bundle.merged_instruction.contains("用更短的称呼回复。"));
    assert!(bundle.toolset_policy.allowed_toolsets.is_none());
    assert!(
        bundle.toolset_policy.preferred_toolsets.is_empty()
            && bundle.toolset_policy.preferred_tools.is_empty()
    );
}

#[test]
fn workflow_skill_enters_workflow_policy_without_replacing_planner() {
    let skill = workflow_skill(
        "workflow.evidence_before_answer",
        "evidence_read_task",
        10,
        "私域事实问题必须先读证据，再交给 planner 推进。",
    );
    let mut input = public_direct_input(None);
    input.task_type = Some("evidence_read_task".to_owned());

    let bundle = SkillMatcher::match_skills(&[skill], &input);

    assert_eq!(
        bundle.workflow_policy.workflow_skill_ids,
        vec!["workflow.evidence_before_answer"]
    );
    assert_eq!(
        bundle.workflow_policy.instruction_blocks,
        vec!["私域事实问题必须先读证据，再交给 planner 推进。"]
    );
}

#[test]
fn runtime_match_input_carries_planner_actor_and_household_context() {
    let actor_user_id = Uuid::new_v4();
    let household_id = Uuid::new_v4();
    let workbench = contract_workbench_with_household_memory(household_id);

    let input = SkillMatchInput::from_runtime(
        &workbench,
        vec![Toolset::PrivatePetContext],
        Some(TaskType::WriteTask.as_str()),
        Some(actor_user_id),
    );

    assert_eq!(input.task_type.as_deref(), Some("write_task"));
    assert_eq!(input.actor_user_id, Some(actor_user_id));
    assert_eq!(input.household_id, Some(household_id));
}

#[test]
fn builtin_runtime_matches_workflow_skill_from_runtime_task_type() {
    let workbench = contract_workbench_with_household_memory(Uuid::new_v4());

    let bundle = BuiltinSkillRuntime::match_runtime(
        &workbench,
        vec![Toolset::PrivatePetContext],
        Some(TaskType::WriteTask.as_str()),
        Some(Uuid::new_v4()),
    );

    assert_eq!(
        bundle.workflow_policy.workflow_skill_ids,
        vec!["workflow.write_requires_confirmation"]
    );
}

#[test]
fn skill_diagnostics_snapshot_freezes_event_fields() {
    let session_id = Uuid::new_v4();
    let turn_id = AgentTurnId::new();
    let message_id = Uuid::new_v4();
    let bundle = SkillMatcher::match_skills(
        &[
            system_skill("system.boundary", 1, "系统边界。"),
            domain_skill(
                "domain.public_pet",
                CapabilityDomain::PublicPetDomain,
                1,
                "公共宠物规则。",
            ),
        ],
        &public_direct_input(None),
    );

    let metadata =
        SkillDiagnosticsSnapshot::new(session_id, turn_id, message_id, &bundle).to_metadata();

    assert_eq!(
        SkillDiagnosticsSnapshot::event_name(),
        "ai.chat.skill.matched"
    );
    assert_eq!(metadata["session_id"], json!(session_id));
    assert_eq!(metadata["turn_id"], json!(turn_id.as_uuid()));
    assert_eq!(metadata["message_id"], json!(message_id));
    assert_eq!(
        metadata["active_skill_ids"],
        json!(["system.boundary", "domain.public_pet"])
    );
    assert_eq!(metadata["active_skill_layers"], json!(["system", "domain"]));
    assert_eq!(metadata["toolset_allowed_toolsets"], json!([]));
    assert_eq!(metadata["workflow_skill_ids"], json!([]));
    assert!(
        metadata["merged_instruction_length"]
            .as_u64()
            .is_some_and(|value| value > 0)
    );
}

fn system_skill(id: &str, priority: i32, instruction: &str) -> SkillDefinition {
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

fn domain_skill(
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

fn workflow_skill(id: &str, task_type: &str, priority: i32, instruction: &str) -> SkillDefinition {
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

fn personalization_skill(
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

fn public_direct_input(actor_user_id: Option<Uuid>) -> SkillMatchInput {
    SkillMatchInput {
        intent: Some(AiIntent::PetCare),
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

fn tool_info(name: &str, toolset: Toolset, read_only: bool) -> ToolDefinitionInfo {
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

fn contract_workbench_with_household_memory(household_id: Uuid) -> AgentSessionWorkbench {
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
            selected_pet: Some(ContextPetSummary {
                pet_id: Uuid::new_v4(),
                name: "梅录".to_owned(),
                species: "cat".to_owned(),
            }),
            authorized_pets: Vec::new(),
            session_summary: None,
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
