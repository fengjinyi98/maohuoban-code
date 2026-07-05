use std::{collections::HashSet, sync::Arc};

use chrono::{Duration, Utc};
use maohuoban_pet_domain::pet::{
    AgentConfirmedFactPayload, DietAssignmentRole, DietChangePayload,
    DietInventoryAttentionCandidate, DietInventoryConsumptionCycleSample,
    DietInventoryCycleCheckSample, DietTrendFeedingSample, EventKind, EventVisibility,
    FeedingCorrectionPayload, FoodScopeType, PetDietAssignment, PetError, PetEvent,
    PetIdentityContext, PetResult, build_diet_inventory_attention_candidates,
    build_diet_trend_summary,
};
use uuid::Uuid;

use super::super::{
    ConfirmPetDietCandidateInput, ConfirmPetDietCandidateResult, DietRepository,
    FoodInventoryChangeHints, FoodInventoryConsumptionCycle, FoodInventoryRepository, NewPetEvent,
    PetCurrentDietContext, PetDietConfirmationCandidate, PetDietConfirmationCandidates,
    PetDietTrendSummary, PetRepository, SetPetCurrentStapleInput, SetPetDietAssignmentInput,
};
use super::food_inventory;

/// 确保用户有权访问宠物
async fn ensure_pet_access(
    repository: &Arc<dyn PetRepository>,
    pet_id: Uuid,
    user_id: Uuid,
) -> PetResult<()> {
    repository
        .authorize_pet_access(pet_id, user_id)
        .await?
        .map(|_| ())
        .ok_or(PetError::PetNotFound)
}

