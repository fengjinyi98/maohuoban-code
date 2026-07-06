use std::sync::Arc;

use async_trait::async_trait;
use chrono::{DateTime, Utc};
use maohuoban_ai_application::ai::ports::{
    AbnormalSymptomCreationDraft, CommittedAbnormalSymptomCreation,
    PetAbnormalSymptomCreationProvider, PreparedObservationWrite,
};
use maohuoban_ai_domain::ai::AiToolConfirmationRequirement;
use maohuoban_pet_application::pet::{AgentConfirmationTaskRepository, NewPetEvent, PetService};
use maohuoban_pet_domain::pet::{
    AgentConfirmationTask, ConfirmationTaskKind, ConfirmationTaskStatus, EventKind,
    EventVisibility, PetError, PetResult,
};
use sqlx::PgPool;
use uuid::Uuid;

/// `PetServiceAbnormalSymptomCreationProvider` Agent 异常创建确认适配器
/// 核心职责：
/// - 将模型整理的异常父记录草稿保存为确认任务
/// - 让授权前不产生 `pet_events` 或 `abnormal_episode`
#[derive(Clone)]
pub(crate) struct PetServiceAbnormalSymptomCreationProvider {
    pet: Arc<PetService>,
    pool: PgPool,
    confirmation_tasks: Arc<dyn AgentConfirmationTaskRepository>,
}

impl PetServiceAbnormalSymptomCreationProvider {
    #[must_use]
    pub(crate) fn new(
        pet: Arc<PetService>,
        pool: PgPool,
        confirmation_tasks: Arc<dyn AgentConfirmationTaskRepository>,
    ) -> Self {
        Self {
            pet,
            pool,
            confirmation_tasks,
        }
    }
}

#[async_trait]
impl PetAbnormalSymptomCreationProvider for PetServiceAbnormalSymptomCreationProvider {
    async fn prepare_abnormal_symptom_creation(
        &self,
        actor_user_id: Uuid,
        pet_id: Uuid,
        session_id: Uuid,
        draft: AbnormalSymptomCreationDraft,
    ) -> PetResult<PreparedObservationWrite> {
        let confirmation_task_id = Uuid::new_v4();
        let candidate_payload = serde_json::json!({
            "event_kind": "health",
            "event_subkind": "abnormal_symptom",
            "occurred_at": draft.occurred_at,
            "symptom_kinds": draft.symptom_kinds,
            "severity": draft.severity,
            "note": draft.note,
            "summary": draft.note,
            "source": "agent_assisted_abnormal_creation",
            "actor_user_id": actor_user_id,
            "chat_session_id": session_id,
        });
        let task = AgentConfirmationTask {
            id: confirmation_task_id,
            pet_id,
            task_kind: ConfirmationTaskKind::AbnormalSymptomCreation,
            question_text: draft
                .confirmation_question_text
                .clone()
                .filter(|text| !text.trim().is_empty())
                .unwrap_or_else(|| "是否确认创建这条异常追踪？".to_owned()),
            candidate_payload: Some(candidate_payload),
            source_hint_id: None,
            source_ref_type: Some("agent_runtime".to_owned()),
            source_ref_id: Some(session_id),
            status: ConfirmationTaskStatus::Pending,
            answer_payload: None,
            resolved_event_id: None,
            created_at: Utc::now(),
            resolved_at: None,
        };
        let saved = self.confirmation_tasks.create(task).await?;

        Ok(PreparedObservationWrite {
            confirmation: AiToolConfirmationRequirement {
                confirmation_task_id: saved.id.to_string(),
                tool_name: "prepare_pet_abnormal_symptom_creation".to_owned(),
                question_text: saved.question_text,
                args: serde_json::json!({
                    "confirmation_task_id": saved.id,
                    "pet_id": pet_id,
                    "note": draft.note,
                }),
            },
        })
    }

