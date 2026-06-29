// MemoryCandidateService 记忆候选写入服务
// 核心职责：
// - 从对话中抽取的可记忆信息先写为 Pending 候选
// - 宠物强事实候选必须经过用户确认或业务工具确认才能升级
// - 偏好类候选可直接创建
// - 通过仓储端口持久化，不感知具体数据库实现

use std::sync::Arc;

use chrono::Utc;
use maohuoban_ai_domain::ai::{
    AiResult, MemoryCandidate, MemoryCandidateKind, MemoryCandidateStatus, MemoryScope,
};
use uuid::Uuid;

use crate::ai::ports::MemoryCandidateRepository;

/// MemoryCandidateService 记忆候选写入服务
/// 核心职责：
/// - 创建 Pending 状态的记忆候选
/// - 确认候选（升级为 Confirmed）
/// - 拒绝候选（标记为 Rejected）
/// - 所有操作通过仓储端口持久化
pub struct MemoryCandidateService {
    repo: Arc<dyn MemoryCandidateRepository>,
}

impl MemoryCandidateService {
    /// new 构造记忆候选服务
    #[must_use]
    pub fn new(repo: Arc<dyn MemoryCandidateRepository>) -> Self {
        Self { repo }
    }

    /// create_candidate 创建一条 Pending 状态的记忆候选
    /// 核心职责：
    /// - 把可记忆信息先写为候选
    /// - 宠物强事实标记为需要用户确认
    /// - 返回候选 ID
    #[allow(clippy::too_many_arguments)]
    pub async fn create_candidate(
        &self,
        scope_type: MemoryScope,
        scope_id: Uuid,
        actor_user_id: Uuid,
        candidate_kind: MemoryCandidateKind,
        summary: String,
        source_message_id: Option<Uuid>,
        confidence: f32,
    ) -> AiResult<Uuid> {
        let candidate = MemoryCandidate {
            id: Uuid::new_v4(),
            scope_type,
            scope_id,
            actor_user_id,
            candidate_kind,
            summary,
            source_message_id,
            confidence,
            status: MemoryCandidateStatus::Pending,
            created_at: Utc::now(),
            confirmed_at: None,
        };
        self.repo.insert_candidate(&candidate).await?;
        Ok(candidate.id)
    }

    /// confirm_candidate 确认候选，升级为 Confirmed 状态
    /// 核心职责：
    /// - 将候选状态改为 Confirmed
    /// - 记录确认时间
    /// - 只有 Pending 状态的候选才能确认
    pub async fn confirm_candidate(&self, candidate_id: Uuid, actor_user_id: Uuid) -> AiResult<()> {
        let candidate = self.repo.get_by_id(candidate_id).await?.ok_or_else(|| {
            maohuoban_ai_domain::ai::AiError::NotFound("memory candidate not found".to_owned())
        })?;

        if candidate.actor_user_id != actor_user_id {
            return Err(maohuoban_ai_domain::ai::AiError::Unauthorized);
        }

        if !candidate.is_pending() {
            return Err(maohuoban_ai_domain::ai::AiError::Conflict(
                "only pending candidates can be confirmed".to_owned(),
            ));
        }

        let now = Utc::now();
        self.repo
            .update_status(
                candidate_id,
                actor_user_id,
                MemoryCandidateStatus::Confirmed,
                Some(now),
            )
            .await
    }

    /// reject_candidate 拒绝候选，标记为 Rejected 状态
    pub async fn reject_candidate(&self, candidate_id: Uuid, actor_user_id: Uuid) -> AiResult<()> {
        let candidate = self.repo.get_by_id(candidate_id).await?.ok_or_else(|| {
            maohuoban_ai_domain::ai::AiError::NotFound("memory candidate not found".to_owned())
        })?;

        if candidate.actor_user_id != actor_user_id {
            return Err(maohuoban_ai_domain::ai::AiError::Unauthorized);
        }

        if !candidate.is_pending() {
            return Err(maohuoban_ai_domain::ai::AiError::Conflict(
                "only pending candidates can be rejected".to_owned(),
            ));
        }

        self.repo
            .update_status(
                candidate_id,
                actor_user_id,
                MemoryCandidateStatus::Rejected,
                None,
            )
            .await
    }
}
