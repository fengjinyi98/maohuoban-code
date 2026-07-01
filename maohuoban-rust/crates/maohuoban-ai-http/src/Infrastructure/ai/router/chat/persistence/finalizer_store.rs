use std::sync::Arc;

use async_trait::async_trait;
use maohuoban_ai_application::ai::finalizer::{
    FinalizerAsyncJob, FinalizerSessionHeaderUpdate, FinalizerStore,
};
use maohuoban_ai_application::ai::ports::{AiSessionRepository, SessionTurnRepository};
use maohuoban_ai_domain::ai::{
    AiCitation, AiMessage, AiProposedAction, AiResult, AiSessionTurnStatus,
};
use uuid::Uuid;

use super::super::super::AiHttpState;

/// HttpFinalizerStore HTTP Finalizer 存储适配器
/// 核心职责：
/// - 将应用层 FinalizerStore 合同适配到现有 session / turn 仓储
/// - 让 stream 与 non-stream 共享同一个终态收口入口
pub(crate) struct HttpFinalizerStore {
    session_repository: Arc<dyn AiSessionRepository>,
    session_turn_repository: Arc<dyn SessionTurnRepository>,
}

impl HttpFinalizerStore {
    /// from_state 从 HTTP 状态构造适配器
    #[must_use]
    pub(crate) fn from_state(state: &AiHttpState) -> Self {
        Self {
            session_repository: state.session_repository.clone(),
            session_turn_repository: state.session_turn_repository.clone(),
        }
    }
}

#[async_trait]
impl FinalizerStore for HttpFinalizerStore {
    async fn write_assistant_message(&self, message: &AiMessage) -> AiResult<()> {
        self.session_repository.insert_message(message).await
    }

    async fn write_citations(
        &self,
        message_id: Uuid,
        session_id: Uuid,
        citations: &[AiCitation],
    ) -> AiResult<()> {
        self.session_repository
            .insert_message_citations(message_id, session_id, citations)
            .await
    }

    async fn write_proposed_actions(
        &self,
        session_id: Uuid,
        actions: &[AiProposedAction],
    ) -> AiResult<()> {
        for action in actions {
            self.session_repository
                .insert_proposed_action(session_id, action)
                .await?;
        }
        Ok(())
    }

    async fn update_turn_status(
        &self,
        turn_id: Uuid,
        status: AiSessionTurnStatus,
        assistant_message_id: Option<Uuid>,
        finish_reason: Option<&str>,
        error_code: Option<&str>,
        retryable: Option<bool>,
    ) -> AiResult<()> {
        self.session_turn_repository
            .update_turn_status(
                turn_id,
                status,
                assistant_message_id,
                finish_reason,
                error_code,
                retryable,
            )
            .await
    }

    async fn update_session_header(&self, update: &FinalizerSessionHeaderUpdate) -> AiResult<()> {
        self.session_repository
            .update_session_header(
                update.session_id,
                update.actor_user_id,
                update.last_turn_id,
                update.last_message_at,
            )
            .await
    }

    async fn trigger_async_job(&self, _job: &FinalizerAsyncJob) -> AiResult<()> {
        Ok(())
    }
}
