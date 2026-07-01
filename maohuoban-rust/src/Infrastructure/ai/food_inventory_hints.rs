use std::sync::Arc;

use async_trait::async_trait;
use chrono::{Duration, Utc};
use maohuoban_ai_application::ai::context::AiFactPackageBuilder;
use maohuoban_ai_application::ai::ports::FoodInventoryHintProvider;
use maohuoban_ai_domain::ai::{
    AiCitation, AiCitationSourceKind, AiError, AiFactEntry, AiFactPackage, AiFactStrength,
    AiPetCandidate, AiPetDisplaySnapshot, AiResult,
};
use maohuoban_pet_application::pet::{FoodInventoryChangeHint, PetService};
use maohuoban_pet_domain::pet::FoodScopeType;
use uuid::Uuid;

/// `PetServiceFoodInventoryHintProvider` AI 储物柜变化线索适配器
/// 核心职责：
/// - 通过现有 `PetService` 加载当前用户近期储物柜变化
/// - 将变化记录裁剪为 AI 弱线索和引用
#[derive(Clone)]
pub(crate) struct PetServiceFoodInventoryHintProvider {
    pet: Arc<PetService>,
}

impl PetServiceFoodInventoryHintProvider {
    /// new 构造储物柜线索适配器
    #[must_use]
    pub(crate) fn new(pet: Arc<PetService>) -> Self {
        Self { pet }
    }
}

#[async_trait]
impl FoodInventoryHintProvider for PetServiceFoodInventoryHintProvider {
    async fn load_food_inventory_hint_package(
        &self,
        actor_user_id: Uuid,
        target_pet: &AiPetDisplaySnapshot,
    ) -> AiResult<AiFactPackage> {
        let since = Utc::now() - Duration::days(30);
        let hints = self
            .pet
            .load_food_inventory_change_hints(FoodScopeType::User, actor_user_id, since)
            .await
            .map_err(|error| AiError::Infrastructure(error.to_string()))?;

        let candidate = AiPetCandidate {
            pet_id: target_pet.pet_id,
            name: target_pet.pet_name.clone(),
            avatar_url: target_pet.pet_avatar_url.clone(),
            species: target_pet.pet_species.clone(),
            profile_number: target_pet.profile_number.clone(),
        };
        let mut builder = AiFactPackageBuilder::new(&candidate);
        for hint in &hints.hints {
            add_food_inventory_hint(&mut builder, hint);
        }
        Ok(builder.build())
    }
}

/// `add_food_inventory_hint` 添加储物柜变化弱线索
/// 核心职责：
/// - 将食品资产变化标记为 weak hint
/// - 使用 food item id 作为引用，避免被当作摄入事实
fn add_food_inventory_hint(builder: &mut AiFactPackageBuilder, hint: &FoodInventoryChangeHint) {
    builder.add_citation(AiCitation {
        source_kind: AiCitationSourceKind::FoodInventoryHint,
        source_id: hint.item_id,
        label: format!("储物柜变化: {}", hint.name),
    });
    builder.add_weak_hint(AiFactEntry {
        key: "food_inventory.change_hint".to_owned(),
        value: format!("{} {}: {}", hint.change_kind, hint.category, hint.name),
        strength: AiFactStrength::Weak,
        citation_id: Some(hint.item_id),
    });
}
