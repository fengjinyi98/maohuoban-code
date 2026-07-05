mod album;
mod diet;
mod food_inventory;
mod food_inventory_delegation;
mod media;
mod merchant;
mod validation;

use std::sync::Arc;

use chrono::Utc;
use maohuoban_pet_domain::pet::{
    EventKind, PetError, PetEvent, PetProfile, PetResult, PetTimeline, PetTimelineEntry,
};
use uuid::Uuid;

use self::validation::{
    normalize_compact_text, normalize_optional_compact_text, validate_optional_microchip,
    validate_optional_weight, validate_pet_name, validate_text,
};
use super::{
    ConfirmPetDietCandidateInput, ConfirmPetDietCandidateResult, DeletePetEvent, DeletePetProfile,
    DeletePetWeightRecord, DeletedPetEvent, DeletedPetWeightRecord, FoodInventoryRepository,
    NewPetEvent, NewPetProfile, NewPetWeightRecord, PetDietConfirmationCandidates,
    PetProfileDiagnostics, PetRepository, PetWeightRecord, PetWeightRecordSource,
    RestorePetProfile, TradePetImport, TradePetImportInput, UpdatePetEvent, UpdatePetProfile,
    UpdatePetProfileResult, UpdatePetWeightRecord, record_pet_profile,
};
use super::{
    FoodInventoryChangeHints, PetCurrentDietContext, SetPetCurrentStapleInput,
    SetPetDietAssignmentInput,
};
use maohuoban_pet_domain::pet::{FoodScopeType, PetDietAssignment, PetIdentityContext};

/// PetService 宠物应用服务
/// 核心职责：
/// - 编排宠物档案创建、事件追加和时间线读取
/// - 编排商家多宠工作台、窝次和关系追溯读取
pub struct PetService {
    repository: Arc<dyn PetRepository>,
    album_repository: Arc<dyn super::PetAlbumRepository>,
    merchant_repository: Arc<dyn super::MerchantRepository>,
    food_inventory: Arc<dyn FoodInventoryRepository>,
    diet: Arc<dyn super::DietRepository>,
}

