//! history AI 历史会话 HTTP handler
//! 核心职责：
//! - 返回当前用户 AI 会话列表
//! - 返回指定会话的消息详情
//! - 校验 session 归属当前 actor

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    response::Response,
};
use chrono::{DateTime, Utc};
use serde::Serialize;
use uuid::Uuid;

use super::AiHttpState;
use super::auth::current_user_id;
use crate::ai::response::{ok_response, unauthorized_response};

/// ChatSessionItem 会话列表项
#[derive(Debug, Serialize)]
pub struct ChatSessionItem {
    pub id: Uuid,
    pub title: String,
    pub subtitle: String,
    pub pet_display_snapshot: Option<PetDisplaySnapshotDTO>,
    pub last_message_preview: String,
    pub last_message_at: String,
}

/// PetDisplaySnapshotDTO 宠物展示快照 DTO
#[derive(Debug, Serialize)]
pub struct PetDisplaySnapshotDTO {
    pub pet_id: Uuid,
    pub pet_name: String,
    pub pet_avatar_url: Option<String>,
    pub pet_species: String,
    pub profile_number: String,
}

/// MessageDTO 消息 DTO
#[derive(Debug, Serialize)]
pub struct MessageDTO {
    pub id: Uuid,
    pub role: String,
    pub content: String,
    pub created_at: String,
}

/// handle_list_sessions 获取会话列表
pub async fn handle_list_sessions(
    State(state): State<AiHttpState>,
    headers: HeaderMap,
) -> Response {
    let Ok(actor_user_id) = current_user_id(&state.auth, &headers).await else {
        return unauthorized_response();
    };

    let sessions = state
        .session_repository
        .list_sessions_by_actor(actor_user_id, 50)
        .await
        .unwrap_or_default();

    let mut items: Vec<ChatSessionItem> = Vec::new();
    for s in &sessions {
        let messages = state
            .session_repository
            .list_messages_by_session(s.id)
            .await
            .unwrap_or_default();

        let (last_preview, last_at) = if let Some(last) = messages.last() {
            (
                last.content.chars().take(50).collect(),
                last.created_at.to_rfc3339(),
            )
        } else {
            (String::new(), s.updated_at.to_rfc3339())
        };

        items.push(ChatSessionItem {
            id: s.id,
            title: s.title.clone(),
            subtitle: format_subtitle(s.updated_at),
            pet_display_snapshot: s
                .pet_display_snapshot
                .as_ref()
                .map(|p| PetDisplaySnapshotDTO {
                    pet_id: p.pet_id,
                    pet_name: p.pet_name.clone(),
                    pet_avatar_url: p.pet_avatar_url.clone(),
                    pet_species: p.pet_species.clone(),
                    profile_number: p.profile_number.clone(),
                }),
            last_message_preview: last_preview,
            last_message_at: last_at,
        });
    }

    ok_response("ai.sessions_loaded", "会话列表已加载", items)
}

/// handle_get_session_messages 获取会话消息详情
pub async fn handle_get_session_messages(
    State(state): State<AiHttpState>,
    headers: HeaderMap,
    Path(session_id): Path<Uuid>,
) -> Response {
    let Ok(actor_user_id) = current_user_id(&state.auth, &headers).await else {
        return unauthorized_response();
    };

    // 校验 session 归属
    let session = match state.session_repository.get_session(session_id).await {
        Ok(Some(s)) if s.actor_user_id == actor_user_id => s,
        _ => {
            return unauthorized_response();
        }
    };

    let messages = state
        .session_repository
        .list_messages_by_session(session_id)
        .await
        .unwrap_or_default();

    let dtos: Vec<MessageDTO> = messages
        .iter()
        .map(|m| MessageDTO {
            id: m.id,
            role: format!("{:?}", m.role).to_lowercase(),
            content: m.content.clone(),
            created_at: m.created_at.to_rfc3339(),
        })
        .collect();

    let _ = session;
    ok_response("ai.messages_loaded", "消息列表已加载", dtos)
}

/// format_subtitle 格式化时间显示
fn format_subtitle(dt: DateTime<Utc>) -> String {
    let now = Utc::now();
    let diff = now.signed_duration_since(dt);
    if diff.num_hours() < 1 {
        "刚刚".to_owned()
    } else if diff.num_hours() < 24 {
        format!("{}小时前", diff.num_hours())
    } else if diff.num_days() == 1 {
        "昨天".to_owned()
    } else if diff.num_days() < 7 {
        format!("{}天前", diff.num_days())
    } else {
        dt.format("%Y-%m-%d").to_string()
    }
}
