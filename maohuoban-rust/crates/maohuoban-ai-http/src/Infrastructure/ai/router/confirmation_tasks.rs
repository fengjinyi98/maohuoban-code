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

/// RejectConfirmationTaskResponse 取消确认任务响应
/// 核心职责：
/// - 向客户端返回被关闭的确认任务 ID
/// - 明确本次用户决策未产生宠物事件写入
#[derive(Debug, Serialize)]
pub struct RejectConfirmationTaskResponse {
    pub confirmation_task_id: Uuid,
    pub status: &'static str,
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

    let authorized = match state
        .pet_resolver
        .list_authorized_candidates(actor_user_id)
        .await
    {
        Ok(candidates) => candidates
            .iter()
            .any(|candidate| candidate.pet_id == task.pet_id),
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
        RejectConfirmationTaskResponse {
            confirmation_task_id,
            status: "dismissed",
        },
    )
}
