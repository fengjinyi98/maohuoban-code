use maohuoban_ai_application::ai::memory::{MemoryRecallBudget, MemoryRetriever};
use maohuoban_ai_application::ai::ports::MemoryQuery;
use maohuoban_ai_application::ai::turn_context::TurnContextBuilder;
use maohuoban_ai_domain::ai::{
    AgentSessionWorkbench, AiConversationSurface, AiPetDisplaySnapshot, MemoryEntry, MemoryPack,
    MemoryScope, RecentConversationPack,
};
use uuid::Uuid;

use super::super::super::AiHttpState;

/// build_agent_session_workbench 构建本轮 Agent 工作台
/// 核心职责：
/// - 委托 application 层 TurnContextBuilder 组装工作台上下文
/// - 透传会话摘要、记忆条目和同会话最近历史
/// - 只在已解析目标宠物时暴露私域宠物能力
pub(crate) fn build_agent_session_workbench(
    surface: AiConversationSurface,
    target_pet: Option<&AiPetDisplaySnapshot>,
    session_summary: Option<String>,
    memory_entries: Vec<MemoryEntry>,
    recent_conversation: RecentConversationPack,
) -> AgentSessionWorkbench {
    TurnContextBuilder::new(surface)
        .with_target_pet(target_pet.cloned())
        .with_session_summary(session_summary)
        .with_memory_entries(memory_entries)
        .with_recent_conversation(recent_conversation)
        .build()
}

/// load_memory_entries_for_workbench 加载本轮工作台记忆
/// 核心职责：
/// - 按 user / session / pet scope 分别发起系统侧召回
/// - 先由 MemoryRetriever 执行 scope 隔离，再合并本轮可见记忆
/// - 合并后执行统一 memory 预算裁剪
pub(crate) async fn load_memory_entries_for_workbench(
    state: &AiHttpState,
    actor_user_id: Uuid,
    session_id: Uuid,
    target_pet: Option<&AiPetDisplaySnapshot>,
) -> maohuoban_ai_domain::ai::AiResult<Vec<MemoryEntry>> {
    let retriever = MemoryRetriever::new(state.memory_repository.clone());
    let mut entries = Vec::new();

    let user_pack = retriever
        .retrieve(MemoryQuery::new(
            MemoryScope::User,
            actor_user_id,
            actor_user_id,
        ))
        .await?;
    entries.extend(user_pack.entries);

    let session_pack = retriever
        .retrieve(MemoryQuery::new(
            MemoryScope::Session,
            session_id,
            actor_user_id,
        ))
        .await?;
    entries.extend(session_pack.entries);

    if let Some(pet) = target_pet {
        let pet_pack = retriever
            .retrieve(
                MemoryQuery::new(MemoryScope::Pet, pet.pet_id, actor_user_id)
                    .with_pet_id(pet.pet_id),
            )
            .await?;
        entries.extend(pet_pack.entries);
    }

    Ok(MemoryRecallBudget::default_for_deepseek_1m()
        .trim(MemoryPack { entries })
        .entries)
}
