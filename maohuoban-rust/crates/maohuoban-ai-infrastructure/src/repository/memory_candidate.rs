//! memory_candidate PostgreSQL 记忆候选仓储
//! 核心职责：
//! - 实现 MemoryCandidateRepository 端口
//! - 按作用域和操作者隔离候选记忆
//! - 持久化候选确认、拒绝和过期状态

use async_trait::async_trait;
use chrono::{DateTime, Utc};
use maohuoban_ai_application::ai::ports::MemoryCandidateRepository;
use maohuoban_ai_domain::ai::{
    AiError, AiResult, MemoryCandidate, MemoryCandidateKind, MemoryCandidateStatus, MemoryScope,
};
use sqlx::{PgPool, Row};
use uuid::Uuid;

/// PostgresMemoryCandidateRepository PostgreSQL 记忆候选仓储
/// 核心职责：
/// - 使用 sqlx 连接 PostgreSQL
/// - 实现候选记忆写入、查询和状态流转
#[derive(Clone)]
pub struct PostgresMemoryCandidateRepository {
    pool: PgPool,
}

impl PostgresMemoryCandidateRepository {
    /// new 构造仓储
    #[must_use]
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }
}

#[async_trait]
impl MemoryCandidateRepository for PostgresMemoryCandidateRepository {
    async fn insert_candidate(&self, candidate: &MemoryCandidate) -> AiResult<()> {
        sqlx::query(
            r"
            INSERT INTO agent_memory_candidates
                (id, scope_type, scope_id, actor_user_id, candidate_kind, summary,
                 source_message_id, confidence, status, created_at, confirmed_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
            ",
        )
        .bind(candidate.id)
        .bind(memory_scope_to_str(candidate.scope_type))
        .bind(candidate.scope_id)
        .bind(candidate.actor_user_id)
        .bind(candidate_kind_to_str(candidate.candidate_kind))
        .bind(&candidate.summary)
        .bind(candidate.source_message_id)
        .bind(candidate.confidence)
        .bind(candidate_status_to_str(candidate.status))
        .bind(candidate.created_at)
        .bind(candidate.confirmed_at)
        .execute(&self.pool)
        .await
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;

        Ok(())
    }

    async fn get_pending_candidates(
        &self,
        scope_type: MemoryScope,
        scope_id: Uuid,
        actor_user_id: Uuid,
    ) -> AiResult<Vec<MemoryCandidate>> {
        let rows = sqlx::query(
            r"
            SELECT id, scope_type, scope_id, actor_user_id, candidate_kind, summary,
                   source_message_id, confidence, status, created_at, confirmed_at
            FROM agent_memory_candidates
            WHERE scope_type = $1
              AND scope_id = $2
              AND actor_user_id = $3
              AND status = 'pending'
            ORDER BY created_at DESC
            ",
        )
        .bind(memory_scope_to_str(scope_type))
        .bind(scope_id)
        .bind(actor_user_id)
        .fetch_all(&self.pool)
        .await
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;

        rows.iter().map(row_to_candidate).collect()
    }

    async fn update_status(
        &self,
        id: Uuid,
        actor_user_id: Uuid,
        status: MemoryCandidateStatus,
        confirmed_at: Option<DateTime<Utc>>,
    ) -> AiResult<()> {
        sqlx::query(
            r"
            UPDATE agent_memory_candidates
            SET status = $3,
                confirmed_at = $4
            WHERE id = $1
              AND actor_user_id = $2
            ",
        )
        .bind(id)
        .bind(actor_user_id)
        .bind(candidate_status_to_str(status))
        .bind(confirmed_at)
        .execute(&self.pool)
        .await
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;

        Ok(())
    }

    async fn get_by_id(&self, id: Uuid) -> AiResult<Option<MemoryCandidate>> {
        let row = sqlx::query(
            r"
            SELECT id, scope_type, scope_id, actor_user_id, candidate_kind, summary,
                   source_message_id, confidence, status, created_at, confirmed_at
            FROM agent_memory_candidates
            WHERE id = $1
            ",
        )
        .bind(id)
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;

        row.as_ref().map(row_to_candidate).transpose()
    }
}

/// memory_scope_to_str 将记忆作用域映射为数据库值
/// 核心职责：
/// - 保持 domain enum 与 PostgreSQL CHECK 约束一致
fn memory_scope_to_str(scope: MemoryScope) -> &'static str {
    match scope {
        MemoryScope::User => "user",
        MemoryScope::Pet => "pet",
        MemoryScope::Household => "household",
        MemoryScope::Session => "session",
    }
}

