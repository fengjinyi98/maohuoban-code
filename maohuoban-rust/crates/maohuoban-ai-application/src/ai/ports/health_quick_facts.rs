// MHB_STRUCTURE_EXEMPTION: ai/ports 为既有应用端口目录；后续 code-structure P1 统一迁移到 Infrastructure/Services 分层目录。
use async_trait::async_trait;
use maohuoban_ai_domain::ai::{AiFactPackage, AiPetDisplaySnapshot, AiResult};
use uuid::Uuid;

/// PetHealthQuickFactProvider 宠物健康快捷事实端口
/// 核心职责：
/// - 读取便便、精神、食欲等健康快捷事实
/// - 返回可进入 PromptBuilder 和 Verifier 的事实包
#[async_trait]
pub trait PetHealthQuickFactProvider: Send + Sync {
    async fn load_recent_health_quick_fact_package(
        &self,
        actor_user_id: Uuid,
        target_pet: &AiPetDisplaySnapshot,
    ) -> AiResult<AiFactPackage>;
}

/// EmptyPetHealthQuickFactProvider 空健康快捷事实提供者
/// 核心职责：
/// - 为测试场景返回只含目标宠物快照的空事实包
#[derive(Clone, Copy)]
pub struct EmptyPetHealthQuickFactProvider;

#[async_trait]
impl PetHealthQuickFactProvider for EmptyPetHealthQuickFactProvider {
    async fn load_recent_health_quick_fact_package(
        &self,
        _actor_user_id: Uuid,
        target_pet: &AiPetDisplaySnapshot,
    ) -> AiResult<AiFactPackage> {
        let mut package = AiFactPackage::empty();
        package.target_pet = Some(target_pet.clone());
        Ok(package)
    }
}
