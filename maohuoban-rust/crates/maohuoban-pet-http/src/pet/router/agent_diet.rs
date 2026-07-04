use axum::{
    Json,
    extract::{Path, State},
    response::Response,
};
use chrono::{Duration, Utc};
use maohuoban_auth_http::auth::extractor::AuthenticatedUser;
use maohuoban_pet_application::pet::ConfirmPetDietCandidateInput;
use maohuoban_pet_domain::pet::FoodScopeType;
use serde::Deserialize;
use uuid::Uuid;

use super::PetHttpState;
use crate::pet::response::{created_response, error_response, ok_response};

/// ConfirmPetDietCandidateRequest 确认饮食候选请求
/// 核心职责：
/// - 接收用户对 Agent 追问候选的确认
/// - 控制是否派生饮食配置变更
#[derive(Debug, Deserialize)]
pub(super) struct ConfirmPetDietCandidateRequest {
    food_item_id: Uuid,
    confirmed_fact_kind: String,
    source_question: String,
    derive_diet_change: bool,
    #[serde(default)]
    derive_feeding_correction: bool,
}

impl ConfirmPetDietCandidateRequest {
    fn into_input(self, pet_id: Uuid, confirmed_by_user_id: Uuid) -> ConfirmPetDietCandidateInput {
        ConfirmPetDietCandidateInput {
            pet_id,
            food_item_id: self.food_item_id,
            confirmed_by_user_id,
            confirmed_fact_kind: self.confirmed_fact_kind,
            source_question: self.source_question,
            derive_diet_change: self.derive_diet_change,
            derive_feeding_correction: self.derive_feeding_correction,
        }
    }
}

/// get_pet_current_diet_context 获取宠物当前饮食上下文（强事实）
pub(super) async fn get_pet_current_diet_context(
    State(state): State<PetHttpState>,
    Path(pet_id): Path<Uuid>,
    actor: AuthenticatedUser,
) -> Response {
    let actor_user_id = actor.user_id();

    match state
        .pet
        .load_pet_current_diet_context(actor_user_id, pet_id)
        .await
    {
        Ok(context) => ok_response("pet.diet_context_loaded", "宠物饮食上下文已加载", context),
        Err(error) => error_response(&error),
    }
}

/// get_pet_diet_trend_summary 获取宠物饮食趋势摘要
/// 核心职责：
/// - 为储物柜页面提供后端计算后的饮食趋势总览
/// - 保持前端只消费展示 DTO，不承载算法逻辑
pub(super) async fn get_pet_diet_trend_summary(
    State(state): State<PetHttpState>,
    Path(pet_id): Path<Uuid>,
    actor: AuthenticatedUser,
) -> Response {
    let owner_user_id = actor.user_id();

    match state
        .pet
        .load_pet_diet_trend_summary(owner_user_id, pet_id)
        .await
    {
        Ok(summary) => ok_response(
            "pet.diet_trend_summary_loaded",
            "饮食趋势摘要已加载",
            summary,
        ),
        Err(error) => error_response(&error),
    }
}

/// get_food_inventory_change_hints 获取近期储物柜变化线索（弱线索）
pub(super) async fn get_food_inventory_change_hints(
    State(state): State<PetHttpState>,
    actor: AuthenticatedUser,
) -> Response {
    let actor_user_id = actor.user_id();

    // 查询过去 30 天的变化线索
    let since = Utc::now() - Duration::days(30);

    match state
        .pet
        .load_food_inventory_change_hints(FoodScopeType::User, actor_user_id, since)
        .await
    {
        Ok(hints) => ok_response(
            "pet.food_inventory_hints_loaded",
            "储物柜变化线索已加载",
            hints,
        ),
        Err(error) => error_response(&error),
    }
}

/// get_pet_diet_confirmation_candidates 获取宠物饮食待确认候选
pub(super) async fn get_pet_diet_confirmation_candidates(
    State(state): State<PetHttpState>,
    Path(pet_id): Path<Uuid>,
    actor: AuthenticatedUser,
) -> Response {
    let actor_user_id = actor.user_id();

    match state
        .pet
        .load_pet_diet_confirmation_candidates(actor_user_id, pet_id)
        .await
    {
        Ok(candidates) => ok_response(
            "pet.diet_confirmation_candidates_loaded",
            "宠物饮食待确认候选已加载",
            candidates,
        ),
        Err(error) => error_response(&error),
    }
}

/// confirm_pet_diet_candidate 确认宠物饮食候选
pub(super) async fn confirm_pet_diet_candidate(
    State(state): State<PetHttpState>,
    Path(pet_id): Path<Uuid>,
    actor: AuthenticatedUser,
    Json(request): Json<ConfirmPetDietCandidateRequest>,
) -> Response {
    let actor_user_id = actor.user_id();

    match state
        .pet
        .confirm_pet_diet_candidate(request.into_input(pet_id, actor_user_id))
        .await
    {
        Ok(result) => created_response("pet.diet_candidate_confirmed", "饮食候选已确认", result),
        Err(error) => error_response(&error),
    }
}
