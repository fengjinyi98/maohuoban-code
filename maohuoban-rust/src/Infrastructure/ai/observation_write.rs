use std::sync::Arc;

use async_trait::async_trait;
use chrono::Utc;
use maohuoban_ai_application::ai::ports::{
    CommittedObservationWrite, ObservationWriteContext, PetObservationWriteProvider,
    PreparedObservationWrite,
};
use maohuoban_ai_domain::ai::AiToolConfirmationRequirement;
use maohuoban_pet_application::pet::{AgentConfirmationTaskRepository, NewPetEvent, PetService};
use maohuoban_pet_domain::pet::{
    AgentConfirmationTask, ConfirmationTaskKind, ConfirmationTaskStatus, EventKind,
    EventVisibility, PetError, PetResult,
};
use uuid::Uuid;

/// `PetServiceObservationWriteProvider` 观察记录写工具适配器
/// 核心职责：
/// - prepare 阶段创建结构化确认任务
/// - commit 阶段校验确认任务并落真实 pet event
#[derive(Clone)]
pub(crate) struct PetServiceObservationWriteProvider {
    pet: Arc<PetService>,
    confirmation_tasks: Arc<dyn AgentConfirmationTaskRepository>,
}

impl PetServiceObservationWriteProvider {
    #[must_use]
    pub(crate) fn new(
        pet: Arc<PetService>,
        confirmation_tasks: Arc<dyn AgentConfirmationTaskRepository>,
    ) -> Self {
        Self {
            pet,
            confirmation_tasks,
        }
    }
}

#[async_trait]
impl PetObservationWriteProvider for PetServiceObservationWriteProvider {
    async fn prepare_observation_write(
        &self,
        actor_user_id: Uuid,
        pet_id: Uuid,
        note: String,
        context: ObservationWriteContext,
    ) -> PetResult<PreparedObservationWrite> {
        let confirmation_task_id = Uuid::new_v4();
        let is_abnormal_followup = context.chat_context_kind.as_deref()
            == Some("abnormal_episode_followup")
            && context.abnormal_episode_id.is_some();
        let event_subkind = if is_abnormal_followup {
            "symptom_followup"
        } else {
            "agent_observation_note"
        };
        let source = if is_abnormal_followup {
            "agent_assisted_followup"
        } else {
            "agent_runtime_confirmed_write"
        };
        let mut candidate_payload = serde_json::json!({
            "event_kind": "health",
            "event_subkind": event_subkind,
            "note": note,
            "actor_user_id": actor_user_id,
            "source": source,
        });
        if let Some(episode_id) = context.abnormal_episode_id {
            candidate_payload["episode_id"] = serde_json::json!(episode_id.to_string());
        }
        if let Some(agent_followup_id) = context.agent_followup_id {
            candidate_payload["agent_followup_id"] =
                serde_json::json!(agent_followup_id.to_string());
        }
        if let Some(source_hint_id) = context.source_hint_id {
            candidate_payload["source_hint_id"] = serde_json::json!(source_hint_id.to_string());
        }
        let task = AgentConfirmationTask {
            id: confirmation_task_id,
            pet_id,
            task_kind: ConfirmationTaskKind::SymptomFollowup,
            question_text: "是否确认写入这条观察记录？".to_owned(),
            candidate_payload: Some(candidate_payload),
            source_hint_id: context.source_hint_id,
            source_ref_type: Some(if is_abnormal_followup {
                "agent_proactive_followup".to_owned()
            } else {
                "agent_runtime".to_owned()
            }),
            source_ref_id: context.agent_followup_id,
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
                tool_name: "commit_pet_observation_write".to_owned(),
                question_text: saved.question_text,
                args: serde_json::json!({
                    "confirmation_task_id": saved.id,
                    "pet_id": pet_id,
                }),
            },
        })
    }

    async fn commit_observation_write(
        &self,
        actor_user_id: Uuid,
        pet_id: Uuid,
        confirmation_task_id: Uuid,
    ) -> PetResult<CommittedObservationWrite> {
        let task = self
            .confirmation_tasks
            .get_by_id(confirmation_task_id)
            .await?;
        if task.pet_id != pet_id || task.status != ConfirmationTaskStatus::Pending {
            return Err(PetError::InvalidInput("确认任务不可用".to_owned()));
        }
        let payload = task
            .candidate_payload
            .clone()
            .ok_or_else(|| PetError::InvalidInput("确认任务缺少候选载荷".to_owned()))?;
        let note = payload
            .get("note")
            .and_then(serde_json::Value::as_str)
            .ok_or_else(|| PetError::InvalidInput("确认任务缺少观察内容".to_owned()))?;
        let event_subkind = payload
            .get("event_subkind")
            .and_then(serde_json::Value::as_str)
            .unwrap_or("agent_observation_note");
        let source = payload
            .get("source")
            .and_then(serde_json::Value::as_str)
            .unwrap_or("agent_runtime_confirmed_write");
        let episode_id = payload
            .get("episode_id")
            .and_then(serde_json::Value::as_str)
            .and_then(|value| Uuid::parse_str(value).ok());
        let agent_followup_id = payload
            .get("agent_followup_id")
            .and_then(serde_json::Value::as_str)
            .and_then(|value| Uuid::parse_str(value).ok());
        let source_hint_id = payload
            .get("source_hint_id")
            .and_then(serde_json::Value::as_str)
            .and_then(|value| Uuid::parse_str(value).ok());
        let mut event_payload = serde_json::json!({
            "note": note,
            "source": source,
            "confirmation_task_id": confirmation_task_id,
        });
        if let Some(episode_id) = episode_id {
            event_payload["episode_id"] = serde_json::json!(episode_id.to_string());
        }
        if let Some(agent_followup_id) = agent_followup_id {
            event_payload["agent_followup_id"] = serde_json::json!(agent_followup_id.to_string());
        }
        if let Some(source_hint_id) = source_hint_id {
            event_payload["source_hint_id"] = serde_json::json!(source_hint_id.to_string());
        }

        let event = self
            .pet
            .create_pet_event(NewPetEvent {
                pet_id,
                actor_user_id,
                event_kind: EventKind::Health,
                event_subkind: Some(event_subkind.to_owned()),
                title: "观察记录已写入".to_owned(),
                summary: Some(note.to_owned()),
                visibility: EventVisibility::Private,
                event_payload,
                occurred_at: Utc::now(),
            })
            .await?;

        self.confirmation_tasks
            .update_status(
                confirmation_task_id,
                "answered",
                Some(serde_json::json!({ "committed": true })),
                Some(event.id),
            )
            .await?;

        Ok(CommittedObservationWrite {
            confirmation_task_id,
            event_id: event.id,
        })
    }
}
