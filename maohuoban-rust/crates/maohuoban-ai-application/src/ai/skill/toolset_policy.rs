use std::collections::HashSet;

use maohuoban_ai_domain::ai::{SkillDefinition, SkillLayer, Toolset};

use crate::ai::tools::ToolDefinitionInfo;

/// SkillToolsetPolicy Skill 工具集策略
/// 核心职责：
/// - 将非 personalization skill 的工具集提示合并为缩小/排序策略
/// - 保证策略只能作用于已经可见的工具定义
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct SkillToolsetPolicy {
    pub allowed_toolsets: Option<Vec<Toolset>>,
    pub preferred_toolsets: Vec<Toolset>,
    pub preferred_tools: Vec<String>,
}

impl SkillToolsetPolicy {
    /// from_skills 从激活 skill 合并工具集策略
    /// 核心职责：
    /// - 忽略 personalization 层工具提示，防止影响授权边界
    /// - 多个 allowed_toolsets 取交集，保证只会继续缩小可见范围
    #[must_use]
    pub fn from_skills(skills: &[SkillDefinition]) -> Self {
        let mut allowed_toolsets: Option<Vec<Toolset>> = None;
        let mut preferred_toolsets = Vec::new();
        let mut preferred_tools = Vec::new();

        for skill in skills
            .iter()
            .filter(|skill| skill.layer != SkillLayer::Personalization)
        {
            let hints = &skill.toolset_hints;
            if !hints.allowed_toolsets.is_empty() {
                allowed_toolsets = Some(match allowed_toolsets {
                    Some(current) => intersect_toolsets(&current, &hints.allowed_toolsets),
                    None => unique_toolsets(&hints.allowed_toolsets),
                });
            }
            append_unique_toolsets(&mut preferred_toolsets, &hints.preferred_toolsets);
            append_unique_strings(&mut preferred_tools, &hints.preferred_tools);
        }

        Self {
            allowed_toolsets,
            preferred_toolsets,
            preferred_tools,
        }
    }

    /// apply_to_tool_definitions 应用到已可见工具
    /// 核心职责：
    /// - 只过滤和排序输入集合
    /// - 不创建、不注册、不恢复任何未授权工具
    #[must_use]
    pub fn apply_to_tool_definitions(
        &self,
        tools: Vec<ToolDefinitionInfo>,
    ) -> Vec<ToolDefinitionInfo> {
        let mut filtered = match &self.allowed_toolsets {
            Some(allowed) => tools
                .into_iter()
                .filter(|tool| allowed.contains(&tool.toolset))
                .collect(),
            None => tools,
        };

        filtered.sort_by(|left, right| {
            tool_rank(self, left)
                .cmp(&tool_rank(self, right))
                .then_with(|| left.name.cmp(&right.name))
        });
        filtered
    }
}

fn tool_rank(policy: &SkillToolsetPolicy, tool: &ToolDefinitionInfo) -> (usize, usize) {
    (
        policy
            .preferred_tools
            .iter()
            .position(|name| name == &tool.name)
            .unwrap_or(usize::MAX),
        policy
            .preferred_toolsets
            .iter()
            .position(|toolset| *toolset == tool.toolset)
            .unwrap_or(usize::MAX),
    )
}

fn intersect_toolsets(left: &[Toolset], right: &[Toolset]) -> Vec<Toolset> {
    let right: HashSet<Toolset> = right.iter().copied().collect();
    left.iter()
        .copied()
        .filter(|toolset| right.contains(toolset))
        .collect()
}

fn unique_toolsets(values: &[Toolset]) -> Vec<Toolset> {
    let mut output = Vec::new();
    append_unique_toolsets(&mut output, values);
    output
}

fn append_unique_toolsets(target: &mut Vec<Toolset>, values: &[Toolset]) {
    for value in values {
        if !target.contains(value) {
            target.push(*value);
        }
    }
}

fn append_unique_strings(target: &mut Vec<String>, values: &[String]) {
    for value in values {
        if !target.contains(value) {
            target.push(value.clone());
        }
    }
}
