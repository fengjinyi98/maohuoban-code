use chrono::Utc;
use maohuoban_ai_application::ai::ports::AiSessionRepository;
use maohuoban_ai_domain::ai::{AiMessage, AiMessageRole, AiMessageStatus};
use uuid::Uuid;

/// spawn_assistant_message_persist 异步持久化助手消息
/// 核心职责：
/// - 在流式完成后保存助手最终消息
/// - 记录 token usage 和完成原因
pub(super) fn spawn_assistant_message_persist(
    repo: std::sync::Arc<dyn AiSessionRepository>,
    message_id: Uuid,
    session_id: Uuid,
    final_text: String,
    input_tokens: u32,
    output_tokens: u32,
    finish_reason: String,
) {
    tokio::spawn(async move {
        let assistant_message = AiMessage {
            id: message_id,
            session_id,
            role: AiMessageRole::Assistant,
            content: final_text,
            status: AiMessageStatus::Completed,
            citations: vec![],
            model: Some("default".to_owned()),
            provider: Some("fake".to_owned()),
            finish_reason: Some(finish_reason),
            usage_input_tokens: Some(input_tokens),
            usage_output_tokens: Some(output_tokens),
            verification: None,
            created_at: Utc::now(),
        };
        let _ = repo.insert_message(&assistant_message).await;
    });
}
