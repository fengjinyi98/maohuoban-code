mod media;
mod merchant;
mod validation;

use std::{collections::HashSet, sync::Arc};

use chrono::{Duration, Utc};
use maohuoban_pet_domain::pet::{
    AgentConfirmedFactPayload, DietAssignmentRole, DietChangePayload, EventKind, EventVisibility,
    FeedingCorrectionPayload, FoodInventoryCategory, FoodInventoryItem, FoodInventoryStatus,
    FoodScopeType, PetDietAssignment, PetError, PetEvent, PetIdentityContext, PetProfile,
    PetResult, PetTimeline,
};
use uuid::Uuid;

use self::validation::{
    normalize_compact_text, normalize_optional_compact_text, validate_optional_microchip,
    validate_optional_weight, validate_pet_name, validate_text,
};
use super::{
    ConfirmPetDietCandidateInput, ConfirmPetDietCandidateResult, DeletePetProfile,
    FoodInventoryRepository, NewFoodInventoryItem, NewPetEvent, NewPetProfile,
    PetDietConfirmationCandidate, PetDietConfirmationCandidates, PetProfileDiagnostics,
    PetRepository, RestorePetProfile, SetPetCurrentStapleInput, SetPetDietAssignmentInput,
    TradePetImport, TradePetImportInput, UpdateFoodInventoryItem, UpdatePetProfile,
    UpdatePetProfileResult, record_pet_profile,
};

/// PetService 宠物应用服务
/// 核心职责：
/// - 编排宠物档案创建、事件追加和时间线读取
/// - 编排商家多宠工作台、窝次和关系追溯读取
pub struct PetService {
    repository: Arc<dyn PetRepository>,
    merchant_repository: Arc<dyn super::MerchantRepository>,
    food_inventory: Arc<dyn FoodInventoryRepository>,
    diet: Arc<dyn super::DietRepository>,
}

