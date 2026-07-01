use serde::{Deserialize, Serialize};

use crate::ai::Toolset;

/// SkillToolsetHints Skill 工具集提示
/// 核心职责：
/// - 表达 skill 对本轮 toolset 的缩小和排序建议
/// - 保持授权边界仍由 Runtime Tool Gateway 和 PolicyGuard 控制
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct SkillToolsetHints {
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub allowed_toolsets: Vec<Toolset>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub preferred_toolsets: Vec<Toolset>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub preferred_tools: Vec<String>,
}

impl SkillToolsetHints {
    /// is_empty 判断是否没有工具集提示
    #[must_use]
    pub fn is_empty(&self) -> bool {
        self.allowed_toolsets.is_empty()
            && self.preferred_toolsets.is_empty()
            && self.preferred_tools.is_empty()
    }
}
