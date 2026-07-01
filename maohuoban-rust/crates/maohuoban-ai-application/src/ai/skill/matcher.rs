use maohuoban_ai_domain::ai::{SkillDefinition, SkillLayer, SkillMatchConditions};

use super::{SkillBundle, SkillMatchInput};

/// SkillMatcher 内置 Skill 匹配器
/// 核心职责：
/// - 根据本轮 intent、task、workbench 和用户作用域选择 skill
/// - 按固定层级优先级输出稳定 SkillBundle
pub struct SkillMatcher;

impl SkillMatcher {
    /// match_skills 匹配并合并 skill
    #[must_use]
    pub fn match_skills(skills: &[SkillDefinition], input: &SkillMatchInput) -> SkillBundle {
        let mut active_skills = skills
            .iter()
            .filter(|skill| skill_matches(skill, input))
            .cloned()
            .collect::<Vec<_>>();
        active_skills.sort_by(|left, right| {
            left.layer
                .priority_rank()
                .cmp(&right.layer.priority_rank())
                .then_with(|| right.priority.cmp(&left.priority))
                .then_with(|| left.skill_id.cmp(&right.skill_id))
        });
        SkillBundle::from_active_skills(active_skills)
    }
}

fn skill_matches(skill: &SkillDefinition, input: &SkillMatchInput) -> bool {
    if skill.layer == SkillLayer::System {
        return true;
    }
    let conditions = &skill.match_conditions;
    if conditions.is_empty() {
        return false;
    }
    matches_conditions(conditions, input)
}

fn matches_conditions(conditions: &SkillMatchConditions, input: &SkillMatchInput) -> bool {
    matches_optional(&conditions.intents, input.intent)
        && matches_optional_str(&conditions.task_types, input.task_type.as_deref())
        && matches_optional(&conditions.surfaces, Some(input.surface))
        && matches_any(&conditions.capability_domains, &input.capability_domains)
        && matches_any_str(&conditions.capability_codes, &input.capability_codes)
        && matches_any(&conditions.toolsets, &input.available_toolsets)
        && matches_optional(&conditions.actor_user_ids, input.actor_user_id)
        && matches_optional(&conditions.household_ids, input.household_id)
        && conditions
            .requires_selected_pet
            .is_none_or(|required| required == input.selected_pet_present)
}

fn matches_optional<T: PartialEq>(expected: &[T], actual: Option<T>) -> bool {
    expected.is_empty() || actual.is_some_and(|actual| expected.contains(&actual))
}

fn matches_optional_str(expected: &[String], actual: Option<&str>) -> bool {
    expected.is_empty() || actual.is_some_and(|actual| expected.iter().any(|value| value == actual))
}

fn matches_any<T: PartialEq>(expected: &[T], actual: &[T]) -> bool {
    expected.is_empty() || expected.iter().any(|value| actual.contains(value))
}

fn matches_any_str(expected: &[String], actual: &[String]) -> bool {
    expected.is_empty() || expected.iter().any(|value| actual.contains(value))
}
