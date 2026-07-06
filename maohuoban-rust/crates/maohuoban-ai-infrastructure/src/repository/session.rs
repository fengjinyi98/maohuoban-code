//! session PostgreSQL AI 会话仓储
//! 核心职责：
//! - 实现 AiSessionRepository 端口
//! - 持久化 AI 会话、消息，查询会话列表和消息详情

use std::collections::HashMap;

use async_trait::async_trait;
use chrono::{DateTime, Utc};
use maohuoban_ai_application::ai::ports::{AiRequestGateLog, AiSessionRepository, AiToolAccessLog};
use maohuoban_ai_domain::ai::{
    AiChatSession, AiChatSessionContextStatus, AiChatSessionStatus, AiChatSessionVisibility,
    AiCitation, AiCitationSourceKind, AiError, AiMessage, AiMessageRole, AiMessageStatus,
    AiProposedAction, AiProposedActionKind, AiProposedActionRisk, AiResult,
};
use sqlx::PgPool;
use uuid::Uuid;

use super::session_rows::{MessageCitationRow, MessageRow, SessionRow};

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
        let visibility_str = session_visibility_code(session.session_visibility);
        let context_status_str = session_context_status_code(session.context_status);

        sqlx::query(
            r"
            INSERT INTO ai_chat_sessions
                (id, actor_user_id, primary_pet_id, surface, source_hint_id,
                   source_task_id, chat_context_kind, abnormal_episode_id,
                   agent_followup_id, title, is_pinned, pet_display_snapshot, status,
                   session_visibility, context_status, activated_at, created_at, updated_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18)
            ON CONFLICT (id) DO UPDATE SET
                primary_pet_id = EXCLUDED.primary_pet_id,
                surface = EXCLUDED.surface,
                source_hint_id = EXCLUDED.source_hint_id,
                source_task_id = EXCLUDED.source_task_id,
                chat_context_kind = EXCLUDED.chat_context_kind,
                abnormal_episode_id = EXCLUDED.abnormal_episode_id,
                agent_followup_id = EXCLUDED.agent_followup_id,
                pet_display_snapshot = EXCLUDED.pet_display_snapshot,
                status = EXCLUDED.status,
                session_visibility = EXCLUDED.session_visibility,
                context_status = EXCLUDED.context_status,
                activated_at = COALESCE(ai_chat_sessions.activated_at, EXCLUDED.activated_at),
                updated_at = EXCLUDED.updated_at
            ",
        )
        .bind(session.id)
        .bind(session.actor_user_id)
        .bind(session.primary_pet_id)
        .bind(surface_str)
        .bind(session.source_hint_id)
        .bind(session.source_task_id)
        .bind(&session.chat_context_kind)
        .bind(session.abnormal_episode_id)
        .bind(session.agent_followup_id)
        .bind(&session.title)
        .bind(session.is_pinned)
        .bind(snapshot_json)
        .bind(status_str)
        .bind(visibility_str)
        .bind(context_status_str)
        .bind(session.activated_at)
        .bind(session.created_at)
        .bind(session.updated_at)
        .execute(&self.pool)
        .await
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;

        Ok(())
    }

    async fn update_session_header(
        &self,
        session_id: Uuid,
        actor_user_id: Uuid,
        last_turn_id: Uuid,
        last_message_at: DateTime<Utc>,
    ) -> AiResult<()> {
        sqlx::query(
            r"
            UPDATE ai_chat_sessions
            SET updated_at = $3,
                last_message_at = $3,
                last_turn_id = $4
            WHERE id = $1
              AND actor_user_id = $2
            ",
        )
        .bind(session_id)
        .bind(actor_user_id)
        .bind(last_message_at)
        .bind(last_turn_id)
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
        let content_blocks_json = serde_json::to_value(&message.content_blocks)
            .unwrap_or(serde_json::Value::Array(vec![]));

        sqlx::query(
            r"
            INSERT INTO ai_messages
                (id, session_id, turn_id, role, content, content_blocks, status, citations,
                 model, provider, finish_reason, usage_input_tokens,
                 usage_output_tokens, verification, created_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
            ",
        )
        .bind(message.id)
        .bind(message.session_id)
        .bind(message.turn_id)
        .bind(role_str)
        .bind(&message.content)
        .bind(content_blocks_json)
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
                   source_task_id, chat_context_kind, abnormal_episode_id,
                   agent_followup_id, title, is_pinned, pet_display_snapshot, status,
                   session_visibility, context_status, activated_at, created_at, updated_at
            FROM ai_chat_sessions
            WHERE actor_user_id = $1
              AND status = 'active'
              AND session_visibility = 'visible'
            ORDER BY is_pinned DESC, updated_at DESC
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
            SELECT id, session_id, turn_id, role, content, content_blocks, status, citations,
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

    async fn list_citations_by_session(
        &self,
        session_id: Uuid,
    ) -> AiResult<HashMap<Uuid, Vec<AiCitation>>> {
        let rows = sqlx::query_as::<_, MessageCitationRow>(
            r"
            SELECT message_id, source_kind, source_id, label
            FROM ai_message_citations
            WHERE session_id = $1
            ORDER BY created_at ASC
            ",
        )
        .bind(session_id)
        .fetch_all(&self.pool)
        .await
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;

        let mut citations_by_message: HashMap<Uuid, Vec<AiCitation>> = HashMap::new();
        for row in rows {
            let message_id = row.message_id;
            if let Some(citation) = row.into_citation() {
                citations_by_message
                    .entry(message_id)
                    .or_default()
                    .push(citation);
            }
        }

        Ok(citations_by_message)
    }

    async fn get_session(&self, session_id: Uuid) -> AiResult<Option<AiChatSession>> {
        let row = sqlx::query_as::<_, SessionRow>(
            r"
            SELECT id, actor_user_id, primary_pet_id, surface, source_hint_id,
                   source_task_id, chat_context_kind, abnormal_episode_id,
                   agent_followup_id, title, is_pinned, pet_display_snapshot, status,
                   session_visibility, context_status, activated_at, created_at, updated_at
            FROM ai_chat_sessions
            WHERE id = $1 AND status = 'active'
            ",
        )
        .bind(session_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;

        Ok(row.map(Into::into))
    }

    async fn find_active_abnormal_episode_session(
        &self,
        actor_user_id: Uuid,
        abnormal_episode_id: Uuid,
    ) -> AiResult<Option<AiChatSession>> {
        let row = sqlx::query_as::<_, SessionRow>(
            r"
            SELECT id, actor_user_id, primary_pet_id, surface, source_hint_id,
                   source_task_id, chat_context_kind, abnormal_episode_id,
                   agent_followup_id, title, is_pinned, pet_display_snapshot, status,
                   session_visibility, context_status, activated_at, created_at, updated_at
            FROM ai_chat_sessions
            WHERE actor_user_id = $1
              AND abnormal_episode_id = $2
              AND status = 'active'
              AND context_status = 'active'
            ORDER BY updated_at DESC
            LIMIT 1
            ",
        )
        .bind(actor_user_id)
        .bind(abnormal_episode_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;

        Ok(row.map(Into::into))
    }

    async fn activate_background_session(
        &self,
        session_id: Uuid,
        actor_user_id: Uuid,
    ) -> AiResult<()> {
        sqlx::query(
            r"
            UPDATE ai_chat_sessions
            SET session_visibility = 'visible',
                activated_at = COALESCE(activated_at, now()),
                updated_at = now()
            WHERE id = $1
              AND actor_user_id = $2
              AND status = 'active'
              AND session_visibility = 'background'
              AND context_status = 'active'
            ",
        )
        .bind(session_id)
        .bind(actor_user_id)
        .execute(&self.pool)
        .await
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;

        Ok(())
    }

    async fn bind_session_to_abnormal_episode_followup(
        &self,
        session_id: Uuid,
        actor_user_id: Uuid,
        abnormal_episode_id: Uuid,
        agent_followup_id: Uuid,
    ) -> AiResult<Option<AiChatSession>> {
        let row = sqlx::query_as::<_, SessionRow>(
            r"
            UPDATE ai_chat_sessions
            SET chat_context_kind = 'abnormal_episode_followup',
                abnormal_episode_id = $3,
                agent_followup_id = $4,
                session_visibility = 'visible',
                context_status = 'active',
                activated_at = COALESCE(activated_at, now()),
                updated_at = now()
            WHERE id = $1
              AND actor_user_id = $2
              AND status = 'active'
            RETURNING id, actor_user_id, primary_pet_id, surface, source_hint_id,
                   source_task_id, chat_context_kind, abnormal_episode_id,
                   agent_followup_id, title, is_pinned, pet_display_snapshot, status,
                   session_visibility, context_status, activated_at, created_at, updated_at
            ",
        )
        .bind(session_id)
        .bind(actor_user_id)
        .bind(abnormal_episode_id)
        .bind(agent_followup_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;

        Ok(row.map(Into::into))
    }

    async fn mark_abnormal_episode_context_deleted(
        &self,
        abnormal_episode_id: Uuid,
    ) -> AiResult<()> {
        sqlx::query(
            r"
            UPDATE ai_chat_sessions
            SET context_status = 'deleted',
                updated_at = now()
            WHERE abnormal_episode_id = $1
              AND chat_context_kind = 'abnormal_episode_followup'
              AND context_status = 'active'
            ",
        )
        .bind(abnormal_episode_id)
        .execute(&self.pool)
        .await
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;

        Ok(())
    }

    async fn rename_session(
        &self,
        session_id: Uuid,
        actor_user_id: Uuid,
        title: &str,
    ) -> AiResult<Option<AiChatSession>> {
        let row = sqlx::query_as::<_, SessionRow>(
            r"
            UPDATE ai_chat_sessions
            SET title = $3, updated_at = now()
            WHERE id = $1 AND actor_user_id = $2 AND status = 'active'
            RETURNING id, actor_user_id, primary_pet_id, surface, source_hint_id,
                   source_task_id, chat_context_kind, abnormal_episode_id,
                   agent_followup_id, title, is_pinned, pet_display_snapshot, status,
                   session_visibility, context_status, activated_at, created_at, updated_at
            ",
        )
        .bind(session_id)
        .bind(actor_user_id)
        .bind(title)
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;

        Ok(row.map(Into::into))
    }

    async fn set_session_pinned(
        &self,
        session_id: Uuid,
        actor_user_id: Uuid,
        is_pinned: bool,
    ) -> AiResult<Option<AiChatSession>> {
        let row = sqlx::query_as::<_, SessionRow>(
            r"
            UPDATE ai_chat_sessions
            SET is_pinned = $3, updated_at = now()
            WHERE id = $1 AND actor_user_id = $2 AND status = 'active'
            RETURNING id, actor_user_id, primary_pet_id, surface, source_hint_id,
                   source_task_id, chat_context_kind, abnormal_episode_id,
                   agent_followup_id, title, is_pinned, pet_display_snapshot, status,
                   session_visibility, context_status, activated_at, created_at, updated_at
            ",
        )
        .bind(session_id)
        .bind(actor_user_id)
        .bind(is_pinned)
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;

        Ok(row.map(Into::into))
    }

    async fn archive_session(
        &self,
        session_id: Uuid,
        actor_user_id: Uuid,
    ) -> AiResult<Option<AiChatSession>> {
        let row = sqlx::query_as::<_, SessionRow>(
            r"
            UPDATE ai_chat_sessions
            SET status = 'archived', updated_at = now()
            WHERE id = $1 AND actor_user_id = $2 AND status = 'active'
            RETURNING id, actor_user_id, primary_pet_id, surface, source_hint_id,
                   source_task_id, chat_context_kind, abnormal_episode_id,
                   agent_followup_id, title, is_pinned, pet_display_snapshot, status,
                   session_visibility, context_status, activated_at, created_at, updated_at
            ",
        )
        .bind(session_id)
        .bind(actor_user_id)
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
                 allowed, denied_reason, returned_ref_ids, request_payload, response_payload,
                 duration_ms, risk_signal)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
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
        .bind(&log.request_payload)
        .bind(&log.response_payload)
        .bind(log.duration_ms)
        .bind(&log.risk_signal)
        .execute(&self.pool)
        .await
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;

        Ok(())
    }

    async fn insert_message_citations(
        &self,
        message_id: Uuid,
        session_id: Uuid,
        citations: &[AiCitation],
    ) -> AiResult<()> {
        for citation in citations {
            sqlx::query(
                r"
                INSERT INTO ai_message_citations
                    (message_id, session_id, source_kind, source_id, label)
                VALUES ($1, $2, $3, $4, $5)
                ON CONFLICT (message_id, source_kind, source_id) DO NOTHING
                ",
            )
            .bind(message_id)
            .bind(session_id)
            .bind(citation_source_kind_code(citation.source_kind))
            .bind(citation.source_id)
            .bind(&citation.label)
            .execute(&self.pool)
            .await
            .map_err(|e| AiError::Infrastructure(e.to_string()))?;
        }

        Ok(())
    }

    async fn insert_proposed_action(
        &self,
        session_id: Uuid,
        action: &AiProposedAction,
    ) -> AiResult<()> {
        sqlx::query(
            r"
            INSERT INTO ai_proposed_actions
                (id, session_id, source_message_id, action_kind, target_pet_id,
                 payload, confirm_text, risk_level, confirmation_task_id, status)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'pending')
            ON CONFLICT (id) DO UPDATE SET
                source_message_id = EXCLUDED.source_message_id,
                action_kind = EXCLUDED.action_kind,
                target_pet_id = EXCLUDED.target_pet_id,
                payload = EXCLUDED.payload,
                confirm_text = EXCLUDED.confirm_text,
                risk_level = EXCLUDED.risk_level,
                confirmation_task_id = EXCLUDED.confirmation_task_id,
                updated_at = now()
            ",
        )
        .bind(action.id)
        .bind(session_id)
        .bind(action.source_message_id)
        .bind(proposed_action_kind_code(action.action_kind))
        .bind(action.target_pet_id)
        .bind(&action.payload)
        .bind(&action.confirm_text)
        .bind(proposed_action_risk_code(action.risk_level))
        .bind(action.confirmation_task_id)
        .execute(&self.pool)
        .await
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;

        Ok(())
    }

    async fn update_message_turn_id(&self, message_id: Uuid, turn_id: Uuid) -> AiResult<()> {
        sqlx::query(
            r"
            UPDATE ai_messages
            SET turn_id = $2
            WHERE id = $1
            ",
        )
        .bind(message_id)
        .bind(turn_id)
        .execute(&self.pool)
        .await
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;

        Ok(())
    }
}

/// citation_source_kind_code 返回引用来源类型编码
/// 核心职责：
/// - 使用稳定 snake_case 写入数据库
/// - 保持 DB 枚举值与 HTTP DTO 序列化一致
fn citation_source_kind_code(kind: AiCitationSourceKind) -> &'static str {
    match kind {
        AiCitationSourceKind::PetEvent => "pet_event",
        AiCitationSourceKind::DietAssignment => "diet_assignment",
        AiCitationSourceKind::FoodInventoryHint => "food_inventory_hint",
        AiCitationSourceKind::AttentionHint => "attention_hint",
        AiCitationSourceKind::ConfirmationTask => "confirmation_task",
        AiCitationSourceKind::AbnormalEpisode => "abnormal_episode",
    }
}

/// proposed_action_kind_code 返回建议动作类型编码
/// 核心职责：
/// - 使用稳定 snake_case 写入数据库
/// - 避免在 SQL 层依赖 Rust Debug 字符串
fn proposed_action_kind_code(kind: AiProposedActionKind) -> &'static str {
    match kind {
        AiProposedActionKind::DietChangeConfirmation => "diet_change_confirmation",
        AiProposedActionKind::FeedingCorrection => "feeding_correction",
        AiProposedActionKind::SymptomFollowup => "symptom_followup",
        AiProposedActionKind::ReminderCreation => "reminder_creation",
        AiProposedActionKind::RiskContextConfirmation => "risk_context_confirmation",
    }
}

