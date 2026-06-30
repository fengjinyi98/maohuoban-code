use chrono::{DateTime, Utc};
use maohuoban_ai_application::ai::ports::AiSessionRepository;
use maohuoban_ai_domain::ai::{
    AiChatSession, AiChatSessionStatus, AiMessage, AiMessageRole, AiMessageStatus,
    AiPetDisplaySnapshot,
};
use uuid::Uuid;

use super::super::super::diagnostics::record_chat_session_persisted;
use super::super::composition::request::ChatStreamRequest;

/// PetSessionContext AI 会话宠物上下文
/// 核心职责：
/// - 承载后端解析后的主宠物 ID
/// - 承载用于历史展示的宠物快照
pub(crate) struct PetSessionContext {
    pub(crate) primary_pet_id: Option<Uuid>,
    pub(crate) pet_display_snapshot: Option<AiPetDisplaySnapshot>,
}

/// persist_session_and_user_message 持久化会话和用户消息
/// 核心职责：
/// - 创建或更新 AI 会话记录
/// - 使用 handler 传入的 message_id 保存本轮用户消息
#[allow(clippy::too_many_arguments)]
pub(crate) async fn persist_session_and_user_message(
    repo: &std::sync::Arc<dyn AiSessionRepository>,
    req: &ChatStreamRequest,
    actor_user_id: Uuid,
    session_id: Uuid,
    message_id: Uuid,
    title: String,
    pet_context: PetSessionContext,
    now: DateTime<Utc>,
) {
    let session = AiChatSession {
        id: session_id,
        actor_user_id,
        primary_pet_id: pet_context.primary_pet_id,
        surface: req.surface,
        source_hint_id: req.source_hint_id,
        source_task_id: req.confirmation_task_id,
        title,
        is_pinned: false,
        pet_display_snapshot: pet_context.pet_display_snapshot,
        status: AiChatSessionStatus::Active,
        created_at: now,
        updated_at: now,
    };
    let session_persisted = repo.upsert_session(&session).await.is_ok();

    let user_message = AiMessage {
        id: message_id,
        session_id,
        role: AiMessageRole::User,
        content: req.message.clone(),
        status: AiMessageStatus::Completed,
        citations: vec![],
        model: None,
        provider: None,
        finish_reason: None,
        usage_input_tokens: None,
        usage_output_tokens: None,
        verification: None,
        created_at: now,
    };
    let user_message_persisted = repo.insert_message(&user_message).await.is_ok();
    record_chat_session_persisted(
        actor_user_id,
        session_id,
        pet_context.primary_pet_id,
        session_persisted,
        user_message_persisted,
    );
}
