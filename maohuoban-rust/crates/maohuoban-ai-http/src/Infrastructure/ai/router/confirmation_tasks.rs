//! confirmation_tasks AI 确认任务 HTTP handler
//! 核心职责：
//! - 承载用户对 Agent 写入确认任务的显式操作
//! - 校验确认任务所属宠物仍在当前用户授权范围内

use axum::{
    extract::{Path, State},
    response::Response,
};
use maohuoban_ai_domain::ai::AiError;
use maohuoban_auth_http::auth::extractor::AuthenticatedUser;
use maohuoban_pet_domain::pet::ConfirmationTaskStatus;
use serde::Serialize;
use serde_json::json;
use uuid::Uuid;

use super::AiHttpState;
use crate::ai::response::{ai_error_response, ok_response};

/// ConfirmationTaskMutationResponse 确认任务变更响应
/// 核心职责：
/// - 向客户端返回被处理的确认任务 ID
/// - 明确确认任务当前状态
#[derive(Debug, Serialize)]
pub struct ConfirmationTaskMutationResponse {
    pub confirmation_task_id: Uuid,
    pub status: &'static str,
}

/// handle_approve_confirmation_task 确认写入任务
/// 核心职责：
/// - 把用户点击确认建模为授权命令
/// - 直接提交确认任务关联的观察记录，不创建聊天消息
pub async fn handle_approve_confirmation_task(
    State(state): State<AiHttpState>,
    actor: AuthenticatedUser,
    Path(confirmation_task_id): Path<Uuid>,
) -> Response {
    let actor_user_id = actor.user_id();
    let Ok(task) = state
        .confirmation_task_repository
        .get_by_id(confirmation_task_id)
        .await
    else {
        return ai_error_response(&AiError::NotFound("confirmation task".to_owned()));
    };

    let authorized = match is_authorized_for_task(&state, actor_user_id, task.pet_id).await {
        Ok(authorized) => authorized,
        Err(error) => return ai_error_response(&error),
    };
    if !authorized {
        return ai_error_response(&AiError::Unauthorized);
    }
    if task.status != ConfirmationTaskStatus::Pending {
        return ai_error_response(&AiError::Conflict(
            "confirmation task is not pending".to_owned(),
        ));
    }

    if let Err(error) = state
        .observation_write_provider
        .commit_observation_write(actor_user_id, task.pet_id, confirmation_task_id)
        .await
    {
        return ai_error_response(&AiError::Infrastructure(error.to_string()));
    }

    ok_response(
        "ai.confirmation_task_approved",
        "已写入这条观察",
        ConfirmationTaskMutationResponse {
            confirmation_task_id,
            status: "answered",
        },
    )
}

/// handle_reject_confirmation_task 取消确认任务
/// 核心职责：
/// - 将 pending 确认任务标记为 dismissed
/// - 只关闭确认任务，不写入 pet_events
pub async fn handle_reject_confirmation_task(
    State(state): State<AiHttpState>,
    actor: AuthenticatedUser,
    Path(confirmation_task_id): Path<Uuid>,
) -> Response {
    let actor_user_id = actor.user_id();
    let Ok(task) = state
        .confirmation_task_repository
        .get_by_id(confirmation_task_id)
        .await
    else {
        return ai_error_response(&AiError::NotFound("confirmation task".to_owned()));
    };

    let authorized = match is_authorized_for_task(&state, actor_user_id, task.pet_id).await {
        Ok(authorized) => authorized,
        Err(error) => return ai_error_response(&error),
    };
    if !authorized {
        return ai_error_response(&AiError::Unauthorized);
    }
    if task.status != ConfirmationTaskStatus::Pending {
        return ai_error_response(&AiError::Conflict(
            "confirmation task is not pending".to_owned(),
        ));
    }

    if let Err(error) = state
        .confirmation_task_repository
        .update_status(
            confirmation_task_id,
            "dismissed",
            Some(json!({"decision": "reject"})),
            None,
        )
        .await
    {
        return ai_error_response(&AiError::Infrastructure(error.to_string()));
    }

    ok_response(
        "ai.confirmation_task_rejected",
        "已取消这条待确认记录",
        ConfirmationTaskMutationResponse {
            confirmation_task_id,
            status: "dismissed",
        },
    )
}

/// is_authorized_for_task 校验确认任务宠物授权
/// 核心职责：
/// - 确认当前用户仍可访问任务所属宠物
/// - 让 approve/reject 共享同一授权边界
async fn is_authorized_for_task(
    state: &AiHttpState,
    actor_user_id: Uuid,
    pet_id: Uuid,
) -> Result<bool, AiError> {
    state
        .pet_resolver
        .list_authorized_candidates(actor_user_id)
        .await
        .map(|candidates| {
            candidates
                .iter()
                .any(|candidate| candidate.pet_id == pet_id)
        })
}
