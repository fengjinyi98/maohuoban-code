//! chat_turn_transaction PostgreSQL 聊天轮次事务实现
//! 核心职责：
//! - 实现 ChatTurnTransactionPort 端口
//! - 在单个数据库事务内完成 Ingress 和 Finalizer 阶段的全部写入
//! - 消除多次独立仓储调用导致的中间态不一致风险

use async_trait::async_trait;
use maohuoban_ai_application::ai::ports::{
    AiRequestGateLog, ChatTurnTransactionPort, FinalizerTxInput, IngressTxInput,
};
use maohuoban_ai_domain::ai::{
    AiChatSession, AiChatSessionStatus, AiCitation, AiCitationSourceKind, AiError, AiMessage,
    AiMessageRole, AiMessageStatus, AiResult, AiSessionTurn, AiSessionTurnStatus,
};
use sqlx::PgPool;

/// PostgresChatTurnTransaction PostgreSQL 聊天轮次事务
/// 核心职责：
/// - 使用 PgPool::begin 创建真实事务
/// - 在同一事务内完成 Ingress / Finalizer 全部写入后提交
#[derive(Clone)]
pub struct PostgresChatTurnTransaction {
    pool: PgPool,
}

impl PostgresChatTurnTransaction {
    /// new 构造事务端口
    #[must_use]
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }
}

#[async_trait]
impl ChatTurnTransactionPort for PostgresChatTurnTransaction {
    async fn persist_ingress_tx(&self, input: &IngressTxInput<'_>) -> AiResult<()> {
        let mut tx = self
            .pool
            .begin()
            .await
            .map_err(|e| AiError::Infrastructure(e.to_string()))?;

        upsert_session_in_tx(&mut tx, input.session).await?;
        insert_user_message_in_tx(&mut tx, input.user_message).await?;
        insert_turn_in_tx(&mut tx, input.turn).await?;
        backfill_message_turn_id_in_tx(&mut tx, input.user_message.id, input.turn.id).await?;
        insert_gate_log_in_tx(&mut tx, input.gate_log).await?;

        tx.commit()
            .await
            .map_err(|e| AiError::Infrastructure(e.to_string()))?;
        Ok(())
    }

    async fn persist_finalizer_tx(&self, input: &FinalizerTxInput<'_>) -> AiResult<()> {
        let mut tx = self
            .pool
            .begin()
            .await
            .map_err(|e| AiError::Infrastructure(e.to_string()))?;

        insert_assistant_message_in_tx(&mut tx, input.assistant_message).await?;
        insert_citations_in_tx(
            &mut tx,
            input.assistant_message.id,
            input.assistant_message.session_id,
            input.citations,
        )
        .await?;
        update_turn_status_in_tx(
            &mut tx,
            input.turn_id,
            input.turn_status,
            input.assistant_message_id,
            input.finish_reason,
            input.error_code,
            input.retryable,
        )
        .await?;

        tx.commit()
            .await
            .map_err(|e| AiError::Infrastructure(e.to_string()))?;
        Ok(())
    }
}

