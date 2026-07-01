use serde::{Deserialize, Serialize};

/// MAIN_PET_CARE_AGENT_ID 首期主 Agent 标识
/// 核心职责：
/// - 固定 WT01 冻结的主 Agent 名称
/// - 供 Runtime 事件、Session 和后续 Adapter 共享
pub const MAIN_PET_CARE_AGENT_ID: &str = "main_pet_care_agent";

/// AgentId Runtime agent 标识
/// 核心职责：
/// - 表达当前 session 由哪个 Agent 定义驱动
/// - 首期只提供 main_pet_care_agent，预留多 Agent 扩展
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(transparent)]
pub struct AgentId(String);

impl AgentId {
    pub fn main_pet_care_agent() -> Self {
        Self(MAIN_PET_CARE_AGENT_ID.to_owned())
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}
