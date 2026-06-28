//! session_event PostgreSQL Agent session event 仓储
//! 核心职责：
//! - 实现 SessionEventRepository 端口
//! - 以 append-only 方式持久化 runtime event 并按 session / turn 回放
// MHB_STRUCTURE_EXEMPTION: WT04 目标文档冻结该 Rust infrastructure repository 路径，保持现有 AI crate 模块形态。

use async_trait::async_trait;
use maohuoban_ai_application::ai::ports::SessionEventRepository;
use maohuoban_ai_domain::ai::{AgentSessionEventEntry, AiError, AiResult};
use sqlx::PgPool;
use uuid::Uuid;

/// PostgresSessionEventRepository PostgreSQL Agent session event 仓储
/// 核心职责：
/// - 使用 sqlx 写入 ai_session_events
/// - 保持 runtime event 与用户可见消息分表存储
#[derive(Clone)]
pub struct PostgresSessionEventRepository {
    pool: PgPool,
}

impl PostgresSessionEventRepository {
    /// new 构造仓储
    #[must_use]
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }
}

#[async_trait]
impl SessionEventRepository for PostgresSessionEventRepository {
    async fn append(&self, entry: &AgentSessionEventEntry) -> AiResult<()> {
        sqlx::query(
            r"
            INSERT INTO ai_session_events
                (id, session_id, turn_id, parent_event_id, event_name, payload, created_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7)
            ",
        )
        .bind(entry.id)
        .bind(entry.session_id)
        .bind(entry.turn_id)
        .bind(entry.parent_event_id)
        .bind(&entry.event_name)
        .bind(&entry.payload)
        .bind(entry.created_at)
        .execute(&self.pool)
        .await
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;

        Ok(())
    }

    async fn list_by_session(&self, session_id: Uuid) -> AiResult<Vec<AgentSessionEventEntry>> {
        let rows = sqlx::query_as::<_, SessionEventRow>(
            r"
            SELECT id, session_id, turn_id, parent_event_id, event_name, payload, created_at
            FROM ai_session_events
            WHERE session_id = $1
            ORDER BY event_index ASC
            ",
        )
        .bind(session_id)
        .fetch_all(&self.pool)
        .await
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;

        Ok(rows.into_iter().map(Into::into).collect())
    }

    async fn list_by_turn(&self, turn_id: Uuid) -> AiResult<Vec<AgentSessionEventEntry>> {
        let rows = sqlx::query_as::<_, SessionEventRow>(
            r"
            SELECT id, session_id, turn_id, parent_event_id, event_name, payload, created_at
            FROM ai_session_events
            WHERE turn_id = $1
            ORDER BY event_index ASC
            ",
        )
        .bind(turn_id)
        .fetch_all(&self.pool)
        .await
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;

        Ok(rows.into_iter().map(Into::into).collect())
    }
}

/// SessionEventRow ai_session_events 查询行
/// 核心职责：
/// - 承载数据库字段
/// - 转换为 AgentSessionEventEntry 领域模型
#[derive(sqlx::FromRow)]
struct SessionEventRow {
    id: Uuid,
    session_id: Uuid,
    turn_id: Uuid,
    parent_event_id: Option<Uuid>,
    event_name: String,
    payload: serde_json::Value,
    created_at: chrono::DateTime<chrono::Utc>,
}

impl From<SessionEventRow> for AgentSessionEventEntry {
    fn from(row: SessionEventRow) -> Self {
        Self {
            id: row.id,
            session_id: row.session_id,
            turn_id: row.turn_id,
            parent_event_id: row.parent_event_id,
            event_name: row.event_name,
            payload: row.payload,
            created_at: row.created_at,
        }
    }
}
