//! session_turn PostgreSQL Turn 账本仓储
//! 核心职责：
//! - 实现 SessionTurnRepository 端口
//! - 持久化 turn 行并在终态时更新
//! - 按 session 读取 turn 列表，按 turn 读取单行

use async_trait::async_trait;
use maohuoban_ai_application::ai::ports::SessionTurnRepository;
use maohuoban_ai_domain::ai::{
    AiConversationSurface, AiError, AiResult, AiSessionTurn, AiSessionTurnStatus,
};
use sqlx::PgPool;
use uuid::Uuid;

/// PostgresSessionTurnRepository PostgreSQL Turn 账本仓储
/// 核心职责：
/// - 使用 sqlx 写入 ai_session_turns
/// - 保持 turn 行与 message/event 的主键关联
#[derive(Clone)]
pub struct PostgresSessionTurnRepository {
    pool: PgPool,
}

impl PostgresSessionTurnRepository {
    /// new 构造仓储
    #[must_use]
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }
}

#[async_trait]
impl SessionTurnRepository for PostgresSessionTurnRepository {
    async fn insert_turn(&self, turn: &AiSessionTurn) -> AiResult<()> {
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
        .execute(&self.pool)
        .await
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;

        Ok(())
    }

    async fn update_turn_status(
        &self,
        turn_id: Uuid,
        status: AiSessionTurnStatus,
        assistant_message_id: Option<Uuid>,
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
        .execute(&self.pool)
        .await
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;

        Ok(())
    }

    async fn get_turn(&self, turn_id: Uuid) -> AiResult<Option<AiSessionTurn>> {
        let row = sqlx::query_as::<_, SessionTurnRow>(
            r"
            SELECT id, session_id, actor_user_id, user_message_id, assistant_message_id,
                   intent, gate_decision, resolved_pet_id, engine_mode, surface, status,
                   finish_reason, error_code, retryable, started_at, finished_at
            FROM ai_session_turns
            WHERE id = $1
            ",
        )
        .bind(turn_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;

        Ok(row.map(Into::into))
    }

    async fn list_turns_by_session(&self, session_id: Uuid) -> AiResult<Vec<AiSessionTurn>> {
        let rows = sqlx::query_as::<_, SessionTurnRow>(
            r"
            SELECT id, session_id, actor_user_id, user_message_id, assistant_message_id,
                   intent, gate_decision, resolved_pet_id, engine_mode, surface, status,
                   finish_reason, error_code, retryable, started_at, finished_at
            FROM ai_session_turns
            WHERE session_id = $1
            ORDER BY started_at ASC
            ",
        )
        .bind(session_id)
        .fetch_all(&self.pool)
        .await
        .map_err(|e| AiError::Infrastructure(e.to_string()))?;

        Ok(rows.into_iter().map(Into::into).collect())
    }
}

/// SessionTurnRow ai_session_turns 查询行
/// 核心职责：
/// - 承载数据库字段
/// - 转换为 AiSessionTurn 领域模型
#[derive(sqlx::FromRow)]
struct SessionTurnRow {
    id: Uuid,
    session_id: Uuid,
    actor_user_id: Uuid,
    user_message_id: Uuid,
    assistant_message_id: Option<Uuid>,
    intent: String,
    gate_decision: String,
    resolved_pet_id: Option<Uuid>,
    engine_mode: String,
    surface: String,
    status: String,
    finish_reason: Option<String>,
    error_code: Option<String>,
    retryable: Option<bool>,
    started_at: chrono::DateTime<chrono::Utc>,
    finished_at: Option<chrono::DateTime<chrono::Utc>>,
}

impl From<SessionTurnRow> for AiSessionTurn {
    fn from(row: SessionTurnRow) -> Self {
        Self {
            id: row.id,
            session_id: row.session_id,
            actor_user_id: row.actor_user_id,
            user_message_id: row.user_message_id,
            assistant_message_id: row.assistant_message_id,
            intent: row.intent,
            gate_decision: row.gate_decision,
            resolved_pet_id: row.resolved_pet_id,
            engine_mode: row.engine_mode,
            surface: parse_surface(&row.surface),
            status: AiSessionTurnStatus::parse_from_str(&row.status)
                .unwrap_or(AiSessionTurnStatus::Running),
            finish_reason: row.finish_reason,
            error_code: row.error_code,
            retryable: row.retryable,
            started_at: row.started_at,
            finished_at: row.finished_at,
        }
    }
}

/// surface_code 返回 surface 数据库编码
fn surface_code(surface: AiConversationSurface) -> &'static str {
    match surface {
        AiConversationSurface::HomePrivate => "home_private",
        AiConversationSurface::PetProfile => "pet_profile",
        AiConversationSurface::AbnormalDetail => "abnormal_detail",
        AiConversationSurface::ConfirmationTask => "confirmation_task",
        AiConversationSurface::UgcComment => "ugc_comment",
    }
}

/// parse_surface 从数据库字符串解析 surface
fn parse_surface(s: &str) -> AiConversationSurface {
    match s {
        "pet_profile" => AiConversationSurface::PetProfile,
        "abnormal_detail" => AiConversationSurface::AbnormalDetail,
        "confirmation_task" => AiConversationSurface::ConfirmationTask,
        "ugc_comment" => AiConversationSurface::UgcComment,
        _ => AiConversationSurface::HomePrivate,
    }
}
