use serde::{Deserialize, Serialize};

/// ModelLabel Runtime 模型标签
/// 核心职责：
/// - 使用毛伙伴稳定 label 屏蔽 Provider 真实模型名
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ModelLabel {
    Lite,
    Primary,
    Pro,
    Memory,
}

impl ModelLabel {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Lite => "lite",
            Self::Primary => "primary",
            Self::Pro => "pro",
            Self::Memory => "memory",
        }
    }
}
