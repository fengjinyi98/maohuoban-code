use serde::{Deserialize, Serialize};

use super::CapabilityDomain;

/// AgentCapability 单项能力说明
/// 核心职责：
/// - 给模型说明某个能力何时可用
/// - 标记该能力是否需要私域宠物上下文
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AgentCapability {
    pub code: String,
    pub domain: CapabilityDomain,
    pub title: String,
    pub when_to_use: String,
    pub requires_private_context: bool,
}
