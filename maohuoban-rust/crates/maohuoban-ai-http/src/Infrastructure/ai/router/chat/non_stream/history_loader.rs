//! history_loader 非流式历史与摘要加载
//! 核心职责：
//! - 加载同会话历史（含归属校验和预算裁剪）
//! - 尝试压缩历史并生成摘要

use maohuoban_ai_application::ai::conversation_history::RecentConversationLoader;
use maohuoban_ai_application::ai::session_summary::SessionSummaryCompressor;
use maohuoban_ai_application::ai::turn_context::ContextBudgetPolicy;
use uuid::Uuid;

use super::super::super::AiHttpState;

pub(super) async fn load_history_and_summary_non_stream(
    state: &AiHttpState,
    actor_user_id: Uuid,
    session_id: Uuid,
    exclude_message_id: Uuid,
) -> (
    maohuoban_ai_domain::ai::RecentConversationPack,
    Option<String>,
) {
    let session_repo = &state.session_repository;
    let summary_repo = &state.session_summary_repository;
    let loader = RecentConversationLoader::new(session_repo.clone(), summary_repo.clone());

    let pack = if let Ok(pack) = loader
        .load_recent_conversation(
            actor_user_id,
            session_id,
            exclude_message_id,
            1_000_000,
            200_000,
        )
        .await
    {
        ContextBudgetPolicy::default_for_deepseek_1m().trim(&pack)
    } else {
        return (
            maohuoban_ai_domain::ai::RecentConversationPack::empty(),
            None,
        );
    };

    let compressor = SessionSummaryCompressor::new(
        state.llm_provider.clone(),
        state.session_summary_repository.clone(),
    );
    let Ok(raw_messages) = session_repo.list_messages_by_session(session_id).await else {
        return (pack, None);
    };
    if let Ok(Some(compressed)) = compressor
        .try_compress(
            session_id,
            actor_user_id,
            &raw_messages,
            3,
            Some(exclude_message_id),
        )
        .await
    {
        return (
            compressed.retained_tail,
            Some(compressed.summary.to_context_summary()),
        );
    }
    let summary_text = match compressor.load_active_summary(session_id).await {
        Ok(Some(s)) => Some(s.to_context_summary()),
        _ => None,
    };
    (pack, summary_text)
}
