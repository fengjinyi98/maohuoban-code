mod album;
mod diet;
mod food_inventory;
mod food_inventory_delegation;
mod media;
mod merchant;
mod validation;

use std::sync::Arc;

use chrono::{DateTime, Datelike, FixedOffset, Timelike, Utc};
use maohuoban_pet_domain::pet::{
    EventKind, PetError, PetEvent, PetProfile, PetResult, PetTimeline, PetTimelineEntry,
};
use uuid::Uuid;

use self::validation::{
    normalize_compact_text, normalize_optional_compact_text, validate_optional_microchip,
    validate_optional_weight, validate_pet_name, validate_text,
};
use super::{AbnormalFollowupEventInput, PetAbnormalEpisodeFacts};
use super::{
    ConfirmPetDietCandidateInput, ConfirmPetDietCandidateResult, DeletePetEvent, DeletePetProfile,
    DeletePetWeightRecord, DeletedPetEvent, DeletedPetWeightRecord, FoodInventoryRepository,
    NewPetEvent, NewPetProfile, NewPetWeightRecord, PetDietConfirmationCandidates,
    PetProfileDiagnostics, PetRepository, PetWeightRecord, PetWeightRecordSource,
    RestorePetProfile, TradePetImport, TradePetImportInput, UpdatePetEvent, UpdatePetProfile,
    UpdatePetProfileResult, UpdatePetWeightRecord, record_pet_profile,
};
use super::{
    FoodInventoryChangeHints, PetCurrentDietContext, PetRecentHealthFacts,
    SetPetCurrentStapleInput, SetPetDietAssignmentInput,
};
use super::{SaveAgentFollowupPlanInput, SavedAgentFollowupPlan};
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
        self.infer_current_staple_from_repeated_feeding(&event)
            .await?;

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
            let condition_change = event
                .event_payload
                .get("condition_change")
                .and_then(|v| v.as_str())
                .map(str::to_owned);

            self.repository
                .update_episode_for_followup(AbnormalFollowupEventInput {
                    pet_id: event.pet_id.unwrap_or(event.id),
                    event_id: event.id,
                    episode_id,
                    observed_at: event.occurred_at,
                    condition_change,
                })
                .await?;
        }

        Ok(event)
    }

    /// save_agent_followup_plan 保存 Agent 主动追踪计划
    /// 核心职责：
    /// - 校验授权用户、计划文案和推荐动作
    /// - 将真实保存委托给仓储状态机
    pub async fn save_agent_followup_plan(
        &self,
        mut input: SaveAgentFollowupPlanInput,
    ) -> PetResult<SavedAgentFollowupPlan> {
        if self
            .repository
            .authorize_pet_access(input.pet_id, input.actor_user_id)
            .await?
            .is_none()
        {
            return Err(PetError::PetNotFound);
        }
        input.message_title = normalize_compact_text(&input.message_title);
        input.message_body = input.message_body.trim().to_owned();
        input.rationale = input.rationale.trim().to_owned();
        validate_text("追踪提醒正文", &input.message_body)?;
        validate_text("追踪规划理由", &input.rationale)?;
        if input.message_title.is_empty() {
            return Err(PetError::InvalidInput("追踪提醒标题不能为空".to_owned()));
        }
        if input.message_title.chars().count() > 32 {
            return Err(PetError::InvalidInput("追踪提醒标题过长".to_owned()));
        }
        if input.message_body.chars().count() > 240 {
            return Err(PetError::InvalidInput("追踪提醒正文过长".to_owned()));
        }
        if input.rationale.chars().count() > 500 {
            return Err(PetError::InvalidInput("追踪规划理由过长".to_owned()));
        }
        validate_followup_planning_decision(&input.planning_decision, input.due_at)?;
        validate_followup_message_date_consistency(&input.message_body, &input.planning_decision)?;
        if input.recommended_actions.is_empty() {
            return Err(PetError::InvalidInput("推荐动作不能为空".to_owned()));
        }
        for action in &input.recommended_actions {
            if !matches!(
                action.as_str(),
                "update_observation" | "chat_with_agent" | "mark_recovered" | "book_clinic"
            ) {
                return Err(PetError::InvalidInput("推荐动作不在允许范围内".to_owned()));
            }
        }
        self.repository.save_agent_followup_plan(input).await
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

    /// 加载 Agent 近期健康快捷事实（强事实）
    pub async fn load_recent_health_quick_facts(
        &self,
        owner_user_id: Uuid,
        pet_id: Uuid,
        limit: i64,
    ) -> PetResult<PetRecentHealthFacts> {
        diet::load_recent_health_quick_facts(
            &self.repository,
            &self.diet,
            owner_user_id,
            pet_id,
            limit,
        )
        .await
    }

    /// 加载 Agent 异常 episode 追踪事实（强事实）
    pub async fn load_abnormal_episode_facts(
        &self,
        owner_user_id: Uuid,
        pet_id: Uuid,
        episode_id: Option<Uuid>,
    ) -> PetResult<Option<PetAbnormalEpisodeFacts>> {
        if self
            .repository
            .authorize_pet_access(pet_id, owner_user_id)
            .await?
            .is_none()
        {
            return Err(PetError::PetNotFound);
        }
        self.repository
            .load_abnormal_episode_facts(pet_id, episode_id)
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

fn validate_followup_planning_decision(
    planning_decision: &serde_json::Value,
    due_at: DateTime<Utc>,
) -> PetResult<()> {
    let now_at = required_planning_datetime(planning_decision, "now_at")?;
    let occurred_at = required_planning_datetime(planning_decision, "occurred_at")?;
    let selected_due_at = required_planning_datetime(planning_decision, "selected_due_at")?;
    if selected_due_at != due_at {
        return Err(PetError::InvalidInput(
            "追踪计划 due_at 与 time_decision.selected_due_at 不一致".to_owned(),
        ));
    }

    let last_observed_at = optional_planning_datetime(planning_decision, "last_observed_at")?;
    let staleness_anchor = last_observed_at
        .filter(|observed_at| *observed_at > occurred_at)
        .unwrap_or(occurred_at);
    let expected_staleness = now_at
        .signed_duration_since(staleness_anchor)
        .num_minutes()
        .max(0);
    let submitted_staleness = planning_decision
        .pointer("/staleness_assessment/staleness_minutes")
        .and_then(serde_json::Value::as_i64)
        .ok_or_else(|| PetError::InvalidInput("缺少信息断层分钟数".to_owned()))?;
    if (submitted_staleness - expected_staleness).abs() > 2 {
        return Err(PetError::InvalidInput(
            "信息断层分钟数与异常发生/最近观察时间不一致".to_owned(),
        ));
    }

    let delay_minutes = planning_decision
        .get("delay_minutes")
        .and_then(serde_json::Value::as_i64)
        .ok_or_else(|| PetError::InvalidInput("缺少追踪延迟分钟数".to_owned()))?;
    let expected_delay = selected_due_at.signed_duration_since(now_at).num_minutes();
    if (delay_minutes - expected_delay).abs() > 2 {
        return Err(PetError::InvalidInput(
            "追踪延迟分钟数与选择的提醒时间不一致".to_owned(),
        ));
    }

    let attention_timing = planning_decision
        .get("attention_timing")
        .and_then(serde_json::Value::as_str)
        .ok_or_else(|| PetError::InvalidInput("缺少追踪时机判断".to_owned()))?;
    if !matches!(
        attention_timing,
        "now_or_soon" | "scheduled_later" | "monitor_without_prompt"
    ) {
        return Err(PetError::InvalidInput(
            "追踪时机判断不在允许范围内".to_owned(),
        ));
    }

    required_planning_string(
        planning_decision,
        "/staleness_assessment/basis",
        "缺少信息断层依据",
    )?;
    required_planning_string(
        planning_decision,
        "/staleness_assessment/reason",
        "缺少信息断层理由",
    )?;
    required_planning_string(
        planning_decision,
        "/identity_context/species",
        "缺少宠物身份上下文",
    )?;

    Ok(())
}

fn required_planning_datetime(
    planning_decision: &serde_json::Value,
    key: &str,
) -> PetResult<DateTime<Utc>> {
    planning_decision
        .get(key)
        .and_then(serde_json::Value::as_str)
        .and_then(parse_utc_datetime)
        .ok_or_else(|| PetError::InvalidInput(format!("缺少或无法解析 {key}")))
}

fn optional_planning_datetime(
    planning_decision: &serde_json::Value,
    key: &str,
) -> PetResult<Option<DateTime<Utc>>> {
    let Some(value) = planning_decision.get(key) else {
        return Ok(None);
    };
    if value.is_null() {
        return Ok(None);
    }
    value
        .as_str()
        .and_then(parse_utc_datetime)
        .map(Some)
        .ok_or_else(|| PetError::InvalidInput(format!("无法解析 {key}")))
}

fn required_planning_string(
    planning_decision: &serde_json::Value,
    pointer: &str,
    error_message: &str,
) -> PetResult<()> {
    match planning_decision
        .pointer(pointer)
        .and_then(serde_json::Value::as_str)
    {
        Some(value) if !value.trim().is_empty() => Ok(()),
        _ => Err(PetError::InvalidInput(error_message.to_owned())),
    }
}

fn validate_followup_message_date_consistency(
    message_body: &str,
    planning_decision: &serde_json::Value,
) -> PetResult<()> {
    let Some(now_at) = planning_decision
        .get("now_at")
        .and_then(serde_json::Value::as_str)
        .and_then(parse_utc_datetime)
    else {
        return Ok(());
    };
    let Some(episode_started_at) = planning_decision
        .get("episode_started_at")
        .and_then(serde_json::Value::as_str)
        .and_then(parse_utc_datetime)
    else {
        return Ok(());
    };

    let shanghai_offset = FixedOffset::east_opt(8 * 60 * 60).expect("valid shanghai offset");
    let now_local = now_at.with_timezone(&shanghai_offset).date_naive();
    let episode_local = episode_started_at
        .with_timezone(&shanghai_offset)
        .date_naive();
    let yesterday_local = now_local.pred_opt();

    if message_body.contains("昨天")
        && Some(episode_local) != yesterday_local
        && mentions_abnormal_event_date_context(message_body)
    {
        return Err(PetError::InvalidInput(
            "追踪提醒正文日期与异常发生日期不一致".to_owned(),
        ));
    }

    let episode_date_mentions = local_date_mentions(episode_local.month(), episode_local.day());
    let mismatched_date_mentions = adjacent_local_date_mentions(now_local, episode_local);
    if mentions_abnormal_event_date_context(message_body)
        && mismatched_date_mentions
            .iter()
            .any(|mention| message_body.contains(mention))
        && !episode_date_mentions
            .iter()
            .any(|mention| message_body.contains(mention))
    {
        return Err(PetError::InvalidInput(
            "追踪提醒正文日期与异常发生日期不一致".to_owned(),
        ));
    }

    validate_followup_message_day_period_consistency(message_body, episode_started_at)?;

    Ok(())
}

fn validate_followup_message_day_period_consistency(
    message_body: &str,
    episode_started_at: DateTime<Utc>,
) -> PetResult<()> {
    let mentioned_periods = event_context_day_period_mentions(message_body);
    if mentioned_periods.is_empty() {
        return Ok(());
    }

    let shanghai_offset = FixedOffset::east_opt(8 * 60 * 60).expect("valid shanghai offset");
    let local_hour = episode_started_at.with_timezone(&shanghai_offset).hour();
    if mentioned_periods
        .iter()
        .any(|period| !period.contains_hour(local_hour))
    {
        return Err(PetError::InvalidInput(
            "追踪提醒正文时段与异常发生时间不一致".to_owned(),
        ));
    }

    Ok(())
}

fn parse_utc_datetime(value: &str) -> Option<DateTime<Utc>> {
    DateTime::parse_from_rfc3339(value)
        .ok()
        .map(|datetime| datetime.with_timezone(&Utc))
}

fn mentions_abnormal_event_date_context(message_body: &str) -> bool {
    ["发现", "出现", "记录", "异常", "发生"]
        .iter()
        .any(|keyword| message_body.contains(keyword))
}

#[derive(Clone, Copy)]
enum LocalDayPeriod {
    Midnight,
    Dawn,
    Morning,
    Forenoon,
    Noon,
    Afternoon,
    Dusk,
    Evening,
}

impl LocalDayPeriod {
    fn token(self) -> &'static str {
        match self {
            Self::Midnight => "凌晨",
            Self::Dawn => "清晨",
            Self::Morning => "早上",
            Self::Forenoon => "上午",
            Self::Noon => "中午",
            Self::Afternoon => "下午",
            Self::Dusk => "傍晚",
            Self::Evening => "晚上",
        }
    }

    fn contains_hour(self, hour: u32) -> bool {
        match self {
            Self::Midnight => hour < 6,
            Self::Dawn => (4..8).contains(&hour),
            Self::Morning => (5..10).contains(&hour),
            Self::Forenoon => (6..12).contains(&hour),
            Self::Noon => (11..14).contains(&hour),
            Self::Afternoon => (12..18).contains(&hour),
            Self::Dusk => (17..20).contains(&hour),
            Self::Evening => hour >= 18,
        }
    }
}

fn event_context_day_period_mentions(message_body: &str) -> Vec<LocalDayPeriod> {
    [
        LocalDayPeriod::Midnight,
        LocalDayPeriod::Dawn,
        LocalDayPeriod::Morning,
        LocalDayPeriod::Forenoon,
        LocalDayPeriod::Noon,
        LocalDayPeriod::Afternoon,
        LocalDayPeriod::Dusk,
        LocalDayPeriod::Evening,
    ]
    .into_iter()
    .filter(|period| day_period_mentions_event_context(message_body, period.token()))
    .collect()
}

fn day_period_mentions_event_context(message_body: &str, period_token: &str) -> bool {
    let chars: Vec<char> = message_body.chars().collect();
    let token_chars: Vec<char> = period_token.chars().collect();
    if chars.len() < token_chars.len() {
        return false;
    }

    (0..=chars.len() - token_chars.len()).any(|index| {
        chars[index..index + token_chars.len()] == token_chars
            && mentions_abnormal_event_date_context(&nearby_chars(
                &chars,
                index,
                token_chars.len(),
                12,
            ))
    })
}

fn nearby_chars(chars: &[char], index: usize, token_len: usize, radius: usize) -> String {
    let start = index.saturating_sub(radius);
    let end = (index + token_len + radius).min(chars.len());
    chars[start..end].iter().collect()
}

fn local_date_mentions(month: u32, day: u32) -> Vec<String> {
    vec![
        format!("{month}/{day}"),
        format!("{month}月{day}日"),
        format!("{month} 月 {day} 日"),
    ]
}

fn adjacent_local_date_mentions(
    now_local: chrono::NaiveDate,
    episode_local: chrono::NaiveDate,
) -> Vec<String> {
    [now_local.pred_opt(), now_local.succ_opt()]
        .into_iter()
        .flatten()
        .filter(|date| *date != episode_local)
        .flat_map(|date| local_date_mentions(date.month(), date.day()))
        .collect()
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
