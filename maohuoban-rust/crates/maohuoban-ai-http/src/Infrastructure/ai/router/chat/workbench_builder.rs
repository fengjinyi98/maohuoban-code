use maohuoban_ai_application::ai::turn_context::TurnContextBuilder;
use maohuoban_ai_domain::ai::{
    AgentSessionWorkbench, AiConversationSurface, AiPetDisplaySnapshot, MemoryEntry,
};

/// build_agent_session_workbench 构建本轮 Agent 工作台
/// 核心职责：
/// - 委托 application 层 TurnContextBuilder 组装工作台上下文
/// - 透传会话摘要和记忆条目，确保 runtime turn 可获取前置上下文
/// - 只在已解析目标宠物时暴露私域宠物能力
pub(super) fn build_agent_session_workbench(
    surface: AiConversationSurface,
    target_pet: Option<&AiPetDisplaySnapshot>,
    session_summary: Option<String>,
    memory_entries: Vec<MemoryEntry>,
) -> AgentSessionWorkbench {
    TurnContextBuilder::new(surface)
        .with_target_pet(target_pet.cloned())
        .with_session_summary(session_summary)
        .with_memory_entries(memory_entries)
        .build()
}
