// MHB_STRUCTURE_EXEMPTION: Phase2 既有路由模块将在 code-structure P1 中按 handler 拆分；本次只补当前主粮契约校验。
use axum::{
    Json,
    extract::{Path, State},
    http::HeaderMap,
    response::Response,
};
use maohuoban_pet_domain::pet::{DietAssignmentRole, PetError};
use uuid::Uuid;

use super::{PetHttpState, auth::current_user_id};
use crate::pet::{
    dto::{SetPetCurrentStapleRequest, SetPetDietAssignmentRequest},
    response::{created_response, error_response, ok_response, unauthorized_response},
};

/// set_pet_current_staple 设为当前主粮
pub(super) async fn set_pet_current_staple(
    State(state): State<PetHttpState>,
    headers: HeaderMap,
    Path(pet_id): Path<Uuid>,
    Json(request): Json<SetPetCurrentStapleRequest>,
) -> Response {
    let Ok(created_by_user_id) = current_user_id(&state.auth, &headers).await else {
        return unauthorized_response();
    };

    let input = request.into_input(pet_id, created_by_user_id);

    match state.pet.set_current_staple(input).await {
        Ok(assignment) => created_response("pet.current_staple_set", "当前主粮已设置", assignment),
        Err(error) => error_response(&error),
    }
}

/// set_pet_diet_assignment 设置饮食配置
pub(super) async fn set_pet_diet_assignment(
    State(state): State<PetHttpState>,
    headers: HeaderMap,
    Path(pet_id): Path<Uuid>,
    Json(request): Json<SetPetDietAssignmentRequest>,
) -> Response {
    let Ok(created_by_user_id) = current_user_id(&state.auth, &headers).await else {
        return unauthorized_response();
    };

    let input = request.into_input(pet_id, created_by_user_id);
    if matches!(input.role, DietAssignmentRole::CurrentStaple) {
        return error_response(&PetError::InvalidInput(
            "当前主粮必须通过当前主粮专用接口设置".to_owned(),
        ));
    }

    match state.pet.set_diet_assignment(input).await {
        Ok(assignment) => created_response("pet.diet_assignment_set", "饮食配置已设置", assignment),
        Err(error) => error_response(&error),
    }
}

/// list_active_diet_assignments 查询活跃饮食配置
pub(super) async fn list_active_diet_assignments(
    State(state): State<PetHttpState>,
    headers: HeaderMap,
    Path(pet_id): Path<Uuid>,
) -> Response {
    let Ok(actor_user_id) = current_user_id(&state.auth, &headers).await else {
        return unauthorized_response();
    };

    match state
        .pet
        .list_active_diet_assignments(pet_id, actor_user_id)
        .await
    {
        Ok(assignments) => ok_response(
            "pet.diet_assignments_listed",
            "饮食配置列表已加载",
            assignments,
        ),
        Err(error) => error_response(&error),
    }
}

/// end_diet_assignment 结束饮食配置
pub(super) async fn end_diet_assignment(
    State(state): State<PetHttpState>,
    headers: HeaderMap,
    Path((pet_id, assignment_id)): Path<(Uuid, Uuid)>,
) -> Response {
    let Ok(ended_by_user_id) = current_user_id(&state.auth, &headers).await else {
        return unauthorized_response();
    };

    match state
        .pet
        .end_diet_assignment(pet_id, assignment_id, ended_by_user_id)
        .await
    {
        Ok(assignment) => ok_response("pet.diet_assignment_ended", "饮食配置已结束", assignment),
        Err(error) => error_response(&error),
    }
}
