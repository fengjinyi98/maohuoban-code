use async_trait::async_trait;
use maohuoban_pet_domain::pet::PetResult;
use uuid::Uuid;

use super::{AbnormalSymptomCreationDraft, CommittedAbnormalSymptomCreation};
use crate::ai::ports::PreparedObservationWrite;

/// PetAbnormalSymptomCreationProvider 异常创建写入端口
/// 核心职责：
/// - 为 AI runtime 提供异常父记录创建确认任务
/// - 在用户授权后提交真实异常事件并返回追踪上下文
#[async_trait]
pub trait PetAbnormalSymptomCreationProvider: Send + Sync {
    async fn prepare_abnormal_symptom_creation(
        &self,
        actor_user_id: Uuid,
        pet_id: Uuid,
        session_id: Uuid,
        draft: AbnormalSymptomCreationDraft,
    ) -> PetResult<PreparedObservationWrite>;

    async fn commit_abnormal_symptom_creation(
        &self,
        actor_user_id: Uuid,
        pet_id: Uuid,
        confirmation_task_id: Uuid,
    ) -> PetResult<CommittedAbnormalSymptomCreation>;
}
