use serde::{Deserialize, Serialize};

/// SkillLayer Skill 分层
/// 核心职责：
/// - 固定 system/domain/workflow/personalization 四层协议
/// - 提供跨层合并时的稳定优先级
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SkillLayer {
    System,
    Domain,
    Workflow,
    Personalization,
}

impl SkillLayer {
    /// as_str 返回稳定层级编码
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::System => "system",
            Self::Domain => "domain",
            Self::Workflow => "workflow",
            Self::Personalization => "personalization",
        }
    }

    /// priority_rank 返回跨层合并优先级
    /// 核心职责：
    /// - 保证 System 永远先于其他层
    /// - 保证 Personalization 永远不能覆盖授权边界
    #[must_use]
    pub const fn priority_rank(self) -> u8 {
        match self {
            Self::System => 0,
            Self::Domain => 1,
            Self::Workflow => 2,
            Self::Personalization => 3,
        }
    }
}
