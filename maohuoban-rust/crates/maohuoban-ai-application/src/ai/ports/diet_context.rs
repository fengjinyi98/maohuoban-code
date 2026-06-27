// MHB_STRUCTURE_EXEMPTION: ai/ports 为既有应用端口目录；后续 code-structure P1 统一迁移到 Infrastructure/Services 分层目录。
use async_trait::async_trait;
use maohuoban_ai_domain::ai::{AiFactPackage, AiPetDisplaySnapshot, AiResult};
use uuid::Uuid;

/// PetDietFactProvider 宠物饮食事实端口
/// 核心职责：
/// - 通过后端宠物体系读取授权饮食强事实
/// - 返回可进入 PromptBuilder 和 Verifier 的事实包
#[async_trait]
pub trait PetDietFactProvider: Send + Sync {
    /// load_current_diet_fact_package 加载目标宠物当前饮食事实包
    async fn load_current_diet_fact_package(
        &self,
        actor_user_id: Uuid,
        target_pet: &AiPetDisplaySnapshot,
    ) -> AiResult<AiFactPackage>;
}

/// EmptyPetDietFactProvider 空饮食事实提供者
/// 核心职责：
/// - 为测试或降级场景返回只含目标宠物快照的空事实包
#[derive(Clone, Copy)]
pub struct EmptyPetDietFactProvider;

#[async_trait]
impl PetDietFactProvider for EmptyPetDietFactProvider {
    async fn load_current_diet_fact_package(
        &self,
        _actor_user_id: Uuid,
        target_pet: &AiPetDisplaySnapshot,
    ) -> AiResult<AiFactPackage> {
        let mut package = AiFactPackage::empty();
        package.target_pet = Some(target_pet.clone());
        Ok(package)
    }
}
