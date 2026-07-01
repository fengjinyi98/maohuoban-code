use std::sync::Arc;

use async_trait::async_trait;
use maohuoban_ai_application::ai::context::AiFactPackageBuilder;
use maohuoban_ai_application::ai::ports::PetDietConfirmationCandidateProvider;
use maohuoban_ai_domain::ai::{
    AiCitation, AiCitationSourceKind, AiError, AiFactEntry, AiFactPackage, AiFactStrength,
    AiPetCandidate, AiPetDisplaySnapshot, AiResult,
};
use maohuoban_pet_application::pet::{PetDietConfirmationCandidate, PetService};
use uuid::Uuid;

/// `PetServiceDietConfirmationCandidateProvider` AI 饮食待确认候选适配器
/// 核心职责：
/// - 通过现有 `PetService` 加载目标宠物饮食待确认候选
/// - 将候选裁剪为 AI `pending_confirmation` 事实
#[derive(Clone)]
pub(crate) struct PetServiceDietConfirmationCandidateProvider {
    pet: Arc<PetService>,
}

impl PetServiceDietConfirmationCandidateProvider {
    /// new 构造饮食待确认候选适配器
    #[must_use]
    pub(crate) fn new(pet: Arc<PetService>) -> Self {
        Self { pet }
    }
}

#[async_trait]
impl PetDietConfirmationCandidateProvider for PetServiceDietConfirmationCandidateProvider {
    async fn load_diet_confirmation_candidate_package(
        &self,
        actor_user_id: Uuid,
        target_pet: &AiPetDisplaySnapshot,
    ) -> AiResult<AiFactPackage> {
        let candidates = self
            .pet
            .load_pet_diet_confirmation_candidates(actor_user_id, target_pet.pet_id)
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
        for candidate in &candidates.candidates {
            add_diet_confirmation_candidate(&mut builder, candidate);
        }
        Ok(builder.build())
    }
}

/// `add_diet_confirmation_candidate` 添加饮食待确认候选事实
/// 核心职责：
/// - 保留追问文案和候选类型
/// - 标记为 `pending_confirmation`，禁止当作已发生事实
fn add_diet_confirmation_candidate(
    builder: &mut AiFactPackageBuilder,
    candidate: &PetDietConfirmationCandidate,
) {
    builder.add_citation(AiCitation {
        source_kind: AiCitationSourceKind::FoodInventoryHint,
        source_id: candidate.food_item_id,
        label: format!("待确认饮食候选: {}", candidate.food_name),
    });
    builder.add_pending_confirmation(AiFactEntry {
        key: "diet.confirmation_candidate".to_owned(),
        value: format!(
            "{} {} {}: {}",
            candidate.candidate_kind,
            candidate.source_change_kind,
            candidate.category,
            candidate.source_question
        ),
        strength: AiFactStrength::PendingConfirmation,
        citation_id: Some(candidate.food_item_id),
    });
}
