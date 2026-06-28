use serde::{Deserialize, Serialize};

use super::{AgentDefinition, CapabilityCatalog, ContextPack, MemoryPack};

/// AgentSessionWorkbench Agent 单轮工作台
/// 核心职责：
/// - 汇总 Agent 定义、能力目录、上下文包和记忆包
/// - 作为 LoopEngine 的受控输入上下文
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AgentSessionWorkbench {
    pub agent_definition: AgentDefinition,
    pub capability_catalog: CapabilityCatalog,
    pub context_pack: ContextPack,
    pub memory_pack: MemoryPack,
}
