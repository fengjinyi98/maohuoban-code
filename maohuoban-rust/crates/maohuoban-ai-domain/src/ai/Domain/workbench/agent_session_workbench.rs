use serde::{Deserialize, Serialize};

use super::{AgentDefinition, CapabilityCatalog, ContextPack, MemoryPack, RecentConversationPack};

/// AgentSessionWorkbench Agent 单轮工作台
/// 核心职责：
/// - 汇总 Agent 定义、能力目录、上下文包、记忆包和最近会话历史
/// - 作为 LoopEngine 的受控输入上下文
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AgentSessionWorkbench {
    pub agent_definition: AgentDefinition,
    pub capability_catalog: CapabilityCatalog,
    pub context_pack: ContextPack,
    pub memory_pack: MemoryPack,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub recent_conversation_pack: Option<RecentConversationPack>,
}
