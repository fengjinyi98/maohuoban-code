// MHB_STRUCTURE_EXEMPTION: ai/ports 为既有应用端口目录；后续 code-structure P1 统一迁移到 Infrastructure/Services 分层目录。
use async_trait::async_trait;
use maohuoban_ai_domain::ai::{AiFactPackage, AiPetDisplaySnapshot, AiResult};
use uuid::Uuid;

/// PetDietConfirmationCandidateProvider 宠物饮食待确认候选端口
/// 核心职责：
/// - 读取目标宠物的饮食待确认候选
/// - 返回只标记为 pending_confirmation 的事实包
#[async_trait]
pub trait PetDietConfirmationCandidateProvider: Send + Sync {
    /// load_diet_confirmation_candidate_package 加载饮食待确认候选事实包
    async fn load_diet_confirmation_candidate_package(
        &self,
        actor_user_id: Uuid,
        target_pet: &AiPetDisplaySnapshot,
    ) -> AiResult<AiFactPackage>;
}