/// memory_scope_from_str 将数据库值映射为记忆作用域
/// 核心职责：
/// - 拒绝未知枚举值，避免静默降级
fn memory_scope_from_str(value: &str) -> AiResult<MemoryScope> {
    match value {
        "user" => Ok(MemoryScope::User),
        "pet" => Ok(MemoryScope::Pet),
        "household" => Ok(MemoryScope::Household),
        "session" => Ok(MemoryScope::Session),
        _ => Err(AiError::Infrastructure(format!(
            "unknown memory scope: {value}"
        ))),
    }
}

/// candidate_kind_to_str 将候选分类映射为数据库值
/// 核心职责：
/// - 保持候选分类与数据库约束一致
fn candidate_kind_to_str(kind: MemoryCandidateKind) -> &'static str {
    match kind {
        MemoryCandidateKind::PreferenceCandidate => "preference_candidate",
        MemoryCandidateKind::ProfileCandidate => "profile_candidate",
        MemoryCandidateKind::PetFactCandidate => "pet_fact_candidate",
        MemoryCandidateKind::SessionSummaryCandidate => "session_summary_candidate",
        MemoryCandidateKind::RiskSignal => "risk_signal",
    }
}

/// candidate_kind_from_str 将数据库值映射为候选分类
/// 核心职责：
/// - 拒绝未知候选分类，避免错误记忆进入上下文
fn candidate_kind_from_str(value: &str) -> AiResult<MemoryCandidateKind> {
    match value {
        "preference_candidate" => Ok(MemoryCandidateKind::PreferenceCandidate),
        "profile_candidate" => Ok(MemoryCandidateKind::ProfileCandidate),
        "pet_fact_candidate" => Ok(MemoryCandidateKind::PetFactCandidate),
        "session_summary_candidate" => Ok(MemoryCandidateKind::SessionSummaryCandidate),
        "risk_signal" => Ok(MemoryCandidateKind::RiskSignal),
        _ => Err(AiError::Infrastructure(format!(
            "unknown memory candidate kind: {value}"
        ))),
    }
}

/// candidate_status_to_str 将候选状态映射为数据库值
/// 核心职责：
/// - 保持候选生命周期状态与数据库约束一致
fn candidate_status_to_str(status: MemoryCandidateStatus) -> &'static str {
    match status {
        MemoryCandidateStatus::Pending => "pending",
        MemoryCandidateStatus::Confirmed => "confirmed",
        MemoryCandidateStatus::Rejected => "rejected",
        MemoryCandidateStatus::Expired => "expired",
    }
}

/// candidate_status_from_str 将数据库值映射为候选状态
/// 核心职责：
/// - 拒绝未知状态，避免候选生命周期被错误解释
fn candidate_status_from_str(value: &str) -> AiResult<MemoryCandidateStatus> {
    match value {
        "pending" => Ok(MemoryCandidateStatus::Pending),
        "confirmed" => Ok(MemoryCandidateStatus::Confirmed),
        "rejected" => Ok(MemoryCandidateStatus::Rejected),
        "expired" => Ok(MemoryCandidateStatus::Expired),
        _ => Err(AiError::Infrastructure(format!(
            "unknown memory candidate status: {value}"
        ))),
    }
}

/// row_to_candidate 将 SQL 行映射为领域候选对象
/// 核心职责：
/// - 统一数据库字段读取
/// - 统一枚举值校验
fn row_to_candidate(row: &sqlx::postgres::PgRow) -> AiResult<MemoryCandidate> {
    let scope_type: String = row
        .try_get("scope_type")
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;
    let candidate_kind: String = row
        .try_get("candidate_kind")
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;
    let status: String = row
        .try_get("status")
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;

    Ok(MemoryCandidate {
        id: row
            .try_get("id")
            .map_err(|e| AiError::Infrastructure(e.to_string()))?,
        scope_type: memory_scope_from_str(&scope_type)?,
        scope_id: row
            .try_get("scope_id")
            .map_err(|e| AiError::Infrastructure(e.to_string()))?,
        actor_user_id: row
            .try_get("actor_user_id")
            .map_err(|e| AiError::Infrastructure(e.to_string()))?,
        candidate_kind: candidate_kind_from_str(&candidate_kind)?,
        summary: row
            .try_get("summary")
            .map_err(|e| AiError::Infrastructure(e.to_string()))?,
        source_message_id: row
            .try_get("source_message_id")
            .map_err(|e| AiError::Infrastructure(e.to_string()))?,
        confidence: row
            .try_get("confidence")
            .map_err(|e| AiError::Infrastructure(e.to_string()))?,
        status: candidate_status_from_str(&status)?,
        created_at: row
            .try_get("created_at")
            .map_err(|e| AiError::Infrastructure(e.to_string()))?,
        confirmed_at: row
            .try_get("confirmed_at")
            .map_err(|e| AiError::Infrastructure(e.to_string()))?,
    })
}
