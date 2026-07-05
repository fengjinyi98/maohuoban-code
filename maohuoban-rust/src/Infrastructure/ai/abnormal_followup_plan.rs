use std::sync::Arc;

use async_trait::async_trait;
use maohuoban_ai_application::ai::ports::{
    AbnormalFollowupPlanDraft, AbnormalFollowupPlanProvider, ObservationWriteContext,
    SavedAbnormalFollowupPlan,
};
use maohuoban_pet_application::pet::{PetService, SaveAgentFollowupPlanInput};
use maohuoban_pet_domain::pet::{PetError, PetResult};
use uuid::Uuid;

/// `PetServiceAbnormalFollowupPlanProvider` Agent 主动追踪计划适配器
/// 核心职责：
/// - 将 Runtime tool 的计划草稿转交 `PetService` 校验保存
/// - 固定 episode 和 followup 归属只能来自后端会话上下文
#[derive(Clone)]
pub(crate) struct PetServiceAbnormalFollowupPlanProvider {
    pet: Arc<PetService>,
}

impl PetServiceAbnormalFollowupPlanProvider {
    #[must_use]
    pub(crate) const fn new(pet: Arc<PetService>) -> Self {
        Self { pet }
    }
}

#[async_trait]
impl AbnormalFollowupPlanProvider for PetServiceAbnormalFollowupPlanProvider {
    async fn save_followup_plan(
        &self,
        actor_user_id: Uuid,
        pet_id: Uuid,
        context: ObservationWriteContext,
        draft: AbnormalFollowupPlanDraft,
    ) -> PetResult<SavedAbnormalFollowupPlan> {
        let episode_id = context
            .abnormal_episode_id
            .ok_or_else(|| PetError::InvalidInput("缺少异常 episode 上下文".to_owned()))?;
        let followup_id = context
            .agent_followup_id
            .ok_or_else(|| PetError::InvalidInput("缺少主动追踪计划上下文".to_owned()))?;
        let saved = self
            .pet
            .save_agent_followup_plan(SaveAgentFollowupPlanInput {
                actor_user_id,
                pet_id,
                episode_id,
                followup_id,
                due_at: draft.due_at,
                message_title: draft.message_title,
                message_body: draft.message_body,
                rationale: draft.rationale,
                recommended_actions: draft.recommended_actions,
            })
            .await?;

        Ok(SavedAbnormalFollowupPlan {
            followup_id: saved.followup_id,
            due_at: saved.due_at,
        })
    }
}
