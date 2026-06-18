mod media;
mod merchant;
mod validation;

use std::sync::Arc;

use maohuoban_pet_domain::pet::{PetError, PetEvent, PetProfile, PetResult, PetTimeline};
use uuid::Uuid;

use self::validation::{
    normalize_compact_text, normalize_optional_compact_text, validate_optional_microchip,
    validate_optional_weight, validate_pet_name, validate_text,
};
use super::{
    DeletePetProfile, NewPetEvent, NewPetProfile, PetProfileDiagnostics, PetRepository,
    RestorePetProfile, TradePetImport, TradePetImportInput, UpdatePetProfile,
    UpdatePetProfileResult, record_pet_profile,
};

/// PetService 宠物应用服务
/// 核心职责：
/// - 编排宠物档案创建、事件追加和时间线读取
/// - 编排商家多宠工作台、窝次和关系追溯读取
pub struct PetService {
    repository: Arc<dyn PetRepository>,
    merchant_repository: Arc<dyn super::MerchantRepository>,
}

impl PetService {
    #[must_use]
    pub fn new(
        repository: Arc<dyn PetRepository>,
        merchant_repository: Arc<dyn super::MerchantRepository>,
    ) -> Self {
        Self {
            repository,
            merchant_repository,
        }
    }

    pub async fn create_pet_profile(&self, mut input: NewPetProfile) -> PetResult<PetProfile> {
        input.name = normalize_compact_text(&input.name);
        input.breed = normalize_optional_compact_text(input.breed);
        validate_pet_name(&input.name)?;
        validate_optional_microchip(input.microchip_number.as_deref())?;
        validate_optional_weight(input.weight_grams)?;
        let owner_user_id = input.owner_user_id;
        let breed = input.breed.clone();
        record_pet_profile(PetProfileDiagnostics {
            stage: "service.normalized",
            action: "create",
            user_id: owner_user_id,
            pet_id: None,
            breed: breed.as_deref(),
            success: true,
        });
        let result = self.repository.create_pet_profile(input).await;
        match &result {
            Ok(profile) => record_pet_profile(PetProfileDiagnostics {
                stage: "service.result",
                action: "create",
                user_id: owner_user_id,
                pet_id: Some(profile.id),
                breed: profile.breed.as_deref(),
                success: true,
            }),
            Err(_error) => record_pet_profile(PetProfileDiagnostics {
                stage: "service.result",
                action: "create",
                user_id: owner_user_id,
                pet_id: None,
                breed: breed.as_deref(),
                success: false,
            }),
        }
        result
    }

    pub async fn update_pet_profile(
        &self,
        mut input: UpdatePetProfile,
    ) -> PetResult<UpdatePetProfileResult> {
        input.name = input.name.map(|name| normalize_compact_text(&name));
        input.breed = normalize_optional_compact_text(input.breed);
        if let Some(name) = input.name.as_deref() {
            validate_pet_name(name)?;
        }
        validate_optional_microchip(input.microchip_number.as_deref())?;
        validate_optional_weight(input.weight_grams)?;
        if self
            .repository
            .find_pet_for_owner(input.pet_id, input.owner_user_id)
            .await?
            .is_none()
        {
            return Err(PetError::PetNotFound);
        }
        let owner_user_id = input.owner_user_id;
        let pet_id = input.pet_id;
        let breed = input.breed.clone();
        record_pet_profile(PetProfileDiagnostics {
            stage: "service.normalized",
            action: "update",
            user_id: owner_user_id,
            pet_id: Some(pet_id),
            breed: breed.as_deref(),
            success: true,
        });
        let result = self.repository.update_pet_profile(input).await;
        match &result {
            Ok(update) => record_pet_profile(PetProfileDiagnostics {
                stage: "service.result",
                action: "update",
                user_id: owner_user_id,
                pet_id: Some(update.profile.id),
                breed: update.profile.breed.as_deref(),
                success: true,
            }),
            Err(_error) => record_pet_profile(PetProfileDiagnostics {
                stage: "service.result",
                action: "update",
                user_id: owner_user_id,
                pet_id: Some(pet_id),
                breed: breed.as_deref(),
                success: false,
            }),
        }
        result
    }

    pub async fn delete_pet_profile(&self, input: DeletePetProfile) -> PetResult<PetProfile> {
        if self
            .repository
            .find_pet_for_owner(input.pet_id, input.owner_user_id)
            .await?
            .is_none()
        {
            return Err(PetError::PetNotFound);
        }
        self.repository.soft_delete_pet_profile(input).await
    }

    pub async fn restore_pet_profile(&self, input: RestorePetProfile) -> PetResult<PetProfile> {
        self.repository.restore_pet_profile(input).await
    }

    pub async fn create_pet_event(&self, input: NewPetEvent) -> PetResult<PetEvent> {
        validate_text("事件标题", &input.title)?;
        if self
            .repository
            .find_pet_for_owner(input.pet_id, input.actor_user_id)
            .await?
            .is_none()
        {
            return Err(PetError::PetNotFound);
        }
        self.repository.create_pet_event(input).await
    }

    pub async fn import_trade_pet(
        &self,
        mut input: TradePetImportInput,
    ) -> PetResult<TradePetImport> {
        input.name = normalize_compact_text(&input.name);
        input.breed = normalize_optional_compact_text(input.breed);
        validate_pet_name(&input.name)?;
        validate_text("来源方", &input.seller_name)?;
        self.repository.import_trade_pet(input).await
    }

    pub async fn list_pet_profiles(&self, owner_user_id: Uuid) -> PetResult<Vec<PetProfile>> {
        self.repository
            .list_pet_profiles_for_owner(owner_user_id)
            .await
    }

    pub async fn load_pet_profile(
        &self,
        owner_user_id: Uuid,
        pet_id: Uuid,
    ) -> PetResult<PetProfile> {
        self.repository
            .find_pet_for_owner(pet_id, owner_user_id)
            .await?
            .ok_or(PetError::PetNotFound)
    }

    pub async fn load_pet_timeline(
        &self,
        owner_user_id: Uuid,
        pet_id: Uuid,
    ) -> PetResult<PetTimeline> {
        if self
            .repository
            .find_pet_for_owner(pet_id, owner_user_id)
            .await?
            .is_none()
        {
            return Err(PetError::PetNotFound);
        }
        self.repository
            .load_pet_timeline(owner_user_id, pet_id, 50)
            .await
    }

    pub async fn load_pet_event_detail(
        &self,
        owner_user_id: Uuid,
        event_id: Uuid,
    ) -> PetResult<PetEvent> {
        self.repository
            .load_pet_event_detail(owner_user_id, event_id)
            .await?
            .ok_or(PetError::PetNotFound)
    }
}
