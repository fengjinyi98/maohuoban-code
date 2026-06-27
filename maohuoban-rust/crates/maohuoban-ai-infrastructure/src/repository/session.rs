//! session PostgreSQL AI 会话仓储
//! 核心职责：
//! - 实现 AiSessionRepository 端口
//! - 持久化 AI 会话、消息，查询会话列表和消息详情

use async_trait::async_trait;
use chrono::Utc;
use maohuoban_ai_application::ai::ports::{AiRequestGateLog, AiSessionRepository, AiToolAccessLog};
use maohuoban_ai_domain::ai::{
    AiChatSession, AiChatSessionStatus, AiError, AiMessage, AiMessageRole, AiMessageStatus,
    AiPetDisplaySnapshot, AiResult,
};
use sqlx::PgPool;
use uuid::Uuid;

/// PostgresAiSessionRepository PostgreSQL AI 会话仓储
/// 核心职责：
/// - 使用 sqlx 连接 PostgreSQL
/// - 实现会话和消息的 CRUD
#[derive(Clone)]
pub struct PostgresAiSessionRepository {
    pool: PgPool,
}

impl PostgresAiSessionRepository {
    /// new 构造仓储
    #[must_use]
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }
}

#[async_trait]
impl AiSessionRepository for PostgresAiSessionRepository {
    async fn upsert_session(&self, session: &AiChatSession) -> AiResult<()> {
        let snapshot_json = session
            .pet_display_snapshot
            .as_ref()
            .map(|s| serde_json::to_value(s).unwrap_or(serde_json::Value::Null));

        let surface_str = match session.surface {
            maohuoban_ai_domain::ai::AiConversationSurface::HomePrivate => "home_private",
            maohuoban_ai_domain::ai::AiConversationSurface::PetProfile => "pet_profile",
            maohuoban_ai_domain::ai::AiConversationSurface::AbnormalDetail => "abnormal_detail",
            maohuoban_ai_domain::ai::AiConversationSurface::ConfirmationTask => "confirmation_task",
            maohuoban_ai_domain::ai::AiConversationSurface::UgcComment => "ugc_comment",
        };

        let status_str = match session.status {
            AiChatSessionStatus::Active => "active",
            AiChatSessionStatus::Archived => "archived",
        };

        sqlx::query(
            r"
            INSERT INTO ai_chat_sessions
                (id, actor_user_id, primary_pet_id, surface, source_hint_id,
                 source_task_id, title, pet_display_snapshot, status,
                 created_at, updated_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
            ON CONFLICT (id) DO UPDATE SET
                title = EXCLUDED.title,
                pet_display_snapshot = EXCLUDED.pet_display_snapshot,
                status = EXCLUDED.status,
                updated_at = EXCLUDED.updated_at
            ",
        )
        .bind(session.id)
        .bind(session.actor_user_id)
        .bind(session.primary_pet_id)
        .bind(surface_str)
        .bind(session.source_hint_id)
        .bind(session.source_task_id)
        .bind(&session.title)
        .bind(snapshot_json)
        .bind(status_str)
        .bind(session.created_at)
        .bind(session.updated_at)
        .execute(&self.pool)
        .await
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;

        Ok(())
    }

    async fn insert_message(&self, message: &AiMessage) -> AiResult<()> {
        let role_str = match message.role {
            AiMessageRole::User => "user",
            AiMessageRole::Assistant => "assistant",
            AiMessageRole::System => "system",
        };

        let status_str = match message.status {
            AiMessageStatus::Streaming => "streaming",
            AiMessageStatus::Completed => "completed",
            AiMessageStatus::Failed => "failed",
        };

        let citations_json = serde_json::to_value(
            message
                .citations
                .iter()
                .map(std::string::ToString::to_string)
                .collect::<Vec<_>>(),
        )
        .unwrap_or(serde_json::Value::Array(vec![]));

        let verification_json = message
            .verification
            .as_ref()
            .map(|v| serde_json::to_value(v).unwrap_or(serde_json::Value::Null));

        sqlx::query(
            r"
            INSERT INTO ai_messages
                (id, session_id, role, content, status, citations,
                 model, provider, finish_reason, usage_input_tokens,
                 usage_output_tokens, verification, created_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
            ",
        )
        .bind(message.id)
        .bind(message.session_id)
        .bind(role_str)
        .bind(&message.content)
        .bind(status_str)
        .bind(citations_json)
        .bind(&message.model)
        .bind(&message.provider)
        .bind(&message.finish_reason)
        .bind(message.usage_input_tokens.map(|t| t as i32))
        .bind(message.usage_output_tokens.map(|t| t as i32))
        .bind(verification_json)
        .bind(message.created_at)
        .execute(&self.pool)
        .await
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;

        Ok(())
    }

    async fn list_sessions_by_actor(
        &self,
        actor_user_id: Uuid,
        limit: i64,
    ) -> AiResult<Vec<AiChatSession>> {
        let rows = sqlx::query_as::<_, SessionRow>(
            r"
            SELECT id, actor_user_id, primary_pet_id, surface, source_hint_id,
                   source_task_id, title, pet_display_snapshot, status,
                   created_at, updated_at
            FROM ai_chat_sessions
            WHERE actor_user_id = $1
            ORDER BY updated_at DESC
            LIMIT $2
            ",
        )
        .bind(actor_user_id)
        .bind(limit)
        .fetch_all(&self.pool)
        .await
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;

        Ok(rows.into_iter().map(Into::into).collect())
    }

    async fn list_messages_by_session(&self, session_id: Uuid) -> AiResult<Vec<AiMessage>> {
        let rows = sqlx::query_as::<_, MessageRow>(
            r"
            SELECT id, session_id, role, content, status, citations,
                   model, provider, finish_reason, usage_input_tokens,
                   usage_output_tokens, verification, created_at
            FROM ai_messages
            WHERE session_id = $1
            ORDER BY created_at ASC
            ",
        )
        .bind(session_id)
        .fetch_all(&self.pool)
        .await
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;

        Ok(rows.into_iter().map(Into::into).collect())
    }

    async fn get_session(&self, session_id: Uuid) -> AiResult<Option<AiChatSession>> {
        let row = sqlx::query_as::<_, SessionRow>(
            r"
            SELECT id, actor_user_id, primary_pet_id, surface, source_hint_id,
                   source_task_id, title, pet_display_snapshot, status,
                   created_at, updated_at
            FROM ai_chat_sessions
            WHERE id = $1
            ",
        )
        .bind(session_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;

        Ok(row.map(Into::into))
    }

    async fn insert_request_gate_log(&self, log: &AiRequestGateLog) -> AiResult<()> {
        sqlx::query(
            r"
            INSERT INTO ai_request_gate_logs
                (session_id, actor_user_id, intent, gate_decision, context_loaded,
                 request_hash, resolved_pet_id, selected_pet_id, risk_signal,
                 estimated_input_tokens)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
            ",
        )
        .bind(log.session_id)
        .bind(log.actor_user_id)
        .bind(&log.intent)
        .bind(&log.gate_decision)
        .bind(log.context_loaded)
        .bind(&log.request_hash)
        .bind(log.resolved_pet_id)
        .bind(log.selected_pet_id)
        .bind(&log.risk_signal)
        .bind(log.estimated_input_tokens)
        .execute(&self.pool)
        .await
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;

        Ok(())
    }

    async fn insert_tool_access_log(&self, log: &AiToolAccessLog) -> AiResult<()> {
        let returned_ref_ids = serde_json::to_value(&log.returned_ref_ids)
            .unwrap_or_else(|_| serde_json::Value::Array(vec![]));

        sqlx::query(
            r"
            INSERT INTO ai_tool_access_logs
                (session_id, actor_user_id, tool_name, requested_scope, target_pet_id,
                 allowed, denied_reason, returned_ref_ids, duration_ms, risk_signal)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
            ",
        )
        .bind(log.session_id)
        .bind(log.actor_user_id)
        .bind(&log.tool_name)
        .bind(&log.requested_scope)
        .bind(log.target_pet_id)
        .bind(log.allowed)
        .bind(&log.denied_reason)
        .bind(returned_ref_ids)
        .bind(log.duration_ms)
        .bind(&log.risk_signal)
        .execute(&self.pool)
        .await
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;

        Ok(())
    }
}

#[derive(sqlx::FromRow)]
struct SessionRow {
    id: Uuid,
    actor_user_id: Uuid,
    primary_pet_id: Option<Uuid>,
    surface: String,
    source_hint_id: Option<Uuid>,
    source_task_id: Option<Uuid>,
    title: String,
    pet_display_snapshot: Option<serde_json::Value>,
    status: String,
    created_at: chrono::DateTime<Utc>,
    updated_at: chrono::DateTime<Utc>,
}

impl From<SessionRow> for AiChatSession {
    fn from(row: SessionRow) -> Self {
        let surface = match row.surface.as_str() {
            "pet_profile" => maohuoban_ai_domain::ai::AiConversationSurface::PetProfile,
            "abnormal_detail" => maohuoban_ai_domain::ai::AiConversationSurface::AbnormalDetail,
            "confirmation_task" => maohuoban_ai_domain::ai::AiConversationSurface::ConfirmationTask,
            "ugc_comment" => maohuoban_ai_domain::ai::AiConversationSurface::UgcComment,
            _ => maohuoban_ai_domain::ai::AiConversationSurface::HomePrivate,
        };

        let status = match row.status.as_str() {
            "archived" => AiChatSessionStatus::Archived,
            _ => AiChatSessionStatus::Active,
        };

        let pet_display_snapshot = row
            .pet_display_snapshot
            .and_then(|v| serde_json::from_value::<AiPetDisplaySnapshot>(v).ok());

        Self {
            id: row.id,
            actor_user_id: row.actor_user_id,
            primary_pet_id: row.primary_pet_id,
            surface,
            source_hint_id: row.source_hint_id,
            source_task_id: row.source_task_id,
            title: row.title,
            pet_display_snapshot,
            status,
            created_at: row.created_at,
            updated_at: row.updated_at,
        }
    }
}

#[derive(sqlx::FromRow)]
struct MessageRow {
    id: Uuid,
    session_id: Uuid,
    role: String,
    content: String,
    status: String,
    citations: serde_json::Value,
    model: Option<String>,
    provider: Option<String>,
    finish_reason: Option<String>,
    usage_input_tokens: Option<i32>,
    usage_output_tokens: Option<i32>,
    verification: Option<serde_json::Value>,
    created_at: chrono::DateTime<Utc>,
}

impl From<MessageRow> for AiMessage {
    fn from(row: MessageRow) -> Self {
        let role = match row.role.as_str() {
            "assistant" => AiMessageRole::Assistant,
            "system" => AiMessageRole::System,
            _ => AiMessageRole::User,
        };

        let status = match row.status.as_str() {
            "streaming" => AiMessageStatus::Streaming,
            "failed" => AiMessageStatus::Failed,
            _ => AiMessageStatus::Completed,
        };

        let citations: Vec<Uuid> = row
            .citations
            .as_array()
            .map(|arr| {
                arr.iter()
                    .filter_map(|v| v.as_str().and_then(|s| Uuid::parse_str(s).ok()))
                    .collect()
            })
            .unwrap_or_default();

        let verification = row
            .verification
            .and_then(|v| serde_json::from_value(v).ok());

        Self {
            id: row.id,
            session_id: row.session_id,
            role,
            content: row.content,
            status,
            citations,
            model: row.model,
            provider: row.provider,
            finish_reason: row.finish_reason,
            usage_input_tokens: row.usage_input_tokens.map(|t| t as u32),
            usage_output_tokens: row.usage_output_tokens.map(|t| t as u32),
            verification,
            created_at: row.created_at,
        }
    }
}
