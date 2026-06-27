use chrono::{DateTime, Utc};
use maohuoban_ai_application::ai::ports::AiSessionRepository;
use maohuoban_ai_domain::ai::{
    AiChatSession, AiChatSessionStatus, AiMessage, AiMessageRole, AiMessageStatus,
    AiPetDisplaySnapshot,
};
use uuid::Uuid;

use super::request::ChatStreamRequest;

/// PetSessionContext AI 会话宠物上下文
/// 核心职责：
/// - 承载后端解析后的主宠物 ID
/// - 承载用于历史展示的宠物快照
pub(super) struct PetSessionContext {
    pub(super) primary_pet_id: Option<Uuid>,
    pub(super) pet_display_snapshot: Option<AiPetDisplaySnapshot>,
}

/// persist_session_and_user_message 持久化会话和用户消息
/// 核心职责：
/// - 创建或更新 AI 会话记录
/// - 保存本轮用户消息
pub(super) async fn persist_session_and_user_message(
    repo: &std::sync::Arc<dyn AiSessionRepository>,
    req: &ChatStreamRequest,
    actor_user_id: Uuid,
    session_id: Uuid,
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
        pet_display_snapshot: pet_context.pet_display_snapshot,
        status: AiChatSessionStatus::Active,
        created_at: now,
        updated_at: now,
    };
    let _ = repo.upsert_session(&session).await;

    let user_message = AiMessage {
        id: Uuid::new_v4(),
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
    let _ = repo.insert_message(&user_message).await;
}
