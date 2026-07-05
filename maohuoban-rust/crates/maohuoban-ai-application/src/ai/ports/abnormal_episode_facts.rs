// MHB_STRUCTURE_EXEMPTION: ai/ports 为既有应用端口目录；后续 code-structure P1 统一迁移到 Infrastructure/Services 分层目录。
use async_trait::async_trait;
use maohuoban_ai_domain::ai::{AiFactPackage, AiPetDisplaySnapshot, AiResult};
use uuid::Uuid;

/// PetAbnormalEpisodeFactProvider 异常 episode 事实端口
/// 核心职责：
/// - 读取目标宠物当前或指定异常 episode 的结构化事实
/// - 返回可进入 PromptBuilder 和 Verifier 的异常追踪事实包
#[async_trait]
pub trait PetAbnormalEpisodeFactProvider: Send + Sync {
    async fn load_abnormal_episode_fact_package(
        &self,
        actor_user_id: Uuid,
        target_pet: &AiPetDisplaySnapshot,
        episode_id: Option<Uuid>,
    ) -> AiResult<AiFactPackage>;
}

/// EmptyPetAbnormalEpisodeFactProvider 空异常 episode 事实提供者
/// 核心职责：
/// - 为测试或降级场景返回只含目标宠物快照的空事实包
#[derive(Clone, Copy)]
pub struct EmptyPetAbnormalEpisodeFactProvider;

#[async_trait]
impl PetAbnormalEpisodeFactProvider for EmptyPetAbnormalEpisodeFactProvider {
    async fn load_abnormal_episode_fact_package(
        &self,
        _actor_user_id: Uuid,
        target_pet: &AiPetDisplaySnapshot,
        _episode_id: Option<Uuid>,
    ) -> AiResult<AiFactPackage> {
        let mut package = AiFactPackage::empty();
        package.target_pet = Some(target_pet.clone());
        Ok(package)
    }
}
