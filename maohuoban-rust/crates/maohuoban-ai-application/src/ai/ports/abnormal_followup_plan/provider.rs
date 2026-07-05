use async_trait::async_trait;
use maohuoban_pet_domain::pet::PetResult;
use uuid::Uuid;

use super::{AbnormalFollowupPlanDraft, SavedAbnormalFollowupPlan};
use crate::ai::ports::ObservationWriteContext;

/// AbnormalFollowupPlanProvider 异常主动追踪计划保存端口
/// 核心职责：
/// - 让 Agent Runtime 通过受控端口提交计划草稿
/// - 隔离模型输出与真实 agent_proactive_followups 状态机
#[async_trait]
pub trait AbnormalFollowupPlanProvider: Send + Sync {
    async fn save_followup_plan(
        &self,
        actor_user_id: Uuid,
        pet_id: Uuid,
        context: ObservationWriteContext,
        draft: AbnormalFollowupPlanDraft,
    ) -> PetResult<SavedAbnormalFollowupPlan>;
}
