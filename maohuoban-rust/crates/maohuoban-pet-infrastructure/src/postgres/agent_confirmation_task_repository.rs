// PostgresAgentConfirmationTaskRepository PostgreSQL 结构化确认任务仓储
// 核心职责：
// - 持久化 agent_confirmation_tasks 的创建、查询和状态更新
// - 保持确认任务不自动写入聊天消息

use async_trait::async_trait;
use maohuoban_pet_application::pet::AgentConfirmationTaskRepository;
use maohuoban_pet_domain::pet::{AgentConfirmationTask, PetError, PetResult};
use sqlx::PgPool;
use uuid::Uuid;

fn to_infrastructure_error(error: sqlx::Error) -> PetError {
    PetError::Infrastructure(error.to_string())
}

/// PostgresAgentConfirmationTaskRepository PostgreSQL 确认任务仓储
#[derive(Debug, Clone)]
pub struct PostgresAgentConfirmationTaskRepository {
    pool: PgPool,
}

impl PostgresAgentConfirmationTaskRepository {
    #[must_use]
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }
}

#[async_trait]
impl AgentConfirmationTaskRepository for PostgresAgentConfirmationTaskRepository {
    async fn create(&self, task: AgentConfirmationTask) -> PetResult<AgentConfirmationTask> {
        let task_kind_str = serde_json::to_value(&task.task_kind)
            .ok()
            .and_then(|v| v.as_str().map(String::from))
            .unwrap_or_default();
        let status_str = serde_json::to_value(&task.status)
            .ok()
            .and_then(|v| v.as_str().map(String::from))
            .unwrap_or_default();

        let row = sqlx::query_as::<_, AgentConfirmationTaskRow>(
            r#"
            INSERT INTO agent_confirmation_tasks (
                id, pet_id, task_kind, question_text, candidate_payload,
                source_hint_id, source_ref_type, source_ref_id,
                status, created_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, now())
            RETURNING
                id, pet_id, task_kind, question_text, candidate_payload,
                source_hint_id, source_ref_type, source_ref_id,
                status, answer_payload, resolved_event_id,
                created_at, resolved_at
            "#,
        )
        .bind(task.id)
        .bind(task.pet_id)
        .bind(&task_kind_str)
        .bind(&task.question_text)
        .bind(&task.candidate_payload)
        .bind(task.source_hint_id)
        .bind(&task.source_ref_type)
        .bind(task.source_ref_id)
        .bind(&status_str)
        .fetch_one(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        row.try_into()
    }

    async fn list_pending_by_pet(&self, pet_id: Uuid) -> PetResult<Vec<AgentConfirmationTask>> {
        let rows = sqlx::query_as::<_, AgentConfirmationTaskRow>(
            r#"
            SELECT
                id, pet_id, task_kind, question_text, candidate_payload,
                source_hint_id, source_ref_type, source_ref_id,
                status, answer_payload, resolved_event_id,
                created_at, resolved_at
            FROM agent_confirmation_tasks
            WHERE pet_id = $1::uuid AND status = 'pending'
            ORDER BY created_at DESC
            "#,
        )
        .bind(pet_id)
        .fetch_all(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        rows.into_iter().map(|r| r.try_into()).collect()
    }

    async fn get_by_id(&self, id: Uuid) -> PetResult<AgentConfirmationTask> {
        let row = sqlx::query_as::<_, AgentConfirmationTaskRow>(
            r#"
            SELECT
                id, pet_id, task_kind, question_text, candidate_payload,
                source_hint_id, source_ref_type, source_ref_id,
                status, answer_payload, resolved_event_id,
                created_at, resolved_at
            FROM agent_confirmation_tasks
            WHERE id = $1::uuid
            "#,
        )
        .bind(id)
        .fetch_one(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        row.try_into()
    }

    async fn update_status(
        &self,
        id: Uuid,
        status: &str,
        answer_payload: Option<serde_json::Value>,
        resolved_event_id: Option<Uuid>,
    ) -> PetResult<()> {
        sqlx::query(
            r#"
            UPDATE agent_confirmation_tasks
            SET status = $1,
                answer_payload = $2,
                resolved_event_id = $3,
                resolved_at = CASE WHEN $1 IN ('answered', 'dismissed', 'expired') THEN now() ELSE NULL END
            WHERE id = $4::uuid
            "#,
        )
        .bind(status)
        .bind(&answer_payload)
        .bind(resolved_event_id)
        .bind(id)
        .execute(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        Ok(())
    }
}

/// AgentConfirmationTaskRow 数据库行结构
#[derive(Debug, sqlx::FromRow)]
struct AgentConfirmationTaskRow {
    id: Uuid,
    pet_id: Uuid,
    task_kind: String,
    question_text: String,
    candidate_payload: Option<serde_json::Value>,
    source_hint_id: Option<Uuid>,
    source_ref_type: Option<String>,
    source_ref_id: Option<Uuid>,
    status: String,
    answer_payload: Option<serde_json::Value>,
    resolved_event_id: Option<Uuid>,
    created_at: chrono::DateTime<chrono::Utc>,
    resolved_at: Option<chrono::DateTime<chrono::Utc>>,
}

impl TryFrom<AgentConfirmationTaskRow> for AgentConfirmationTask {
    type Error = maohuoban_pet_domain::pet::PetError;

    fn try_from(row: AgentConfirmationTaskRow) -> Result<Self, Self::Error> {
        let task_kind = serde_json::from_value::<maohuoban_pet_domain::pet::ConfirmationTaskKind>(
            serde_json::Value::String(row.task_kind),
        )
        .map_err(|_| {
            maohuoban_pet_domain::pet::PetError::Infrastructure("invalid task_kind".to_owned())
        })?;

        let status = serde_json::from_value::<maohuoban_pet_domain::pet::ConfirmationTaskStatus>(
            serde_json::Value::String(row.status),
        )
        .map_err(|_| {
            maohuoban_pet_domain::pet::PetError::Infrastructure("invalid task status".to_owned())
        })?;

        Ok(AgentConfirmationTask {
            id: row.id,
            pet_id: row.pet_id,
            task_kind,
            question_text: row.question_text,
            candidate_payload: row.candidate_payload,
            source_hint_id: row.source_hint_id,
            source_ref_type: row.source_ref_type,
            source_ref_id: row.source_ref_id,
            status,
            answer_payload: row.answer_payload,
            resolved_event_id: row.resolved_event_id,
            created_at: row.created_at,
            resolved_at: row.resolved_at,
        })
    }
}
