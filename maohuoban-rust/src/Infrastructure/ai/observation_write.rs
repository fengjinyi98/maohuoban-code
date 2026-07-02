use std::sync::Arc;

use async_trait::async_trait;
use chrono::Utc;
use maohuoban_ai_application::ai::ports::{
    CommittedObservationWrite, PetObservationWriteProvider, PreparedObservationWrite,
};
use maohuoban_ai_domain::ai::AiToolConfirmationRequirement;
use maohuoban_pet_application::pet::{AgentConfirmationTaskRepository, NewPetEvent, PetService};
use maohuoban_pet_domain::pet::{
    AgentConfirmationTask, ConfirmationTaskKind, ConfirmationTaskStatus, EventKind,
    EventVisibility, PetError, PetResult,
};
use uuid::Uuid;

/// PetServiceObservationWriteProvider 观察记录写工具适配器
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
    ) -> PetResult<PreparedObservationWrite> {
        let confirmation_task_id = Uuid::new_v4();
        let task = AgentConfirmationTask {
            id: confirmation_task_id,
            pet_id,
            task_kind: ConfirmationTaskKind::SymptomFollowup,
            question_text: "是否确认写入这条观察记录？".to_owned(),
            candidate_payload: Some(serde_json::json!({
                "event_kind": "health",
                "event_subkind": "agent_observation_note",
                "note": note,
                "actor_user_id": actor_user_id,
            })),
            source_hint_id: None,
            source_ref_type: Some("agent_runtime".to_owned()),
            source_ref_id: None,
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

        let event = self
            .pet
            .create_pet_event(NewPetEvent {
                pet_id,
                actor_user_id,
                event_kind: EventKind::Health,
                event_subkind: Some("agent_observation_note".to_owned()),
                title: "观察记录已写入".to_owned(),
                summary: Some(note.to_owned()),
                visibility: EventVisibility::Private,
                event_payload: serde_json::json!({
                    "note": note,
                    "source": "agent_runtime_confirmed_write",
                    "confirmation_task_id": confirmation_task_id,
                }),
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