    async fn commit_abnormal_symptom_creation(
        &self,
        actor_user_id: Uuid,
        pet_id: Uuid,
        confirmation_task_id: Uuid,
    ) -> PetResult<CommittedAbnormalSymptomCreation> {
        let task = self
            .confirmation_tasks
            .get_by_id(confirmation_task_id)
            .await?;
        if task.pet_id != pet_id
            || task.status != ConfirmationTaskStatus::Pending
            || task.task_kind != ConfirmationTaskKind::AbnormalSymptomCreation
        {
            return Err(PetError::InvalidInput("确认任务不可用".to_owned()));
        }
        let payload = task
            .candidate_payload
            .clone()
            .ok_or_else(|| PetError::InvalidInput("确认任务缺少候选载荷".to_owned()))?;
        let note = required_payload_string(&payload, "note")?;
        let occurred_at = required_payload_datetime(&payload, "occurred_at")?;
        let symptom_kinds = required_payload_string_array(&payload, "symptom_kinds")?;
        let severity = required_payload_string(&payload, "severity")?;
        let summary = payload
            .get("summary")
            .and_then(serde_json::Value::as_str)
            .unwrap_or(&note)
            .to_owned();

        let event = self
            .pet
            .create_pet_event(NewPetEvent {
                pet_id,
                actor_user_id,
                event_kind: EventKind::Health,
                event_subkind: Some("abnormal_symptom".to_owned()),
                title: "异常情况".to_owned(),
                summary: Some(note.clone()),
                visibility: EventVisibility::Private,
                event_payload: serde_json::json!({
                    "note": note,
                    "summary": summary,
                    "symptom_kinds": symptom_kinds,
                    "severity": severity,
                    "source": "agent_assisted_abnormal_creation",
                    "confirmation_task_id": confirmation_task_id,
                    "chat_session_id": payload.get("chat_session_id").cloned().unwrap_or(serde_json::Value::Null),
                }),
                occurred_at,
            })
            .await?;

        let episode_id = event
            .event_payload
            .get("episode_id")
            .and_then(serde_json::Value::as_str)
            .and_then(|value| Uuid::parse_str(value).ok())
            .ok_or_else(|| PetError::Infrastructure("异常事件缺少 episode_id".to_owned()))?;
        let (agent_followup_id, next_followup_due_at) =
            load_episode_followup_context(&self.pool, pet_id, episode_id).await?;

        self.confirmation_tasks
            .update_status(
                confirmation_task_id,
                "answered",
                Some(serde_json::json!({
                    "committed": true,
                    "event_id": event.id,
                    "episode_id": episode_id,
                    "agent_followup_id": agent_followup_id,
                    "next_followup_due_at": next_followup_due_at,
                })),
                Some(event.id),
            )
            .await?;

        Ok(CommittedAbnormalSymptomCreation {
            confirmation_task_id,
            event_id: event.id,
            episode_id,
            agent_followup_id,
            next_followup_due_at,
        })
    }
}

/// `required_payload_string` 读取确认任务字符串字段
/// 核心职责：
/// - 校验授权提交所需候选载荷字段存在
/// - 保持写入前字段错误可诊断
fn required_payload_string(payload: &serde_json::Value, key: &str) -> PetResult<String> {
    payload
        .get(key)
        .and_then(serde_json::Value::as_str)
        .filter(|value| !value.trim().is_empty())
        .map(str::to_owned)
        .ok_or_else(|| PetError::InvalidInput(format!("确认任务缺少 {key}")))
}

/// `required_payload_datetime` 读取确认任务时间字段
/// 核心职责：
/// - 将模型提交的 RFC3339 时间转换为 UTC
/// - 阻止无效时间进入异常事件账本
fn required_payload_datetime(payload: &serde_json::Value, key: &str) -> PetResult<DateTime<Utc>> {
    let raw = required_payload_string(payload, key)?;
    DateTime::parse_from_rfc3339(&raw)
        .map(|value| value.with_timezone(&Utc))
        .map_err(|_| PetError::InvalidInput(format!("{key} 格式无效")))
}

/// `required_payload_string_array` 读取确认任务字符串数组字段
/// 核心职责：
/// - 校验授权提交所需数组字段存在且非空
/// - 阻止坏载荷被静默改写为默认异常类型
fn required_payload_string_array(payload: &serde_json::Value, key: &str) -> PetResult<Vec<String>> {
    let values = payload
        .get(key)
        .and_then(serde_json::Value::as_array)
        .ok_or_else(|| PetError::InvalidInput(format!("确认任务缺少 {key}")))?;
    let parsed = values
        .iter()
        .map(|value| {
            value
                .as_str()
                .filter(|item| !item.trim().is_empty())
                .map(str::to_owned)
                .ok_or_else(|| PetError::InvalidInput(format!("{key} 包含无效值")))
        })
        .collect::<PetResult<Vec<_>>>()?;
    if parsed.is_empty() {
        return Err(PetError::InvalidInput(format!("{key} 不能为空")));
    }
    Ok(parsed)
}

/// `load_episode_followup_context` 读取异常 episode 初始追踪上下文
/// 核心职责：
/// - 从异常事件创建结果读取初始 planning followup
/// - 为授权后同会话续跑 Agent 提供计划事实
async fn load_episode_followup_context(
    pool: &PgPool,
    pet_id: Uuid,
    episode_id: Uuid,
) -> PetResult<(Uuid, DateTime<Utc>)> {
    let row = sqlx::query_as::<_, (Option<Uuid>, Option<DateTime<Utc>>)>(
        r"
        SELECT last_followup_plan_id, next_followup_due_at
        FROM abnormal_episodes
        WHERE id = $1::uuid AND pet_id = $2::uuid
        ",
    )
    .bind(episode_id)
    .bind(pet_id)
    .fetch_optional(pool)
    .await
    .map_err(|error| PetError::Infrastructure(error.to_string()))?
    .ok_or_else(|| PetError::Infrastructure("异常 episode 读取失败".to_owned()))?;
    let followup_id = row
        .0
        .ok_or_else(|| PetError::Infrastructure("异常 episode 缺少 followup 计划".to_owned()))?;
    let due_at = row
        .1
        .ok_or_else(|| PetError::Infrastructure("异常 episode 缺少下一次追踪时间".to_owned()))?;
    Ok((followup_id, due_at))
}