impl PetService {
    #[must_use]
    pub fn new(
        repository: Arc<dyn PetRepository>,
        merchant_repository: Arc<dyn super::MerchantRepository>,
        food_inventory: Arc<dyn FoodInventoryRepository>,
        diet: Arc<dyn super::DietRepository>,
    ) -> Self {
        Self {
            repository,
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
        self.enrich_feeding_event_payload(&mut input).await?;

        // 检查是否 abnormal_symptom；保存字段到局部变量避免 move 后访问 input
        let is_abnormal = input.event_subkind.as_deref() == Some("abnormal_symptom")
            && input.event_kind == EventKind::Health;
        let abnormal_pet_id = input.pet_id;
        let abnormal_actor_user_id = input.actor_user_id;

        // 先创建事件以获取 event_id
        let event = self
            .repository
            .create_pet_event(input)
            .await?;

        // abnormal_symptom 事件：原子创建 episode + hint
        if is_abnormal {
            let symptom_kinds_str = event
                .event_payload
                .get("symptom_kinds")
                .map(|v| v.to_string())
                .unwrap_or_else(|| "[]".to_owned());
            let severity_str = event
                .event_payload
                .get("severity")
                .and_then(|v| v.as_str())
                .unwrap_or("mild")
                .to_owned();
            let primary_symptom_str = event
                .event_payload
                .get("symptom_kinds")
                .and_then(|v| v.as_array())
                .and_then(|a| a.first())
                .and_then(|v| v.as_str())
                .unwrap_or("other")
                .to_owned();

            let _episode_id = self
                .repository
                .handle_abnormal_symptom_event(
                    abnormal_pet_id,
                    abnormal_actor_user_id,
                    event.id,
                    &symptom_kinds_str,
                    &primary_symptom_str,
                    &severity_str,
                    event.occurred_at,
                )
                .await?;
        }

        Ok(event)
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
        if self
            .repository
            .authorize_pet_access(pet_id, owner_user_id)
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

    // --- Food Inventory ---

    pub async fn create_food_inventory_item(
        &self,
        input: NewFoodInventoryItem,
    ) -> PetResult<FoodInventoryItem> {
        reject_direct_archived_status(input.inventory_status)?;
        self.food_inventory.create_item(input).await
    }

    pub async fn list_food_inventory_items(
        &self,
        scope_type: FoodScopeType,
        scope_id: Uuid,
        category: Option<FoodInventoryCategory>,
        status: Option<FoodInventoryStatus>,
    ) -> PetResult<Vec<FoodInventoryItem>> {
        self.food_inventory
            .list_items(scope_type, scope_id, category, status)
            .await
    }

    pub async fn find_food_inventory_item(&self, item_id: Uuid) -> PetResult<FoodInventoryItem> {
        self.food_inventory
            .find_item(item_id)
            .await?
            .ok_or(PetError::FoodInventoryNotFound)
    }

    pub async fn update_food_inventory_item(
        &self,
        input: UpdateFoodInventoryItem,
    ) -> PetResult<FoodInventoryItem> {
        if let Some(status) = input.inventory_status {
            reject_direct_archived_status(status)?;
        }
        self.ensure_food_inventory_editor(input.item_id, input.editor_user_id)
            .await?;
        self.food_inventory.update_item(input).await
    }

    pub async fn archive_food_inventory_item(
        &self,
        item_id: Uuid,
        editor_user_id: Uuid,
    ) -> PetResult<FoodInventoryItem> {
        self.ensure_food_inventory_editor(item_id, editor_user_id)
            .await?;
        self.food_inventory
            .archive_item(item_id, editor_user_id)
            .await
    }

    pub async fn restore_food_inventory_item(
        &self,
        item_id: Uuid,
        editor_user_id: Uuid,
        status: FoodInventoryStatus,
    ) -> PetResult<FoodInventoryItem> {
        reject_direct_archived_status(status)?;
        self.ensure_food_inventory_editor(item_id, editor_user_id)
            .await?;
        self.food_inventory
            .restore_item(item_id, editor_user_id, status)
            .await
    }

    pub async fn restock_food_inventory_item(
        &self,
        item_id: Uuid,
        editor_user_id: Uuid,
        quantity: i32,
    ) -> PetResult<FoodInventoryItem> {
        self.ensure_food_inventory_editor(item_id, editor_user_id)
            .await?;
        self.food_inventory
            .restock_item(item_id, editor_user_id, quantity)
            .await
    }

    async fn ensure_food_inventory_editor(
        &self,
        item_id: Uuid,
        editor_user_id: Uuid,
    ) -> PetResult<()> {
        self.load_food_inventory_editor_item(item_id, editor_user_id)
            .await
            .map(|_| ())
    }

    async fn load_food_inventory_editor_item(
        &self,
        item_id: Uuid,
        editor_user_id: Uuid,
    ) -> PetResult<FoodInventoryItem> {
        let item = self
            .food_inventory
            .find_item(item_id)
            .await?
            .ok_or(PetError::FoodInventoryNotFound)?;
        if item.scope_type == FoodScopeType::User && item.scope_id == editor_user_id {
            Ok(item)
        } else {
            Err(PetError::FoodInventoryNotFound)
        }
    }

    async fn load_food_inventory_consumable_item(
        &self,
        item_id: Uuid,
        editor_user_id: Uuid,
    ) -> PetResult<FoodInventoryItem> {
        let item = self
            .load_food_inventory_editor_item(item_id, editor_user_id)
            .await?;
        if item.inventory_status.is_archived() || item.archived_at.is_some() {
            Err(PetError::InvalidInput(
                "已归档食品资产不能用于饮食配置或喂食记录".to_owned(),
            ))
        } else {
            Ok(item)
        }
    }

    async fn enrich_feeding_event_payload(&self, input: &mut NewPetEvent) -> PetResult<()> {
        if input.event_subkind.as_deref() != Some("feeding") {
            return Ok(());
        }
        let Some(food_item_id_value) = input.event_payload.get("food_item_id") else {
            return Ok(());
        };
        if food_item_id_value.is_null() {
            return Ok(());
        }
        let food_item_id = food_item_id_value
            .as_str()
            .and_then(|value| Uuid::parse_str(value).ok())
            .ok_or_else(|| PetError::InvalidInput("食品资产 ID 格式不正确".to_owned()))?;
        let food_item = self
            .load_food_inventory_consumable_item(food_item_id, input.actor_user_id)
            .await?;
        let payload = input
            .event_payload
            .as_object_mut()
            .ok_or_else(|| PetError::InvalidInput("喂食事件载荷格式不正确".to_owned()))?;
        payload.insert(
            "food_snapshot".to_owned(),
            serde_json::json!({
                "name": food_item.name,
                "brand": food_item.brand,
                "category": food_item.category.as_str(),
                "spec": food_item.spec
            }),
        );
        Ok(())
    }

    async fn ensure_pet_access(&self, pet_id: Uuid, user_id: Uuid) -> PetResult<()> {
        self.repository
            .authorize_pet_access(pet_id, user_id)
            .await?
            .map(|_| ())
            .ok_or(PetError::PetNotFound)
    }

    // --- Diet Assignments ---

    pub async fn set_current_staple(
        &self,
        input: SetPetCurrentStapleInput,
    ) -> PetResult<PetDietAssignment> {
        self.ensure_pet_access(input.pet_id, input.created_by_user_id)
            .await?;
        self.load_food_inventory_consumable_item(input.food_item_id, input.created_by_user_id)
            .await?;
        let previous = self.diet.find_current_staple(input.pet_id).await?;
        let pet_id = input.pet_id;
        let food_item_id = input.food_item_id;
        let created_by_user_id = input.created_by_user_id;
        let reason = input.reason.clone();
        let assignment = self.diet.set_current_staple(input).await?;
        let payload = DietChangePayload {
            from_food_item_id: previous.map(|assignment| assignment.food_item_id),
            to_food_item_id: food_item_id,
            assignment_id: assignment.id,
            transition_state: "started".to_owned(),
            started_at: assignment.started_at,
            confirmed_by_user_id: created_by_user_id,
        };
        let event_payload = serde_json::to_value(payload).map_err(|error| {
            PetError::Infrastructure(format!("failed to serialize diet change payload: {error}"))
        })?;
        self.repository
            .create_pet_event(NewPetEvent {
                pet_id,
                actor_user_id: created_by_user_id,
                event_kind: EventKind::Daily,
                event_subkind: Some("diet_change".to_owned()),
                title: "当前主粮已更新".to_owned(),
                summary: reason,
                visibility: EventVisibility::Private,
                event_payload,
                occurred_at: assignment.started_at,
            })
            .await?;
        Ok(assignment)
    }

    pub async fn set_diet_assignment(
        &self,
        input: SetPetDietAssignmentInput,
    ) -> PetResult<PetDietAssignment> {
        if matches!(input.role, DietAssignmentRole::CurrentStaple) {
            return Err(PetError::InvalidInput(
                "当前主粮必须通过当前主粮专用接口设置".to_owned(),
            ));
        }
        self.ensure_pet_access(input.pet_id, input.created_by_user_id)
            .await?;
        self.load_food_inventory_consumable_item(input.food_item_id, input.created_by_user_id)
            .await?;
        self.diet.set_assignment(input).await
    }

    pub async fn end_diet_assignment(
        &self,
        pet_id: Uuid,
        assignment_id: Uuid,
        ended_by_user_id: Uuid,
    ) -> PetResult<PetDietAssignment> {
        self.ensure_pet_access(pet_id, ended_by_user_id).await?;
        self.diet
            .end_assignment(pet_id, assignment_id, ended_by_user_id)
            .await
    }

    pub async fn list_active_diet_assignments(
        &self,
        pet_id: Uuid,
        actor_user_id: Uuid,
    ) -> PetResult<Vec<PetDietAssignment>> {
        self.ensure_pet_access(pet_id, actor_user_id).await?;
        self.diet.list_active_assignments(pet_id).await
    }

    pub async fn find_current_staple(&self, pet_id: Uuid) -> PetResult<Option<PetDietAssignment>> {
        self.diet.find_current_staple(pet_id).await
    }

    /// 加载 Agent 饮食上下文（强事实）
    pub async fn load_pet_current_diet_context(
        &self,
        owner_user_id: Uuid,
        pet_id: Uuid,
    ) -> PetResult<super::PetCurrentDietContext> {
        self.ensure_pet_access(pet_id, owner_user_id).await?;
        self.diet.load_pet_current_diet_context(pet_id).await
    }

    /// 加载储物柜变化线索（弱线索）
    pub async fn load_food_inventory_change_hints(
        &self,
        scope_type: FoodScopeType,
        scope_id: Uuid,
        since: chrono::DateTime<chrono::Utc>,
    ) -> PetResult<super::FoodInventoryChangeHints> {
        self.diet
            .load_food_inventory_change_hints(scope_type, scope_id, since)
            .await
    }

    /// 加载宠物饮食待确认候选
    pub async fn load_pet_diet_confirmation_candidates(
        &self,
        owner_user_id: Uuid,
        pet_id: Uuid,
    ) -> PetResult<PetDietConfirmationCandidates> {
        self.ensure_pet_access(pet_id, owner_user_id).await?;
        let identity = self.load_identity_context(owner_user_id, pet_id).await?;
        let context = self.diet.load_pet_current_diet_context(pet_id).await?;
        let hints = self
            .diet
            .load_food_inventory_change_hints(
                FoodScopeType::User,
                owner_user_id,
                Utc::now() - Duration::days(30),
            )
            .await?;

        let mut known_food_item_ids = HashSet::new();
        if let Some(current_staple) = context.current_staple {
            known_food_item_ids.insert(current_staple.food_item_id);
        }
        for item in context
            .trying_foods
            .into_iter()
            .chain(context.usual_treats)
            .chain(context.usual_nutritions)
        {
            known_food_item_ids.insert(item.food_item_id);
        }
        for feeding in context.recent_feeding_events {
            if let Some(food_item_id) = feeding.food_item_id {
                known_food_item_ids.insert(food_item_id);
            }
        }

        let candidates = hints
            .hints
            .into_iter()
            .filter(|hint| dietary_hint_category(&hint.category))
            .filter(|hint| !known_food_item_ids.contains(&hint.item_id))
            .map(|hint| PetDietConfirmationCandidate {
                food_item_id: hint.item_id,
                food_name: hint.name.clone(),
                category: hint.category,
                candidate_kind: "possible_diet_change".to_owned(),
                fact_strength: "pending_confirmation".to_owned(),
                source_change_kind: hint.change_kind,
                source_question: format!(
                    "最近新增的「{}」，{}有吃过或正在换这款吗？",
                    hint.name, identity.identity.name
                ),
            })
            .collect();

        Ok(PetDietConfirmationCandidates { candidates })
    }

    /// 确认宠物饮食候选并写入事实
    pub async fn confirm_pet_diet_candidate(
        &self,
        input: ConfirmPetDietCandidateInput,
    ) -> PetResult<ConfirmPetDietCandidateResult> {
        self.ensure_pet_access(input.pet_id, input.confirmed_by_user_id)
            .await?;
        self.ensure_food_inventory_editor(input.food_item_id, input.confirmed_by_user_id)
            .await?;
        if !matches!(
            input.confirmed_fact_kind.as_str(),
            "current_staple" | "feeding_correction"
        ) {
            return Err(PetError::InvalidInput("暂不支持的饮食确认类型".to_owned()));
        }
        self.load_food_inventory_consumable_item(input.food_item_id, input.confirmed_by_user_id)
            .await?;

        let payload = AgentConfirmedFactPayload {
            confirmed_fact_kind: input.confirmed_fact_kind.clone(),
            linked_food_item_id: Some(input.food_item_id),
            linked_pet_id: Some(input.pet_id),
            confidence: "user_confirmed".to_owned(),
            source_question: input.source_question.clone(),
        };
        let event_payload = serde_json::to_value(payload).map_err(|error| {
            PetError::Infrastructure(format!(
                "failed to serialize agent confirmed fact payload: {error}"
            ))
        })?;
        let confirmed_event = self
            .repository
            .create_pet_event(NewPetEvent {
                pet_id: input.pet_id,
                actor_user_id: input.confirmed_by_user_id,
                event_kind: EventKind::Daily,
                event_subkind: Some("agent_confirmed_fact".to_owned()),
                title: "饮食事实已确认".to_owned(),
                summary: Some(input.source_question.clone()),
                visibility: EventVisibility::Private,
                event_payload,
                occurred_at: Utc::now(),
            })
            .await?;

        let assignment_id = if input.derive_diet_change {
            Some(
                self.set_current_staple(SetPetCurrentStapleInput {
                    pet_id: input.pet_id,
                    food_item_id: input.food_item_id,
                    created_by_user_id: input.confirmed_by_user_id,
                    reason: Some("Agent 追问后用户确认".to_owned()),
                })
                .await?
                .id,
            )
        } else {
            None
        };

        let correction_event_id = if input.derive_feeding_correction {
            let payload = FeedingCorrectionPayload {
                food_item_id: input.food_item_id,
                linked_pet_id: input.pet_id,
                confirmed_event_id: confirmed_event.id,
                source_question: input.source_question.clone(),
                corrected_by_user_id: input.confirmed_by_user_id,
            };
            let event_payload = serde_json::to_value(payload).map_err(|error| {
                PetError::Infrastructure(format!(
                    "failed to serialize feeding correction payload: {error}"
                ))
            })?;
            Some(
                self.repository
                    .create_pet_event(NewPetEvent {
                        pet_id: input.pet_id,
                        actor_user_id: input.confirmed_by_user_id,
                        event_kind: EventKind::Daily,
                        event_subkind: Some("feeding_correction".to_owned()),
                        title: "喂食记录已修正".to_owned(),
                        summary: Some(input.source_question.clone()),
                        visibility: EventVisibility::Private,
                        event_payload,
                        occurred_at: Utc::now(),
                    })
                    .await?
                    .id,
            )
        } else {
            None
        };

        Ok(ConfirmPetDietCandidateResult {
            confirmed_event_id: confirmed_event.id,
            assignment_id,
            correction_event_id,
        })
    }

    /// 加载 Agent 身份上下文（含授权校验）
    pub async fn load_identity_context(
        &self,
        user_id: Uuid,
        pet_id: Uuid,
    ) -> PetResult<PetIdentityContext> {
        self.repository.load_identity_context(pet_id, user_id).await
    }
}

fn dietary_hint_category(category: &str) -> bool {
    matches!(
        category,
        "main_food" | "wet_food" | "treats" | "nutrition" | "other"
    )
}

fn reject_direct_archived_status(status: FoodInventoryStatus) -> PetResult<()> {
    if status.is_archived() {
        Err(PetError::InvalidInput(
            "归档状态只能通过归档操作设置".to_owned(),
        ))
    } else {
        Ok(())
    }
}