/// 设为当前主粮
pub(super) async fn set_current_staple(
    repository: &Arc<dyn PetRepository>,
    diet: &Arc<dyn DietRepository>,
    food_inventory: &Arc<dyn FoodInventoryRepository>,
    input: SetPetCurrentStapleInput,
) -> PetResult<PetDietAssignment> {
    ensure_pet_access(repository, input.pet_id, input.created_by_user_id).await?;
    food_inventory::load_food_inventory_consumable_item(
        food_inventory,
        input.food_item_id,
        input.created_by_user_id,
    )
    .await?;
    let previous = diet.find_current_staple(input.pet_id).await?;
    let pet_id = input.pet_id;
    let food_item_id = input.food_item_id;
    let created_by_user_id = input.created_by_user_id;
    let reason = input.reason.clone();
    let assignment = diet.set_current_staple(input).await?;
    let payload = DietChangePayload {
        from_food_item_id: previous.map(|a| a.food_item_id),
        to_food_item_id: food_item_id,
        assignment_id: assignment.id,
        transition_state: "started".to_owned(),
        started_at: assignment.started_at,
        confirmed_by_user_id: created_by_user_id,
    };
    let event_payload = serde_json::to_value(payload).map_err(|error| {
        PetError::Infrastructure(format!("failed to serialize diet change payload: {error}"))
    })?;
    repository
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

/// 设置饮食配置（尝试中、常用零食/营养品、禁用/不适合）
pub(super) async fn set_diet_assignment(
    repository: &Arc<dyn PetRepository>,
    diet: &Arc<dyn DietRepository>,
    food_inventory: &Arc<dyn FoodInventoryRepository>,
    input: SetPetDietAssignmentInput,
) -> PetResult<PetDietAssignment> {
    if matches!(input.role, DietAssignmentRole::CurrentStaple) {
        return Err(PetError::InvalidInput(
            "当前主粮必须通过当前主粮专用接口设置".to_owned(),
        ));
    }
    ensure_pet_access(repository, input.pet_id, input.created_by_user_id).await?;
    food_inventory::load_food_inventory_consumable_item(
        food_inventory,
        input.food_item_id,
        input.created_by_user_id,
    )
    .await?;
    diet.set_assignment(input).await
}

/// 结束饮食配置
pub(super) async fn end_diet_assignment(
    repository: &Arc<dyn PetRepository>,
    diet: &Arc<dyn DietRepository>,
    pet_id: Uuid,
    assignment_id: Uuid,
    ended_by_user_id: Uuid,
) -> PetResult<PetDietAssignment> {
    ensure_pet_access(repository, pet_id, ended_by_user_id).await?;
    diet.end_assignment(pet_id, assignment_id, ended_by_user_id)
        .await
}

/// 列出活跃饮食配置
pub(super) async fn list_active_diet_assignments(
    repository: &Arc<dyn PetRepository>,
    diet: &Arc<dyn DietRepository>,
    pet_id: Uuid,
    actor_user_id: Uuid,
) -> PetResult<Vec<PetDietAssignment>> {
    ensure_pet_access(repository, pet_id, actor_user_id).await?;
    diet.list_active_assignments(pet_id).await
}

/// 查找当前主粮
pub(super) async fn find_current_staple(
    diet: &Arc<dyn DietRepository>,
    pet_id: Uuid,
) -> PetResult<Option<PetDietAssignment>> {
    diet.find_current_staple(pet_id).await
}

/// 加载 Agent 饮食上下文（强事实）
pub(super) async fn load_pet_current_diet_context(
    repository: &Arc<dyn PetRepository>,
    diet: &Arc<dyn DietRepository>,
    owner_user_id: Uuid,
    pet_id: Uuid,
) -> PetResult<PetCurrentDietContext> {
    ensure_pet_access(repository, pet_id, owner_user_id).await?;
    diet.load_pet_current_diet_context(pet_id).await
}

/// 加载宠物饮食趋势摘要
pub(super) async fn load_pet_diet_trend_summary(
    repository: &Arc<dyn PetRepository>,
    diet: &Arc<dyn DietRepository>,
    owner_user_id: Uuid,
    pet_id: Uuid,
) -> PetResult<PetDietTrendSummary> {
    ensure_pet_access(repository, pet_id, owner_user_id).await?;
    let window_days = 60;
    let samples = diet
        .load_diet_trend_feeding_samples(pet_id, Utc::now() - Duration::days(window_days))
        .await?;
    Ok(build_diet_trend_summary(&samples, window_days))
}

/// 加载宠物饮食趋势喂食样本
/// 核心职责：
/// - 校验宠物访问权限
/// - 为首页轻提醒和饮食分析提供统一饮食事实来源
pub(super) async fn load_pet_diet_trend_feeding_samples(
    repository: &Arc<dyn PetRepository>,
    diet: &Arc<dyn DietRepository>,
    owner_user_id: Uuid,
    pet_id: Uuid,
    window_days: i64,
) -> PetResult<Vec<DietTrendFeedingSample>> {
    ensure_pet_access(repository, pet_id, owner_user_id).await?;
    diet.load_diet_trend_feeding_samples(pet_id, Utc::now() - Duration::days(window_days))
        .await
}

/// 加载饮食库存提醒候选
/// 核心职责：
/// - 汇总喂食样本、食品库存和已确认消耗周期
/// - 输出饮食算法层提醒候选，供首页映射展示
pub(super) async fn load_diet_inventory_attention_candidates(
    repository: &Arc<dyn PetRepository>,
    diet: &Arc<dyn DietRepository>,
    food_inventory: &Arc<dyn FoodInventoryRepository>,
    owner_user_id: Uuid,
    pet_id: Uuid,
    window_days: i64,
) -> PetResult<Vec<DietInventoryAttentionCandidate>> {
    ensure_pet_access(repository, pet_id, owner_user_id).await?;
    let samples = diet
        .load_diet_trend_feeding_samples(pet_id, Utc::now() - Duration::days(window_days))
        .await?;
    let items = food_inventory
        .list_items(FoodScopeType::User, owner_user_id, None, None)
        .await?;
    let cycles = food_inventory
        .list_consumption_cycles(FoodScopeType::User, owner_user_id)
        .await?;
    let cycle_checks = food_inventory
        .list_cycle_still_using_checks(FoodScopeType::User, owner_user_id)
        .await?;
    let cycle_samples = cycles
        .iter()
        .map(cycle_sample_from_consumption_cycle)
        .collect::<Vec<_>>();
    let check_samples = cycle_checks
        .into_iter()
        .map(|(food_item_id, checked_at)| DietInventoryCycleCheckSample {
            food_item_id,
            checked_at,
        })
        .collect::<Vec<_>>();
    Ok(build_diet_inventory_attention_candidates(
        &items,
        &samples,
        &cycle_samples,
        &check_samples,
    ))
}

fn cycle_sample_from_consumption_cycle(
    cycle: &FoodInventoryConsumptionCycle,
) -> DietInventoryConsumptionCycleSample {
    DietInventoryConsumptionCycleSample {
        food_item_id: cycle.food_item_id,
        package_weight_grams: cycle.package_weight_grams,
        confirmed_at: cycle.confirmed_at,
    }
}

/// 加载储物柜变化线索（弱线索）
pub(super) async fn load_food_inventory_change_hints(
    diet: &Arc<dyn DietRepository>,
    scope_type: FoodScopeType,
    scope_id: Uuid,
    since: chrono::DateTime<chrono::Utc>,
) -> PetResult<FoodInventoryChangeHints> {
    diet.load_food_inventory_change_hints(scope_type, scope_id, since)
        .await
}

/// 加载宠物饮食待确认候选
pub(super) async fn load_pet_diet_confirmation_candidates(
    repository: &Arc<dyn PetRepository>,
    diet: &Arc<dyn DietRepository>,
    owner_user_id: Uuid,
    pet_id: Uuid,
) -> PetResult<PetDietConfirmationCandidates> {
    ensure_pet_access(repository, pet_id, owner_user_id).await?;
    let identity = repository
        .load_identity_context(pet_id, owner_user_id)
        .await?;
    let context = diet.load_pet_current_diet_context(pet_id).await?;
    let hints = diet
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

/// 创建饮食确认事件
async fn create_confirmed_event(
    repository: &Arc<dyn PetRepository>,
    input: &ConfirmPetDietCandidateInput,
) -> PetResult<PetEvent> {
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
    repository
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
        .await
}

/// 创建喂食修正事件
async fn create_feeding_correction_event(
    repository: &Arc<dyn PetRepository>,
    input: &ConfirmPetDietCandidateInput,
    confirmed_event_id: Uuid,
) -> PetResult<Uuid> {
    let payload = FeedingCorrectionPayload {
        food_item_id: input.food_item_id,
        linked_pet_id: input.pet_id,
        confirmed_event_id,
        source_question: input.source_question.clone(),
        corrected_by_user_id: input.confirmed_by_user_id,
    };
    let event_payload = serde_json::to_value(payload).map_err(|error| {
        PetError::Infrastructure(format!(
            "failed to serialize feeding correction payload: {error}"
        ))
    })?;
    let event = repository
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
        .await?;
    Ok(event.id)
}

/// 确认宠物饮食候选并写入事实
pub(super) async fn confirm_pet_diet_candidate(
    repository: &Arc<dyn PetRepository>,
    diet: &Arc<dyn DietRepository>,
    food_inventory: &Arc<dyn FoodInventoryRepository>,
    input: ConfirmPetDietCandidateInput,
) -> PetResult<ConfirmPetDietCandidateResult> {
    ensure_pet_access(repository, input.pet_id, input.confirmed_by_user_id).await?;
    food_inventory::ensure_food_inventory_editor(
        food_inventory,
        input.food_item_id,
        input.confirmed_by_user_id,
    )
    .await?;
    if !matches!(
        input.confirmed_fact_kind.as_str(),
        "current_staple" | "feeding_correction"
    ) {
        return Err(PetError::InvalidInput("暂不支持的饮食确认类型".to_owned()));
    }
    food_inventory::load_food_inventory_consumable_item(
        food_inventory,
        input.food_item_id,
        input.confirmed_by_user_id,
    )
    .await?;

    let confirmed_event = create_confirmed_event(repository, &input).await?;

    let assignment_id = if input.derive_diet_change {
        Some(
            set_current_staple(
                repository,
                diet,
                food_inventory,
                SetPetCurrentStapleInput {
                    pet_id: input.pet_id,
                    food_item_id: input.food_item_id,
                    created_by_user_id: input.confirmed_by_user_id,
                    reason: Some("Agent 追问后用户确认".to_owned()),
                },
            )
            .await?
            .id,
        )
    } else {
        None
    };

    let correction_event_id = if input.derive_feeding_correction {
        Some(create_feeding_correction_event(repository, &input, confirmed_event.id).await?)
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
pub(super) async fn load_identity_context(
    repository: &Arc<dyn PetRepository>,
    user_id: Uuid,
    pet_id: Uuid,
) -> PetResult<PetIdentityContext> {
    repository.load_identity_context(pet_id, user_id).await
}

fn dietary_hint_category(category: &str) -> bool {
    matches!(
        category,
        "main_food" | "wet_food" | "treats" | "nutrition" | "other"
    )
}
