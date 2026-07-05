use async_trait::async_trait;
use maohuoban_pet_domain::pet::PetResult;
use uuid::Uuid;

use super::{CommittedObservationWrite, PreparedObservationWrite};

/// ObservationWriteContext Agent 写入观察时的后端绑定上下文
/// 核心职责：
/// - 承载已由后端会话确认的异常追踪上下文
/// - 避免模型通过工具参数自由指定 episode 或 followup 归属
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct ObservationWriteContext {
    pub chat_context_kind: Option<String>,
    pub abnormal_episode_id: Option<Uuid>,
    pub source_hint_id: Option<Uuid>,
    pub agent_followup_id: Option<Uuid>,
}

impl ObservationWriteContext {
    /// is_abnormal_episode_followup 返回是否绑定异常追踪上下文
    /// 核心职责：
    /// - 固定异常追踪 Agent 上下文的判定边界
    /// - 为 Runtime planning 与写入工具共享同一后端上下文信号
    #[must_use]
    pub fn is_abnormal_episode_followup(&self) -> bool {
        self.chat_context_kind.as_deref() == Some("abnormal_episode_followup")
            && self.abnormal_episode_id.is_some()
    }
}

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
        context: ObservationWriteContext,
    ) -> PetResult<PreparedObservationWrite>;

    async fn commit_observation_write(
        &self,
        actor_user_id: Uuid,
        pet_id: Uuid,
        confirmation_task_id: Uuid,
    ) -> PetResult<CommittedObservationWrite>;
}
