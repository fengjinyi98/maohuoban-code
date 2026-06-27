use std::sync::Arc;

use async_trait::async_trait;
use maohuoban_ai_application::ai::context::AiFactPackageBuilder;
use maohuoban_ai_application::ai::ports::PetIdentityFactProvider;
use maohuoban_ai_domain::ai::{
    AiError, AiFactEntry, AiFactPackage, AiFactStrength, AiPetCandidate, AiPetDisplaySnapshot,
    AiResult,
};
use maohuoban_pet_application::pet::PetService;
use uuid::Uuid;

/// PetServiceIdentityFactProvider AI 宠物身份事实适配器
/// 核心职责：
/// - 通过现有 PetService 加载授权身份上下文
/// - 将宠物身份摘要裁剪为 AI 强事实包
#[derive(Clone)]
pub(crate) struct PetServiceIdentityFactProvider {
    pet: Arc<PetService>,
}

impl PetServiceIdentityFactProvider {
    /// new 构造身份事实适配器
    #[must_use]
    pub(crate) fn new(pet: Arc<PetService>) -> Self {
        Self { pet }
    }
}

#[async_trait]
impl PetIdentityFactProvider for PetServiceIdentityFactProvider {
    async fn load_identity_fact_package(
        &self,
        actor_user_id: Uuid,
        target_pet: &AiPetDisplaySnapshot,
    ) -> AiResult<AiFactPackage> {
        let context = self
            .pet
            .load_identity_context(actor_user_id, target_pet.pet_id)
            .await
            .map_err(|error| AiError::Infrastructure(error.to_string()))?;

        let candidate = AiPetCandidate {
            pet_id: target_pet.pet_id,
            name: context.identity.name.clone(),
            avatar_url: target_pet.pet_avatar_url.clone(),
            species: context.identity.species.clone(),
            profile_number: context.identity.profile_number.clone(),
        };
        let mut builder = AiFactPackageBuilder::new(&candidate);
        builder.add_strong_fact(identity_fact("pet_identity.name", context.identity.name));
        builder.add_strong_fact(identity_fact(
            "pet_identity.species",
            context.identity.species,
        ));
        builder.add_strong_fact(identity_fact("pet_identity.sex", context.identity.sex));
        builder.add_strong_fact(identity_fact(
            "pet_identity.life_status",
            context.identity.life_status,
        ));
        if let Some(breed) = context.identity.breed {
            builder.add_strong_fact(identity_fact("pet_identity.breed", breed));
        }
        if let Some(birthday) = context.identity.birthday {
            builder.add_strong_fact(identity_fact("pet_identity.birthday", birthday));
        }
        Ok(builder.build())
    }
}

/// identity_fact 构造身份强事实
/// 核心职责：
/// - 统一身份事实 key 和强度
fn identity_fact(key: &str, value: String) -> AiFactEntry {
    AiFactEntry {
        key: key.to_owned(),
        value,
        strength: AiFactStrength::Strong,
        citation_id: None,
    }
}
