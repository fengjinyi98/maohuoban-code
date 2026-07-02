use async_trait::async_trait;
use maohuoban_pet_domain::pet::PetResult;
use uuid::Uuid;

use super::{CommittedObservationWrite, PreparedObservationWrite};

/// PetObservationWriteProvider 宠物观察记录写工具端口
/// 核心职责：
/// - 为 AI runtime 提供 prepare/commit 双阶段写入协议
/// - 隔离 confirmation task 持久化与真实 pet event 写入实现
#[async_trait]
pub trait PetObservationWriteProvider: Send + Sync {
    async fn prepare_observation_write(
        &self,
        actor_user_id: Uuid,
        pet_id: Uuid,
        note: String,
    ) -> PetResult<PreparedObservationWrite>;

    async fn commit_observation_write(
        &self,
        actor_user_id: Uuid,
        pet_id: Uuid,
        confirmation_task_id: Uuid,
    ) -> PetResult<CommittedObservationWrite>;
}
