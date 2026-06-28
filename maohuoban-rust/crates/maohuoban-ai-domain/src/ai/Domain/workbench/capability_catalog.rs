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