/// proposed_action_risk_code 返回建议动作风险编码
/// 核心职责：
/// - 使用稳定 snake_case 写入数据库
/// - 对齐前端 pending action 风险展示
fn proposed_action_risk_code(risk: AiProposedActionRisk) -> &'static str {
    match risk {
        AiProposedActionRisk::Low => "low",
        AiProposedActionRisk::Medium => "medium",
        AiProposedActionRisk::High => "high",
    }
}

/// session_visibility_code 返回会话可见性编码
/// 核心职责：
/// - 使用稳定 snake_case 写入数据库
/// - 区分用户可见聊天与后台追踪上下文
fn session_visibility_code(visibility: AiChatSessionVisibility) -> &'static str {
    match visibility {
        AiChatSessionVisibility::Visible => "visible",
        AiChatSessionVisibility::Background => "background",
    }
}

/// session_context_status_code 返回会话上下文状态编码
/// 核心职责：
/// - 使用稳定 snake_case 写入数据库
/// - 表达业务上下文相对聊天记录的独立生命周期
fn session_context_status_code(status: AiChatSessionContextStatus) -> &'static str {
    match status {
        AiChatSessionContextStatus::Active => "active",
        AiChatSessionContextStatus::Deleted => "deleted",
        AiChatSessionContextStatus::Closed => "closed",
    }
}
