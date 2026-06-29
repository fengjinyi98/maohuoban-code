//! session_summary PostgreSQL 会话摘要仓储
//! 核心职责：
//! - 实现 SessionSummaryRepository 端口
//! - 持久化和查询会话摘要，支持版本替代和压缩边界追踪

use async_trait::async_trait;
use chrono::{DateTime, Utc};
use maohuoban_ai_application::ai::ports::SessionSummaryRepository;
use maohuoban_ai_domain::ai::{AiError, AiResult, SessionSummary, SessionSummaryScope};
use sqlx::PgPool;
use uuid::Uuid;

/// PostgresSessionSummaryRepository PostgreSQL 会话摘要仓储
/// 核心职责：
/// - 使用 sqlx 连接 PostgreSQL
/// - 实现摘要 CRUD 和版本替代
#[derive(Clone)]
pub struct PostgresSessionSummaryRepository {
    pool: PgPool,
}

impl PostgresSessionSummaryRepository {
    /// new 构造仓储
    #[must_use]
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }
}

#[async_trait]
impl SessionSummaryRepository for PostgresSessionSummaryRepository {
    async fn insert_summary(&self, summary: &SessionSummary) -> AiResult<()> {
        let scope_str = match summary.scope_type {
            SessionSummaryScope::User => "user",
            SessionSummaryScope::Pet => "pet",
            SessionSummaryScope::Household => "household",
        };
        let referenced_ids: Vec<String> = summary
            .referenced_event_ids
            .iter()
            .map(std::string::ToString::to_string)
            .collect();
        let referenced_json =
            serde_json::to_value(&referenced_ids).unwrap_or(serde_json::Value::Array(Vec::new()));

        sqlx::query(
            r"
            INSERT INTO ai_chat_session_summaries
                (id, chat_session_id, scope_type, scope_id, summary_text,
                 referenced_event_ids, token_budget_hint, compressed_until_message_id,
                 created_at, superseded_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
            ",
        )
        .bind(summary.id)
        .bind(summary.chat_session_id)
        .bind(scope_str)
        .bind(summary.scope_id)
        .bind(&summary.summary_text)
        .bind(&referenced_json)
        .bind(summary.token_budget_hint.map(|v| v as i32))
        .bind(summary.compressed_until_message_id)
        .bind(summary.created_at)
        .bind(summary.superseded_at)
        .execute(&self.pool)
        .await
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;

        Ok(())
    }

    async fn get_active_summary(&self, chat_session_id: Uuid) -> AiResult<Option<SessionSummary>> {
        let row = sqlx::query(
            r"
            SELECT id, chat_session_id, scope_type, scope_id, summary_text,
                   referenced_event_ids, token_budget_hint, compressed_until_message_id,
                   created_at, superseded_at
            FROM ai_chat_session_summaries
            WHERE chat_session_id = $1 AND superseded_at IS NULL
            ORDER BY created_at DESC
            LIMIT 1
            ",
        )
        .bind(chat_session_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;

        match row {
            Some(r) => {
                let scope_type_str: String =
                    sqlx::Row::try_get(&r, "scope_type").unwrap_or_else(|_| "user".to_owned());
                let scope_type = match scope_type_str.as_str() {
                    "pet" => SessionSummaryScope::Pet,
                    "household" => SessionSummaryScope::Household,
                    _ => SessionSummaryScope::User,
                };
                let referenced_json: serde_json::Value =
                    sqlx::Row::try_get(&r, "referenced_event_ids")
                        .unwrap_or(serde_json::Value::Array(Vec::new()));
                let referenced_event_ids: Vec<Uuid> = referenced_json
                    .as_array()
                    .map(|arr| {
                        arr.iter()
                            .filter_map(|v| v.as_str().and_then(|s| Uuid::parse_str(s).ok()))
                            .collect()
                    })
                    .unwrap_or_default();
                let token_budget_hint: Option<i32> =
                    sqlx::Row::try_get(&r, "token_budget_hint").ok();
                let token_budget_hint = token_budget_hint.map(|v| u32::try_from(v).unwrap_or(0));

                let id: Uuid = sqlx::Row::try_get(&r, "id").expect("id");
                let scope_id: Uuid = sqlx::Row::try_get(&r, "scope_id").expect("scope_id");
                let summary_text: String =
                    sqlx::Row::try_get(&r, "summary_text").expect("summary_text");
                let compressed_until_message_id: Option<Uuid> =
                    sqlx::Row::try_get(&r, "compressed_until_message_id").ok();
                let created_at: DateTime<Utc> =
                    sqlx::Row::try_get(&r, "created_at").expect("created_at");
                let superseded_at: Option<DateTime<Utc>> =
                    sqlx::Row::try_get(&r, "superseded_at").ok();

                Ok(Some(SessionSummary {
                    id,
                    chat_session_id,
                    scope_type,
                    scope_id,
                    summary_text,
                    referenced_event_ids,
                    token_budget_hint,
                    compressed_until_message_id,
                    created_at,
                    superseded_at,
                }))
            }
            None => Ok(None),
        }
    }

    async fn supersede_previous_summaries(
        &self,
        chat_session_id: Uuid,
        superseded_at: DateTime<Utc>,
    ) -> AiResult<()> {
        sqlx::query(
            r"
            UPDATE ai_chat_session_summaries
            SET superseded_at = $2
            WHERE chat_session_id = $1 AND superseded_at IS NULL
            ",
        )
        .bind(chat_session_id)
        .bind(superseded_at)
        .execute(&self.pool)
        .await
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;

        Ok(())
    }
}