/// upsert_session_in_tx 在事务内写入或更新会话
async fn upsert_session_in_tx(
    tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    session: &AiChatSession,
) -> AiResult<()> {
    let snapshot_json = session
        .pet_display_snapshot
        .as_ref()
        .map(|s| serde_json::to_value(s).unwrap_or(serde_json::Value::Null));

    let surface_str = surface_code(session.surface);
    let status_str = match session.status {
        AiChatSessionStatus::Active => "active",
        AiChatSessionStatus::Archived => "archived",
    };

    sqlx::query(
        r"
        INSERT INTO ai_chat_sessions
            (id, actor_user_id, primary_pet_id, surface, source_hint_id,
             source_task_id, title, is_pinned, pet_display_snapshot, status,
             created_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
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
    .bind(session.is_pinned)
    .bind(snapshot_json)
    .bind(status_str)
    .bind(session.created_at)
    .bind(session.updated_at)
    .execute(&mut **tx)
    .await
    .map_err(|e| AiError::Infrastructure(e.to_string()))?;

    Ok(())
}

/// insert_user_message_in_tx 在事务内插入用户消息（turn_id=NULL，后续回写）
async fn insert_user_message_in_tx(
    tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    message: &AiMessage,
) -> AiResult<()> {
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
    let content_blocks_json =
        serde_json::to_value(&message.content_blocks).unwrap_or(serde_json::Value::Array(vec![]));

    sqlx::query(
        r"
        INSERT INTO ai_messages
            (id, session_id, turn_id, role, content, content_blocks, status, citations,
             model, provider, finish_reason, usage_input_tokens,
             usage_output_tokens, verification, created_at)
        VALUES ($1, $2, NULL, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
        ",
    )
    .bind(message.id)
    .bind(message.session_id)
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
    .bind(
        message
            .verification
            .as_ref()
            .map(|v| serde_json::to_value(v).unwrap_or(serde_json::Value::Null)),
    )
    .bind(message.created_at)
    .execute(&mut **tx)
    .await
    .map_err(|e| AiError::Infrastructure(e.to_string()))?;

    Ok(())
}

/// insert_turn_in_tx 在事务内插入 turn 账本行
async fn insert_turn_in_tx(
    tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    turn: &AiSessionTurn,
) -> AiResult<()> {
    let surface_str = surface_code(turn.surface);
    let status_str = turn.status.as_str();

    sqlx::query(
        r"
        INSERT INTO ai_session_turns
            (id, session_id, actor_user_id, user_message_id, assistant_message_id,
             intent, gate_decision, resolved_pet_id, engine_mode, surface, status,
             finish_reason, error_code, retryable, started_at, finished_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)
        ",
    )
    .bind(turn.id)
    .bind(turn.session_id)
    .bind(turn.actor_user_id)
    .bind(turn.user_message_id)
    .bind(turn.assistant_message_id)
    .bind(&turn.intent)
    .bind(&turn.gate_decision)
    .bind(turn.resolved_pet_id)
    .bind(&turn.engine_mode)
    .bind(surface_str)
    .bind(status_str)
    .bind(&turn.finish_reason)
    .bind(&turn.error_code)
    .bind(turn.retryable)
    .bind(turn.started_at)
    .bind(turn.finished_at)
    .execute(&mut **tx)
    .await
    .map_err(|e| AiError::Infrastructure(e.to_string()))?;

    Ok(())
}

/// backfill_message_turn_id_in_tx 在事务内回写消息的 turn_id
async fn backfill_message_turn_id_in_tx(
    tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    message_id: uuid::Uuid,
    turn_id: uuid::Uuid,
) -> AiResult<()> {
    sqlx::query("UPDATE ai_messages SET turn_id = $2 WHERE id = $1")
        .bind(message_id)
        .bind(turn_id)
        .execute(&mut **tx)
        .await
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;
    Ok(())
}

/// insert_gate_log_in_tx 在事务内插入 gate 审计日志
async fn insert_gate_log_in_tx(
    tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    log: &AiRequestGateLog,
) -> AiResult<()> {
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
    .execute(&mut **tx)
    .await
    .map_err(|e| AiError::Infrastructure(e.to_string()))?;
    Ok(())
}

/// insert_assistant_message_in_tx 在事务内插入助手消息
async fn insert_assistant_message_in_tx(
    tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    message: &AiMessage,
) -> AiResult<()> {
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
    let content_blocks_json =
        serde_json::to_value(&message.content_blocks).unwrap_or(serde_json::Value::Array(vec![]));

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
    .execute(&mut **tx)
    .await
    .map_err(|e| AiError::Infrastructure(e.to_string()))?;

    Ok(())
}

/// insert_citations_in_tx 在事务内写入引用
async fn insert_citations_in_tx(
    tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    message_id: uuid::Uuid,
    session_id: uuid::Uuid,
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
        .execute(&mut **tx)
        .await
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;
    }
    Ok(())
}

/// update_turn_status_in_tx 在事务内更新 turn 终态
async fn update_turn_status_in_tx(
    tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    turn_id: uuid::Uuid,
    status: AiSessionTurnStatus,
    assistant_message_id: Option<uuid::Uuid>,
    finish_reason: Option<&str>,
    error_code: Option<&str>,
    retryable: Option<bool>,
) -> AiResult<()> {
    let status_str = status.as_str();
    sqlx::query(
        r"
        UPDATE ai_session_turns
        SET status = $2,
            assistant_message_id = COALESCE($3, assistant_message_id),
            finish_reason = $4,
            error_code = $5,
            retryable = $6,
            finished_at = CASE WHEN $2 IN ('completed', 'failed', 'interrupted')
                               THEN now() ELSE finished_at END
        WHERE id = $1
        ",
    )
    .bind(turn_id)
    .bind(status_str)
    .bind(assistant_message_id)
    .bind(finish_reason)
    .bind(error_code)
    .bind(retryable)
    .execute(&mut **tx)
    .await
    .map_err(|e| AiError::Infrastructure(e.to_string()))?;
    Ok(())
}

/// surface_code 返回 surface 数据库编码
fn surface_code(surface: maohuoban_ai_domain::ai::AiConversationSurface) -> &'static str {
    match surface {
        maohuoban_ai_domain::ai::AiConversationSurface::HomePrivate => "home_private",
        maohuoban_ai_domain::ai::AiConversationSurface::PetProfile => "pet_profile",
        maohuoban_ai_domain::ai::AiConversationSurface::AbnormalDetail => "abnormal_detail",
        maohuoban_ai_domain::ai::AiConversationSurface::ConfirmationTask => "confirmation_task",
        maohuoban_ai_domain::ai::AiConversationSurface::UgcComment => "ugc_comment",
    }
}

/// citation_source_kind_code 返回引用来源类型编码
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
