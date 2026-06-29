use async_trait::async_trait;
use maohuoban_ai_domain::ai::{AiResult, SessionSummary};
use uuid::Uuid;

/// SessionSummaryRepository 会话摘要仓储端口
/// 核心职责：
/// - 持久化和查询会话摘要
/// - application 只依赖该 trait，不感知具体数据库实现
#[async_trait]
pub trait SessionSummaryRepository: Send + Sync {
    /// insert_summary 写入新的会话摘要
    /// 核心职责：
    /// - 新摘要写入后，同 session 旧摘要应被标记 superseded_at
    async fn insert_summary(&self, summary: &SessionSummary) -> AiResult<()>;

    /// get_active_summary 获取会话当前有效摘要
    /// 核心职责：
    /// - 返回 superseded_at 为 None 的最新摘要
    async fn get_active_summary(&self, chat_session_id: Uuid) -> AiResult<Option<SessionSummary>>;

    /// supersede_previous_summaries 标记旧摘要为已替代
    /// 核心职责：
    /// - 将同 session 所有未替代的摘要标记 superseded_at
    async fn supersede_previous_summaries(
        &self,
        chat_session_id: Uuid,
        superseded_at: chrono::DateTime<chrono::Utc>,
    ) -> AiResult<()>;
}

/// NoopSessionSummaryRepository 空实现占位
/// 核心职责：
/// - 在没有 Postgres 实现时提供默认空行为
/// - 所有操作返回 Ok 但不持久化
#[derive(Clone, Copy)]
pub struct NoopSessionSummaryRepository;

#[async_trait]
impl SessionSummaryRepository for NoopSessionSummaryRepository {
    async fn insert_summary(&self, _summary: &SessionSummary) -> AiResult<()> {
        Ok(())
    }

    async fn get_active_summary(&self, _chat_session_id: Uuid) -> AiResult<Option<SessionSummary>> {
        Ok(None)
    }

    async fn supersede_previous_summaries(
        &self,
        _chat_session_id: Uuid,
        _superseded_at: chrono::DateTime<chrono::Utc>,
    ) -> AiResult<()> {
        Ok(())
    }
}
