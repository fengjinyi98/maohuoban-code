use async_trait::async_trait;
use maohuoban_ai_domain::ai::{AiFactPackage, AiPetDisplaySnapshot, AiResult};
use uuid::Uuid;

/// PetIdentityFactProvider 宠物身份事实端口
/// 核心职责：
/// - 通过后端宠物体系读取授权身份事实
/// - 返回可进入 PromptBuilder 和 Verifier 的事实包
#[async_trait]
pub trait PetIdentityFactProvider: Send + Sync {
    /// load_identity_fact_package 加载目标宠物身份事实包
    async fn load_identity_fact_package(
        &self,
        actor_user_id: Uuid,
        target_pet: &AiPetDisplaySnapshot,
    ) -> AiResult<AiFactPackage>;
}

/// EmptyPetIdentityFactProvider 空身份事实提供者
/// 核心职责：
/// - 为测试或降级场景返回只含目标宠物快照的空事实包
#[derive(Clone, Copy)]
pub struct EmptyPetIdentityFactProvider;

#[async_trait]
impl PetIdentityFactProvider for EmptyPetIdentityFactProvider {
    async fn load_identity_fact_package(
        &self,
        _actor_user_id: Uuid,
        target_pet: &AiPetDisplaySnapshot,
    ) -> AiResult<AiFactPackage> {
        let mut package = AiFactPackage::empty();
        package.target_pet = Some(target_pet.clone());
        Ok(package)
    }
}
