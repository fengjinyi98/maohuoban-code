use async_trait::async_trait;
use maohuoban_ai_domain::ai::{AiResult, MemoryCandidate, MemoryCandidateStatus, MemoryScope};
use uuid::Uuid;

/// MemoryCandidateRepository 记忆候选仓储端口
/// 核心职责：
/// - 持久化和查询记忆候选
/// - 支持按作用域和归属过滤
/// - application 只依赖该 trait，不感知具体数据库实现
#[async_trait]
pub trait MemoryCandidateRepository: Send + Sync {
    /// insert_candidate 写入新的记忆候选
    async fn insert_candidate(&self, candidate: &MemoryCandidate) -> AiResult<()>;

    /// get_pending_candidates 获取待确认的候选
    /// 核心职责：
    /// - 按 scope_type、scope_id 和 actor_user_id 过滤
    /// - 只返回 Pending 状态的候选
    async fn get_pending_candidates(
        &self,
        scope_type: MemoryScope,
        scope_id: Uuid,
        actor_user_id: Uuid,
    ) -> AiResult<Vec<MemoryCandidate>>;

    /// update_status 更新候选状态
    async fn update_status(
        &self,
        id: Uuid,
        actor_user_id: Uuid,
        status: MemoryCandidateStatus,
        confirmed_at: Option<chrono::DateTime<chrono::Utc>>,
    ) -> AiResult<()>;

    /// get_by_id 按 ID 获取候选
    async fn get_by_id(&self, id: Uuid) -> AiResult<Option<MemoryCandidate>>;
}

/// NoopMemoryCandidateRepository 空实现占位
/// 核心职责：
/// - 在没有 Postgres 实现时提供默认空行为
#[derive(Clone, Copy)]
pub struct NoopMemoryCandidateRepository;

#[async_trait]
impl MemoryCandidateRepository for NoopMemoryCandidateRepository {
    async fn insert_candidate(&self, _candidate: &MemoryCandidate) -> AiResult<()> {
        Ok(())
    }

    async fn get_pending_candidates(
        &self,
        _scope_type: MemoryScope,
        _scope_id: Uuid,
        _actor_user_id: Uuid,
    ) -> AiResult<Vec<MemoryCandidate>> {
        Ok(Vec::new())
    }

    async fn update_status(
        &self,
        _id: Uuid,
        _actor_user_id: Uuid,
        _status: MemoryCandidateStatus,
        _confirmed_at: Option<chrono::DateTime<chrono::Utc>>,
    ) -> AiResult<()> {
        Ok(())
    }

    async fn get_by_id(&self, _id: Uuid) -> AiResult<Option<MemoryCandidate>> {
        Ok(None)
    }
}
