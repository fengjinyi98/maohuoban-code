// MHB_STRUCTURE_EXEMPTION: ai/ports 为既有应用端口目录；后续 code-structure P1 统一迁移到 Infrastructure/Services 分层目录。
use async_trait::async_trait;
use maohuoban_ai_domain::ai::{AiFactPackage, AiPetDisplaySnapshot, AiResult};
use uuid::Uuid;

/// FoodInventoryHintProvider 储物柜变化线索端口
/// 核心职责：
/// - 读取当前用户储物柜变化弱线索
/// - 返回只进入 Prompt 弱线索区的事实包
#[async_trait]
pub trait FoodInventoryHintProvider: Send + Sync {
    /// load_food_inventory_hint_package 加载储物柜变化弱线索包
    async fn load_food_inventory_hint_package(
        &self,
        actor_user_id: Uuid,
        target_pet: &AiPetDisplaySnapshot,
    ) -> AiResult<AiFactPackage>;
}
