use serde::{Deserialize, Serialize};

use super::AgentCapability;

/// CapabilityCatalog Agent 能力目录
/// 核心职责：
/// - 汇总本轮可投影给模型的能力说明
/// - 只描述能力，不执行工具
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct CapabilityCatalog {
    pub capabilities: Vec<AgentCapability>,
}

impl CapabilityCatalog {
    /// has_private_capabilities 判断目录中是否包含私域能力
    /// 核心职责：
    /// - 检查是否有能力标记了 requires_private_context
    /// - 供 TurnContextBuilder 决定是否向模型暴露私域工具
    #[must_use]
    pub fn has_private_capabilities(&self) -> bool {
        self.capabilities
            .iter()
            .any(|capability| capability.requires_private_context)
    }
}
