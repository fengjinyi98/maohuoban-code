use serde::{Deserialize, Serialize};

use crate::ai::{AgentId, CapabilityDomain, ModelLabel};

/// AgentDefinition Agent 基础定义
/// 核心职责：
/// - 描述当前工作台使用的 Agent 身份和默认模型
/// - 给 LoopEngine 提供稳定的能力域声明
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AgentDefinition {
    pub agent_id: AgentId,
    pub name: String,
    pub purpose: String,
    pub default_model_label: ModelLabel,
    pub capability_domains: Vec<CapabilityDomain>,
}
