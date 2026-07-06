// skill_runtime_contract WT09 Skill Runtime 合同测试
// 核心职责：
// - 固定 SkillDefinition、SkillMatcher 和 SkillBundle 的协议边界
// - 验证 skill 与 tool/planner/prompt 的分层关系

use maohuoban_ai_application::ai::planning::TaskType;
use maohuoban_ai_application::ai::skill::{
    BuiltinSkillRuntime, SkillDiagnosticsSnapshot, SkillMatchInput, SkillMatcher,
};
use maohuoban_ai_domain::ai::{
    AgentTurnId, AiConversationSurface, AiIntent, CapabilityDomain, SkillDefinition, SkillLayer,
    SkillMatchConditions, SkillToolsetHints, Toolset,
};
use serde_json::json;
use support::{
    contract_workbench_with_household_memory, domain_skill, personalization_skill,
    public_direct_input, system_skill, tool_info, workflow_skill,
};
use uuid::Uuid;

mod support;

#[test]
fn skill_definition_roundtrips_with_contract_fields() {
    let definition = SkillDefinition {
        skill_id: "system.medical_boundary".to_owned(),
        layer: SkillLayer::System,
        title: "医疗边界".to_owned(),
        match_conditions: SkillMatchConditions {
            intents: vec![AiIntent::Allowed],
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
    assert_eq!(value["match_conditions"]["intents"], json!(["allowed"]));
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
        intent: Some(AiIntent::Allowed),
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
        Some(TaskType::ContextAnswer.as_str()),
        Some(actor_user_id),
    );

    assert_eq!(input.task_type.as_deref(), Some("context_answer"));
    assert_eq!(input.actor_user_id, Some(actor_user_id));
    assert_eq!(input.household_id, Some(household_id));
}

#[test]
fn builtin_runtime_matches_abnormal_episode_proactive_followup_planning_skill() {
    let workbench = contract_workbench_with_household_memory(Uuid::new_v4());

    let bundle = BuiltinSkillRuntime::match_runtime(
        &workbench,
        vec![
            Toolset::PrivatePetContext,
            Toolset::Confirmation,
            Toolset::Temporal,
        ],
        Some("abnormal_episode_followup_planning"),
        Some(Uuid::new_v4()),
    );

    assert_eq!(
        bundle.workflow_policy.workflow_skill_ids,
        vec!["workflow.abnormal_episode_proactive_followup_planning"]
    );
    assert!(
        bundle
            .merged_instruction
            .contains("读取宠物身份档案、异常 episode、近期便便/精神/食欲、饮食和储物柜线索"),
        "planning skill should force multi-source evidence before planning: {}",
        bundle.merged_instruction
    );
    assert!(
        bundle
            .merged_instruction
            .contains("信息断层按 now_at - max(occurred_at,last_observed_at) 理解"),
        "planning skill should define the plan contract: {}",
        bundle.merged_instruction
    );
    assert!(
        bundle.merged_instruction.contains("time_decision")
            && bundle.merged_instruction.contains("attention_timing")
            && bundle.merged_instruction.contains("staleness_assessment")
            && bundle.merged_instruction.contains("identity_context")
            && bundle.merged_instruction.contains("urgency_window")
            && bundle.merged_instruction.contains("time_tool_used"),
        "planning skill should require auditable model-owned time reasoning: {}",
        bundle.merged_instruction
    );
    assert!(
        bundle
            .merged_instruction
            .contains("弱线索只能作为待确认询问方向"),
        "planning skill should keep weak hints out of confirmed rationale: {}",
        bundle.merged_instruction
    );
    assert!(
        bundle.merged_instruction.contains("08:51 属于早上或上午"),
        "planning skill should keep Chinese day-period wording consistent with local event time: {}",
        bundle.merged_instruction
    );
    assert!(
        bundle
            .toolset_policy
            .preferred_toolsets
            .contains(&Toolset::PrivatePetContext)
            && bundle
                .toolset_policy
                .preferred_toolsets
                .contains(&Toolset::Temporal),
        "planning skill should prefer private facts and temporal helpers: {:?}",
        bundle.toolset_policy.preferred_toolsets
    );
    for expected_tool in [
        "load_pet_identity_context",
        "load_pet_abnormal_episode_facts",
        "load_pet_recent_health_facts",
        "load_pet_current_diet_context",
        "load_food_inventory_change_hints",
    ] {
        assert!(
            bundle
                .toolset_policy
                .preferred_tools
                .contains(&expected_tool.to_owned()),
            "missing preferred planning tool {expected_tool}: {:?}",
            bundle.toolset_policy.preferred_tools
        );
    }
}

#[test]
fn builtin_runtime_always_matches_temporal_reasoning_skill() {
    let workbench = contract_workbench_with_household_memory(Uuid::new_v4());

    let bundle = BuiltinSkillRuntime::match_workbench(&workbench, vec![]);

    assert!(
        bundle
            .active_skills
            .iter()
            .any(|skill| skill.skill_id == "temporal.reasoning"),
        "temporal reasoning skill should be active for every turn"
    );
    assert!(
        bundle.merged_instruction.contains("可信时间上下文")
            && bundle.merged_instruction.contains("日期派生事实"),
        "temporal skill must force trusted temporal context usage: {}",
        bundle.merged_instruction
    );
}

#[test]
fn builtin_runtime_temporal_skill_prefers_date_calculator_toolset() {
    let workbench = contract_workbench_with_household_memory(Uuid::new_v4());

    let bundle = BuiltinSkillRuntime::match_workbench(&workbench, vec![Toolset::Temporal]);

    assert!(
        bundle
            .toolset_policy
            .preferred_toolsets
            .contains(&Toolset::Temporal),
        "temporal reasoning should prefer temporal tools when available: {:?}",
        bundle.toolset_policy.preferred_toolsets
    );
    assert!(
        bundle
            .toolset_policy
            .preferred_tools
            .contains(&"date_calculator".to_owned()),
        "temporal reasoning should prefer date_calculator for relative date tasks: {:?}",
        bundle.toolset_policy.preferred_tools
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
