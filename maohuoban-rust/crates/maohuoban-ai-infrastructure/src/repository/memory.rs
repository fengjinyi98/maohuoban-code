//! memory PostgreSQL 记忆仓储
//! 核心职责：
//! - 实现 MemoryRepository 端口
//! - 按作用域、主体和操作者隔离模型可见记忆
//! - 只返回活跃状态的已裁剪记忆摘要

use async_trait::async_trait;
use maohuoban_ai_application::ai::ports::{MemoryQuery, MemoryRepository};
use maohuoban_ai_domain::ai::{AiError, AiResult, MemoryEntry, MemoryScope};
use sqlx::{PgPool, Row};
use uuid::Uuid;

/// PostgresMemoryRepository PostgreSQL 记忆仓储
/// 核心职责：
/// - 使用 sqlx 连接 PostgreSQL
/// - 按查询条件读取模型可见记忆摘要
#[derive(Clone)]
pub struct PostgresMemoryRepository {
    pool: PgPool,
}

impl PostgresMemoryRepository {
    /// new 构造仓储
    #[must_use]
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }
}

#[async_trait]
impl MemoryRepository for PostgresMemoryRepository {
    async fn find_memories(&self, query: &MemoryQuery) -> AiResult<Vec<MemoryEntry>> {
        if !query.is_valid() {
            return Err(AiError::InvalidInput(
                "invalid memory query scope subject".to_owned(),
            ));
        }

        let rows = sqlx::query(
            r"
            SELECT scope_type, scope_id, pet_id, household_id, summary
            FROM agent_memory_items
            WHERE scope_type = $1
              AND scope_id = $2
              AND actor_user_id = $3
              AND status = 'active'
              AND ($1 <> 'pet' OR $4::uuid IS NULL OR pet_id = $4)
              AND ($1 <> 'household' OR $5::uuid IS NULL OR household_id = $5)
            ORDER BY updated_at DESC, created_at DESC
            ",
        )
        .bind(memory_scope_to_str(query.scope_type))
        .bind(query.scope_id)
        .bind(query.actor_user_id)
        .bind(query.pet_id)
        .bind(query.household_id)
        .fetch_all(&self.pool)
        .await
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;

        rows.iter().map(row_to_memory_entry).collect()
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
/// - 拒绝未知枚举值，避免跨作用域错误投影
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

/// row_to_memory_entry 将 SQL 行映射为模型可见记忆
/// 核心职责：
/// - 只暴露已裁剪摘要
/// - 为不同作用域填充主体标识
fn row_to_memory_entry(row: &sqlx::postgres::PgRow) -> AiResult<MemoryEntry> {
    let scope_type: String = row
        .try_get("scope_type")
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;
    let scope = memory_scope_from_str(&scope_type)?;
    let scope_id: Uuid = row
        .try_get("scope_id")
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;
    let pet_id: Option<Uuid> = row
        .try_get("pet_id")
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;
    let household_id: Option<Uuid> = row
        .try_get("household_id")
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;

    let subject_id = match scope {
        MemoryScope::Pet => pet_id.or(Some(scope_id)),
        MemoryScope::Household => household_id.or(Some(scope_id)),
        MemoryScope::User | MemoryScope::Session => Some(scope_id),
    };

    Ok(MemoryEntry {
        scope,
        subject_id,
        summary: row
            .try_get("summary")
            .map_err(|e| AiError::Infrastructure(e.to_string()))?,
    })
}