impl PetService {
    #[must_use]
    pub fn new(
        repository: Arc<dyn PetRepository>,
        album_repository: Arc<dyn super::PetAlbumRepository>,
        merchant_repository: Arc<dyn super::MerchantRepository>,
        food_inventory: Arc<dyn FoodInventoryRepository>,
        diet: Arc<dyn super::DietRepository>,
    ) -> Self {
        Self {
            repository,
            album_repository,
            merchant_repository,
            food_inventory,
            diet,
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
        let initial_weight_grams = input.weight_grams;
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
        if let Ok(profile) = &result
            && let Some(weight_grams) = initial_weight_grams
        {
            self.create_initial_weight_record(profile.id, owner_user_id, weight_grams)
                .await?;
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
            .authorize_pet_access(input.pet_id, input.owner_user_id)
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

    pub async fn create_pet_event(&self, mut input: NewPetEvent) -> PetResult<PetEvent> {
        validate_text("事件标题", &input.title)?;
        if self
            .repository
            .authorize_pet_access(input.pet_id, input.actor_user_id)
            .await?
            .is_none()
        {
            return Err(PetError::PetNotFound);
        }
        validate_quick_fact_payload(&input)?;
        self.enrich_feeding_event_payload(&mut input).await?;

        if input.event_subkind.as_deref() == Some("abnormal_symptom")
            && input.event_kind == EventKind::Health
        {
            return self.repository.create_abnormal_symptom_event(input).await;
        }

        let event = self.repository.create_pet_event(input).await?;
        self.mark_feeding_food_item_in_use(&event).await?;

        if event.event_subkind.as_deref() == Some("abnormal_recovery")
            && event.event_kind == EventKind::Health
        {
            let episode_id = event
                .event_payload
                .get("episode_id")
                .and_then(|v| v.as_str())
                .and_then(|s| Uuid::parse_str(s).ok());

            self.repository
                .update_episode_for_recovery(
                    event.pet_id.unwrap_or(event.id),
                    event.id,
                    episode_id,
                    event.occurred_at,
                )
                .await?;
        }

        if event.event_subkind.as_deref() == Some("symptom_followup")
            && event.event_kind == EventKind::Health
        {
            let episode_id = event
                .event_payload
                .get("episode_id")
                .and_then(|v| v.as_str())
                .and_then(|s| Uuid::parse_str(s).ok());

            self.repository
                .update_episode_for_followup(
                    event.pet_id.unwrap_or(event.id),
                    event.id,
                    episode_id,
                    event.occurred_at,
                )
                .await?;
        }

        Ok(event)
    }

    pub async fn create_pet_weight_record(
        &self,
        input: NewPetWeightRecord,
    ) -> PetResult<PetWeightRecord> {
        validate_optional_weight(Some(input.weight_grams))?;
        if self
            .repository
            .authorize_pet_access(input.pet_id, input.actor_user_id)
            .await?
            .is_none()
        {
            return Err(PetError::PetNotFound);
        }
        self.repository.create_pet_weight_record(input).await
    }

    pub async fn list_pet_weight_records(
        &self,
        owner_user_id: Uuid,
        pet_id: Uuid,
    ) -> PetResult<Vec<PetWeightRecord>> {
        if self
            .repository
            .authorize_pet_access(pet_id, owner_user_id)
            .await?
            .is_none()
        {
            return Err(PetError::PetNotFound);
        }
        self.repository
            .list_pet_weight_records(owner_user_id, pet_id, 100)
            .await
    }

    pub async fn load_pet_weight_record(
        &self,
        owner_user_id: Uuid,
        record_id: Uuid,
    ) -> PetResult<PetWeightRecord> {
        self.repository
            .load_pet_weight_record(owner_user_id, record_id)
            .await?
            .ok_or(PetError::WeightRecordNotFound)
    }

    pub async fn update_pet_weight_record(
        &self,
        input: UpdatePetWeightRecord,
    ) -> PetResult<PetWeightRecord> {
        validate_optional_weight(Some(input.weight_grams))?;
        self.repository.update_pet_weight_record(input).await
    }

    pub async fn delete_pet_weight_record(
        &self,
        input: DeletePetWeightRecord,
    ) -> PetResult<DeletedPetWeightRecord> {
        self.repository.delete_pet_weight_record(input).await
    }

    async fn create_initial_weight_record(
        &self,
        pet_id: Uuid,
        actor_user_id: Uuid,
        weight_grams: i32,
    ) -> PetResult<PetWeightRecord> {
        self.repository
            .create_pet_weight_record(NewPetWeightRecord {
                pet_id,
                actor_user_id,
                weight_grams,
                note: Some("创建宠物时记录的初始体重".to_owned()),
                source: PetWeightRecordSource::ProfileInitial,
                occurred_at: Utc::now(),
            })
            .await
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
            .authorize_pet_access(pet_id, owner_user_id)
            .await?
            .ok_or(PetError::PetNotFound)
    }

    pub async fn load_pet_timeline(
        &self,
        owner_user_id: Uuid,
        pet_id: Uuid,
    ) -> PetResult<PetTimeline> {
        let Some(pet) = self
            .repository
            .authorize_pet_access(pet_id, owner_user_id)
            .await?
        else {
            return Err(PetError::PetNotFound);
        };
        let mut timeline = self
            .repository
            .load_pet_timeline(owner_user_id, pet_id, 50)
            .await?;
        timeline.entries = merged_timeline_entries(&pet, &timeline.events);
        Ok(timeline)
    }

    pub async fn load_pet_event_detail(
        &self,
        owner_user_id: Uuid,
        event_id: Uuid,
    ) -> PetResult<PetEvent> {
        self.repository
            .load_pet_event_detail(owner_user_id, event_id)
            .await?
            .ok_or(PetError::PetEventNotFound)
    }

    pub async fn update_pet_event(&self, input: UpdatePetEvent) -> PetResult<PetEvent> {
        validate_text("事件标题", &input.title)?;
        validate_quick_fact_update_payload(&input)?;
        self.repository.update_pet_event(input).await
    }

    pub async fn delete_pet_event(&self, input: DeletePetEvent) -> PetResult<DeletedPetEvent> {
        self.repository.delete_pet_event(input).await
    }

    pub async fn load_attention_hints(&self, pet_id: Uuid) -> PetResult<Vec<serde_json::Value>> {
        self.repository.load_attention_hints(pet_id).await
    }

    // --- Diet Assignments (delegated to diet.rs) ---

    pub async fn set_current_staple(
        &self,
        input: SetPetCurrentStapleInput,
    ) -> PetResult<PetDietAssignment> {
        diet::set_current_staple(&self.repository, &self.diet, &self.food_inventory, input).await
    }

    pub async fn set_diet_assignment(
        &self,
        input: SetPetDietAssignmentInput,
    ) -> PetResult<PetDietAssignment> {
        diet::set_diet_assignment(&self.repository, &self.diet, &self.food_inventory, input).await
    }

    pub async fn end_diet_assignment(
        &self,
        pet_id: Uuid,
        assignment_id: Uuid,
        ended_by_user_id: Uuid,
    ) -> PetResult<PetDietAssignment> {
        diet::end_diet_assignment(
            &self.repository,
            &self.diet,
            pet_id,
            assignment_id,
            ended_by_user_id,
        )
        .await
    }

    pub async fn list_active_diet_assignments(
        &self,
        pet_id: Uuid,
        actor_user_id: Uuid,
    ) -> PetResult<Vec<PetDietAssignment>> {
        diet::list_active_diet_assignments(&self.repository, &self.diet, pet_id, actor_user_id)
            .await
    }

    pub async fn find_current_staple(&self, pet_id: Uuid) -> PetResult<Option<PetDietAssignment>> {
        diet::find_current_staple(&self.diet, pet_id).await
    }

    /// 加载 Agent 饮食上下文（强事实）
    pub async fn load_pet_current_diet_context(
        &self,
        owner_user_id: Uuid,
        pet_id: Uuid,
    ) -> PetResult<PetCurrentDietContext> {
        diet::load_pet_current_diet_context(&self.repository, &self.diet, owner_user_id, pet_id)
            .await
    }

    /// 加载储物柜变化线索（弱线索）
    pub async fn load_food_inventory_change_hints(
        &self,
        scope_type: FoodScopeType,
        scope_id: Uuid,
        since: chrono::DateTime<chrono::Utc>,
    ) -> PetResult<FoodInventoryChangeHints> {
        diet::load_food_inventory_change_hints(&self.diet, scope_type, scope_id, since).await
    }

    /// 加载宠物饮食待确认候选
    pub async fn load_pet_diet_confirmation_candidates(
        &self,
        owner_user_id: Uuid,
        pet_id: Uuid,
    ) -> PetResult<PetDietConfirmationCandidates> {
        diet::load_pet_diet_confirmation_candidates(
            &self.repository,
            &self.diet,
            owner_user_id,
            pet_id,
        )
        .await
    }

    /// 确认宠物饮食候选并写入事实
    pub async fn confirm_pet_diet_candidate(
        &self,
        input: ConfirmPetDietCandidateInput,
    ) -> PetResult<ConfirmPetDietCandidateResult> {
        diet::confirm_pet_diet_candidate(&self.repository, &self.diet, &self.food_inventory, input)
            .await
    }

    /// 加载 Agent 身份上下文（含授权校验）
    pub async fn load_identity_context(
        &self,
        user_id: Uuid,
        pet_id: Uuid,
    ) -> PetResult<PetIdentityContext> {
        diet::load_identity_context(&self.repository, user_id, pet_id).await
    }
}

fn validate_quick_fact_payload(input: &NewPetEvent) -> PetResult<()> {
    if input.event_subkind.as_deref() != Some("quick_fact") {
        return Ok(());
    }

    let quick_fact_kind = input
        .event_payload
        .get("quick_fact_kind")
        .and_then(|value| value.as_str())
        .ok_or_else(|| PetError::InvalidInput("快捷状态缺少类型".to_owned()))?;

    match quick_fact_kind {
        "poop_normal" | "energy_normal" | "appetite_normal" => {}
        _ => return Err(PetError::InvalidInput("快捷状态类型无效".to_owned())),
    }

    let submission_id = input
        .event_payload
        .get("quick_fact_submission_id")
        .and_then(|value| value.as_str())
        .ok_or_else(|| PetError::InvalidInput("快捷状态缺少提交标识".to_owned()))?;
    Uuid::parse_str(submission_id)
        .map(|_| ())
        .map_err(|_| PetError::InvalidInput("快捷状态提交标识无效".to_owned()))
}

fn validate_quick_fact_update_payload(input: &UpdatePetEvent) -> PetResult<()> {
    if input.event_subkind.as_deref() != Some("quick_fact") {
        return Ok(());
    }

    let quick_fact_kind = input
        .event_payload
        .get("quick_fact_kind")
        .and_then(|value| value.as_str())
        .ok_or_else(|| PetError::InvalidInput("快捷状态缺少类型".to_owned()))?;

    match quick_fact_kind {
        "poop_normal" | "energy_normal" | "appetite_normal" => Ok(()),
        _ => Err(PetError::InvalidInput("快捷状态类型无效".to_owned())),
    }
}

/// merged_timeline_entries 合并宠物事件与生命周期事实
/// 核心职责：
/// - 将生日、到家日纳入宠物完整时间线
/// - 保持真实事件仍由事件账本提供，生命周期事实由档案字段投影
fn merged_timeline_entries(pet: &PetProfile, events: &[PetEvent]) -> Vec<PetTimelineEntry> {
    let mut entries = events
        .iter()
        .filter_map(PetTimelineEntry::from_event)
        .collect::<Vec<_>>();

    if let Some(birthday) = pet.birthday {
        entries.push(PetTimelineEntry::lifecycle_birth(
            pet.id, &pet.name, birthday,
        ));
    }

    if let Some(arrival_date) = pet.arrival_date {
        entries.push(PetTimelineEntry::lifecycle_homecoming(
            pet.id,
            &pet.name,
            arrival_date,
        ));
    }

    entries.sort_by(|left, right| {
        right
            .occurred_at
            .cmp(&left.occurred_at)
            .then_with(|| right.id.cmp(&left.id))
    });
    entries
}
