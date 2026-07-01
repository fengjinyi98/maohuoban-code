use async_trait::async_trait;
use maohuoban_ai_domain::ai::{
    AiCitation, AiMessage, AiProposedAction, AiResult, AiSessionTurnStatus,
};
use uuid::Uuid;

use super::{FinalizerAsyncJob, FinalizerSessionHeaderUpdate};

/// FinalizerStore Finalizer 存储端口
/// 核心职责：
/// - 提供同步收口所需的关键写入能力
/// - 提供异步后处理触发能力并由 Finalizer 决定 fail-open
#[async_trait]
pub trait FinalizerStore: Send + Sync {
    /// write_assistant_message 写入助手最终快照
    async fn write_assistant_message(&self, message: &AiMessage) -> AiResult<()>;

    /// write_citations 写入助手消息引用
    async fn write_citations(
        &self,
        message_id: Uuid,
        session_id: Uuid,
        citations: &[AiCitation],
    ) -> AiResult<()>;

    /// write_proposed_actions 写入建议动作或确认任务
    async fn write_proposed_actions(
        &self,
        session_id: Uuid,
        actions: &[AiProposedAction],
    ) -> AiResult<()>;

    /// update_turn_status 更新 turn 终态
    async fn update_turn_status(
        &self,
        turn_id: Uuid,
        status: AiSessionTurnStatus,
        assistant_message_id: Option<Uuid>,
        finish_reason: Option<&str>,
        error_code: Option<&str>,
        retryable: Option<bool>,
    ) -> AiResult<()>;

    /// update_session_header 刷新会话 header
    async fn update_session_header(&self, update: &FinalizerSessionHeaderUpdate) -> AiResult<()>;

    /// trigger_async_job 触发异步后处理
    async fn trigger_async_job(&self, job: &FinalizerAsyncJob) -> AiResult<()>;
}
