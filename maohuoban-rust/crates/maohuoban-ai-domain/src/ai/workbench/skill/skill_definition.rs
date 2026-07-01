use serde::{Deserialize, Serialize};

use super::{SkillLayer, SkillMatchConditions, SkillToolsetHints};

/// SkillDefinition 内置 Skill 定义
/// 核心职责：
/// - 描述 Skill 的身份、层级、匹配条件和注入指令
/// - 将工具集提示作为策略输入，而不是可执行动作
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SkillDefinition {
    pub skill_id: String,
    pub layer: SkillLayer,
    pub title: String,
    pub match_conditions: SkillMatchConditions,
    pub instruction_block: String,
    pub toolset_hints: SkillToolsetHints,
    pub priority: i32,
    pub mutable: bool,
}
