use std::fmt::Write as _;

use maohuoban_ai_domain::ai::{SkillDefinition, SkillLayer};

use super::{SkillToolsetPolicy, SkillWorkflowPolicy};

/// SkillBundle 本轮激活 Skill 包
/// 核心职责：
/// - 固定 active_skills、merged_instruction、toolset_policy 和 workflow_policy 输出
/// - 按 system/domain/workflow/personalization 顺序投影 skill 指令
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SkillBundle {
    pub active_skills: Vec<SkillDefinition>,
    pub merged_instruction: String,
    pub toolset_policy: SkillToolsetPolicy,
    pub workflow_policy: SkillWorkflowPolicy,
}

impl SkillBundle {
    /// from_active_skills 从已排序 skill 构建输出包
    #[must_use]
    pub fn from_active_skills(active_skills: Vec<SkillDefinition>) -> Self {
        Self {
            merged_instruction: merged_instruction(&active_skills),
            toolset_policy: SkillToolsetPolicy::from_skills(&active_skills),
            workflow_policy: workflow_policy(&active_skills),
            active_skills,
        }
    }
}

fn merged_instruction(skills: &[SkillDefinition]) -> String {
    let mut output = String::new();
    for skill in skills {
        writeln!(
            output,
            "- [{}] {}：{}",
            skill.layer.as_str(),
            skill.skill_id,
            skill.title
        )
        .expect("write skill instruction");
        writeln!(output, "  {}", skill.instruction_block).expect("write skill instruction");
    }
    output
}

fn workflow_policy(skills: &[SkillDefinition]) -> SkillWorkflowPolicy {
    let mut policy = SkillWorkflowPolicy::default();
    for skill in skills
        .iter()
        .filter(|skill| skill.layer == SkillLayer::Workflow)
    {
        policy.workflow_skill_ids.push(skill.skill_id.clone());
        policy
            .instruction_blocks
            .push(skill.instruction_block.clone());
    }
    policy
}
