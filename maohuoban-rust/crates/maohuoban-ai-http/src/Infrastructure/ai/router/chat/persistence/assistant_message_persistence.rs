use chrono::Utc;
use maohuoban_ai_application::ai::ports::AiSessionRepository;
use maohuoban_ai_domain::ai::{AiCitation, AiMessage, AiMessageRole, AiMessageStatus};
use uuid::Uuid;

use super::super::super::diagnostics::record_chat_assistant_persisted;

/// spawn_assistant_message_persist 异步持久化助手消息
/// 核心职责：
/// - 在流式完成后保存助手最终消息
/// - 记录 token usage 和完成原因
pub(crate) fn spawn_assistant_message_persist(
    repo: std::sync::Arc<dyn AiSessionRepository>,
    request: AssistantMessagePersistRequest,
) {
    tokio::spawn(async move {
        persist_assistant_message(&repo, request).await;
    });
}

/// AssistantMessagePersistRequest 助手消息持久化请求
/// 核心职责：
/// - 承载助手最终消息、引用和 usage
/// - 统一异步 spawn 与 await 持久化入口
pub(crate) struct AssistantMessagePersistRequest {
    message_id: Uuid,
    session_id: Uuid,
    turn_id: Option<Uuid>,
    final_text: String,
    citations: Vec<AiCitation>,
    input_tokens: u32,
    output_tokens: u32,
    finish_reason: String,
}

impl AssistantMessagePersistRequest {
    /// new 构造助手消息持久化请求
    #[must_use]
    pub(crate) fn new(
        message_id: Uuid,
        session_id: Uuid,
        final_text: String,
        citations: Vec<AiCitation>,
        input_tokens: u32,
        output_tokens: u32,
        finish_reason: String,
    ) -> Self {
        Self {
            message_id,
            session_id,
            turn_id: None,
            final_text,
            citations,
            input_tokens,
            output_tokens,
            finish_reason,
        }
    }

    /// with_turn_id 设置 turn_id
    #[must_use]
    pub(crate) fn with_turn_id(mut self, turn_id: Uuid) -> Self {
        self.turn_id = Some(turn_id);
        self
    }
}

/// persist_assistant_message 持久化助手消息
/// 核心职责：
/// - 保存助手最终文本和 token usage
/// - 将回答引用写入独立引用表
pub(crate) async fn persist_assistant_message(
    repo: &std::sync::Arc<dyn AiSessionRepository>,
    request: AssistantMessagePersistRequest,
) {
    let citation_ids = request
        .citations
        .iter()
        .map(|citation| citation.source_id)
        .collect::<Vec<_>>();
    let citation_count = request.citations.len();
    let finish_reason = request.finish_reason.clone();
    let assistant_message = AiMessage {
        id: request.message_id,
        session_id: request.session_id,
        turn_id: request.turn_id,
        role: AiMessageRole::Assistant,
        content: request.final_text,
        status: AiMessageStatus::Completed,
        citations: citation_ids,
        model: Some("default".to_owned()),
        provider: Some("fake".to_owned()),
        finish_reason: Some(request.finish_reason),
        usage_input_tokens: Some(request.input_tokens),
        usage_output_tokens: Some(request.output_tokens),
        verification: None,
        created_at: Utc::now(),
    };
    let message_persisted = repo.insert_message(&assistant_message).await.is_ok();
    let citations_persisted = repo
        .insert_message_citations(request.message_id, request.session_id, &request.citations)
        .await
        .is_ok();
    record_chat_assistant_persisted(
        request.session_id,
        request.message_id,
        message_persisted && citations_persisted,
        citation_count,
        request.input_tokens,
        request.output_tokens,
        &finish_reason,
    );
}
