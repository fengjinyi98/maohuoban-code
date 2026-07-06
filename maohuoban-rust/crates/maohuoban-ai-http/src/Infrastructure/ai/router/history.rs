//! history AI 历史会话 HTTP handler
//! 核心职责：
//! - 返回当前用户 AI 会话列表
//! - 返回指定会话的消息详情
//! - 校验 session 归属当前 actor

use std::collections::HashMap;

use axum::{
    Json,
    extract::{Path, State},
    response::Response,
};
use chrono::{DateTime, Utc};
use maohuoban_ai_domain::ai::{
    AiChatSession, AiChatSessionContextStatus, AiCitation, AiCitationSourceKind, AiContentBlock,
    AiError, AiMessageRole, AiPetCandidate, AiPetDisplaySnapshot,
};
use maohuoban_auth_http::auth::extractor::AuthenticatedUser;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use super::AiHttpState;
use super::diagnostics::{
    record_history_messages_loaded, record_history_mutation_completed,
    record_history_sessions_loaded,
};
use crate::ai::response::{ai_error_response, ok_response, unauthorized_response};

/// ChatSessionItem 会话列表项
#[derive(Debug, Serialize)]
pub struct ChatSessionItem {
    pub id: Uuid,
    pub title: String,
    pub is_pinned: bool,
    pub chat_context_kind: Option<String>,
    pub context_status: String,
    pub abnormal_episode_id: Option<Uuid>,
    pub source_hint_id: Option<Uuid>,
    pub agent_followup_id: Option<Uuid>,
    pub subtitle: String,
    pub pet_display_snapshot: Option<PetDisplaySnapshotDTO>,
    pub last_message_preview: String,
    pub last_message_at: String,
}

/// SessionMutationResultDTO 会话操作结果 DTO
#[derive(Debug, Serialize)]
pub struct SessionMutationResultDTO {
    pub id: Uuid,
    pub title: String,
    pub is_pinned: bool,
}

/// ActivateAbnormalEpisodeSessionRequest 激活异常追踪会话请求
/// 核心职责：
/// - 接收轻提醒进入 AI 聊天时携带的 abnormal episode ID
/// - 由后端将后台追踪上下文升级为用户可见聊天
#[derive(Debug, Deserialize)]
pub struct ActivateAbnormalEpisodeSessionRequest {
    pub abnormal_episode_id: Uuid,
}

/// RenameChatSessionRequest 重命名会话请求
#[derive(Debug, Deserialize)]
pub struct RenameChatSessionRequest {
    pub title: String,
}

/// PinChatSessionRequest 置顶会话请求
#[derive(Debug, Deserialize)]
pub struct PinChatSessionRequest {
    pub is_pinned: bool,
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
    pub content_blocks: Vec<AiContentBlock>,
    pub citations: Vec<MessageCitationDTO>,
    pub created_at: String,
}

/// MessageCitationDTO 消息引用 DTO
/// 核心职责：
/// - 向历史消息返回可追溯来源类型、来源 ID 和展示标签
/// - 保持历史复看与实时 SSE 引用展示一致
#[derive(Debug, Serialize)]
pub struct MessageCitationDTO {
    pub source_kind: String,
    pub source_id: Uuid,
    pub label: String,
}

/// handle_list_sessions 获取会话列表
pub async fn handle_list_sessions(
    State(state): State<AiHttpState>,
    actor: AuthenticatedUser,
) -> Response {
    let actor_user_id = actor.user_id();

    let sessions = state
        .session_repository
        .list_sessions_by_actor(actor_user_id, 50)
        .await
        .unwrap_or_default();

    let pet_candidates_by_id = state
        .pet_resolver
        .list_authorized_candidates(actor_user_id)
        .await
        .unwrap_or_default()
        .into_iter()
        .map(|candidate| (candidate.pet_id, candidate))
        .collect::<HashMap<_, _>>();

    let mut items: Vec<ChatSessionItem> = Vec::new();
    for s in &sessions {
        items.push(session_item_with_pet_candidates(&state, s, &pet_candidates_by_id).await);
    }

    record_history_sessions_loaded(
        actor_user_id,
        items.len(),
        sessions.iter().filter(|session| session.is_pinned).count(),
        items
            .iter()
            .filter(|item| item.pet_display_snapshot.is_some())
            .count(),
        pet_candidates_by_id.len(),
    );
    ok_response("ai.sessions_loaded", "会话列表已加载", items)
}

/// handle_get_session_messages 获取会话消息详情
pub async fn handle_get_session_messages(
    State(state): State<AiHttpState>,
    actor: AuthenticatedUser,
    Path(session_id): Path<Uuid>,
) -> Response {
    let actor_user_id = actor.user_id();

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
    let citations_by_message = state
        .session_repository
        .list_citations_by_session(session_id)
        .await
        .unwrap_or_default();

    let dtos: Vec<MessageDTO> = messages
        .iter()
        .filter(|m| is_user_visible_role(m.role))
        .map(|m| MessageDTO {
            id: m.id,
            role: format!("{:?}", m.role).to_lowercase(),
            content: m.content.clone(),
            content_blocks: m.content_blocks.clone(),
            citations: citations_by_message
                .get(&m.id)
                .map(|citations| citations.iter().map(message_citation_dto).collect())
                .unwrap_or_default(),
            created_at: m.created_at.to_rfc3339(),
        })
        .collect();

    let _ = session;
    record_history_messages_loaded(actor_user_id, session_id, dtos.len());
    ok_response("ai.messages_loaded", "消息列表已加载", dtos)
}

/// handle_activate_abnormal_episode_session 激活异常追踪会话
/// 核心职责：
/// - 将当前用户的后台异常追踪 session 标记为 visible
/// - 返回同一个 session 的前端历史列表 DTO，供聊天页继续加载消息
pub async fn handle_activate_abnormal_episode_session(
    State(state): State<AiHttpState>,
    actor: AuthenticatedUser,
    Json(req): Json<ActivateAbnormalEpisodeSessionRequest>,
) -> Response {
    let actor_user_id = actor.user_id();
    let session = match state
        .session_repository
        .find_active_abnormal_episode_session(actor_user_id, req.abnormal_episode_id)
        .await
    {
        Ok(Some(session)) => session,
        Ok(None) => return unauthorized_response(),
        Err(error) => return ai_error_response(&error),
    };

    if let Err(error) = state
        .session_repository
        .activate_background_session(session.id, actor_user_id)
        .await
    {
        return ai_error_response(&error);
    }

    match state.session_repository.get_session(session.id).await {
        Ok(Some(session)) if session.actor_user_id == actor_user_id => ok_response(
            "ai.session_activated",
            "异常追踪会话已激活",
            session_item(&state, actor_user_id, session).await,
        ),
        Ok(_) => unauthorized_response(),
        Err(error) => ai_error_response(&error),
    }
}

/// handle_rename_session 重命名当前用户会话
pub async fn handle_rename_session(
    State(state): State<AiHttpState>,
    actor: AuthenticatedUser,
    Path(session_id): Path<Uuid>,
    Json(req): Json<RenameChatSessionRequest>,
) -> Response {
    let actor_user_id = actor.user_id();

    let title = req.title.trim();
    if title.is_empty() || title.chars().count() > 60 {
        record_history_mutation_completed("rename", actor_user_id, session_id, false);
        return ai_error_response(&AiError::InvalidInput(
            "会话标题长度需为 1-60 个字符".to_owned(),
        ));
    }

    match state
        .session_repository
        .rename_session(session_id, actor_user_id, title)
        .await
    {
        Ok(Some(session)) => {
            record_history_mutation_completed("rename", actor_user_id, session_id, true);
            ok_response(
                "ai.session_renamed",
                "会话已重命名",
                session_mutation_result(session),
            )
        }
        Ok(None) => {
            record_history_mutation_completed("rename", actor_user_id, session_id, false);
            unauthorized_response()
        }
        Err(error) => {
            record_history_mutation_completed("rename", actor_user_id, session_id, false);
            ai_error_response(&error)
        }
    }
}

/// handle_pin_session 更新当前用户会话置顶状态
pub async fn handle_pin_session(
    State(state): State<AiHttpState>,
    actor: AuthenticatedUser,
    Path(session_id): Path<Uuid>,
    Json(req): Json<PinChatSessionRequest>,
) -> Response {
    let actor_user_id = actor.user_id();

    match state
        .session_repository
        .set_session_pinned(session_id, actor_user_id, req.is_pinned)
        .await
    {
        Ok(Some(session)) => {
            record_history_mutation_completed("pin", actor_user_id, session_id, true);
            ok_response(
                "ai.session_pin_updated",
                "会话置顶状态已更新",
                session_mutation_result(session),
            )
        }
        Ok(None) => {
            record_history_mutation_completed("pin", actor_user_id, session_id, false);
            unauthorized_response()
        }
        Err(error) => {
            record_history_mutation_completed("pin", actor_user_id, session_id, false);
            ai_error_response(&error)
        }
    }
}

/// handle_delete_session 归档当前用户会话
pub async fn handle_delete_session(
    State(state): State<AiHttpState>,
    actor: AuthenticatedUser,
    Path(session_id): Path<Uuid>,
) -> Response {
    let actor_user_id = actor.user_id();

    match state
        .session_repository
        .archive_session(session_id, actor_user_id)
        .await
    {
        Ok(Some(session)) => {
            record_history_mutation_completed("delete", actor_user_id, session_id, true);
            ok_response(
                "ai.session_deleted",
                "会话已删除",
                session_mutation_result(session),
            )
        }
        Ok(None) => {
            record_history_mutation_completed("delete", actor_user_id, session_id, false);
            unauthorized_response()
        }
        Err(error) => {
            record_history_mutation_completed("delete", actor_user_id, session_id, false);
            ai_error_response(&error)
        }
    }
}

/// session_mutation_result 构造会话操作响应
/// 核心职责：
/// - 只暴露前端更新历史列表所需字段
/// - 避免 mutation 响应泄露完整会话内部状态
fn session_mutation_result(session: AiChatSession) -> SessionMutationResultDTO {
    SessionMutationResultDTO {
        id: session.id,
        title: session.title,
        is_pinned: session.is_pinned,
    }
}

async fn session_item(
    state: &AiHttpState,
    actor_user_id: Uuid,
    session: AiChatSession,
) -> ChatSessionItem {
    let pet_candidates_by_id = state
        .pet_resolver
        .list_authorized_candidates(actor_user_id)
        .await
        .unwrap_or_default()
        .into_iter()
        .map(|candidate| (candidate.pet_id, candidate))
        .collect::<HashMap<_, _>>();

    session_item_with_pet_candidates(state, &session, &pet_candidates_by_id).await
}

async fn session_item_with_pet_candidates(
    state: &AiHttpState,
    session: &AiChatSession,
    pet_candidates_by_id: &HashMap<Uuid, AiPetCandidate>,
) -> ChatSessionItem {
    let messages = state
        .session_repository
        .list_messages_by_session(session.id)
        .await
        .unwrap_or_default();

    let visible_messages: Vec<_> = messages
        .iter()
        .filter(|m| is_user_visible_role(m.role))
        .collect();
    let (last_preview, last_at) = if let Some(last) = visible_messages.last() {
        (
            last.content.chars().take(50).collect(),
            last.created_at.to_rfc3339(),
        )
    } else {
        (String::new(), session.updated_at.to_rfc3339())
    };

    ChatSessionItem {
        id: session.id,
        title: session.title.clone(),
        is_pinned: session.is_pinned,
        chat_context_kind: session.chat_context_kind.clone(),
        context_status: context_status_code(session.context_status).to_owned(),
        abnormal_episode_id: session.abnormal_episode_id,
        source_hint_id: session.source_hint_id,
        agent_followup_id: session.agent_followup_id,
        subtitle: format_subtitle(session.updated_at),
        pet_display_snapshot: history_pet_snapshot(
            session.pet_display_snapshot.as_ref(),
            session.primary_pet_id,
            pet_candidates_by_id,
        )
        .map(pet_snapshot_dto),
        last_message_preview: last_preview,
        last_message_at: last_at,
    }
}

/// context_status_code 返回上下文状态编码
/// 核心职责：
/// - 向历史列表暴露稳定 snake_case 字段
/// - 让前端区分聊天记录与异常上下文生命周期
fn context_status_code(status: AiChatSessionContextStatus) -> &'static str {
    match status {
        AiChatSessionContextStatus::Active => "active",
        AiChatSessionContextStatus::Deleted => "deleted",
        AiChatSessionContextStatus::Closed => "closed",
    }
}

fn message_citation_dto(citation: &AiCitation) -> MessageCitationDTO {
    MessageCitationDTO {
        source_kind: citation_source_kind_code(citation.source_kind).to_owned(),
        source_id: citation.source_id,
        label: citation.label.clone(),
    }
}

fn citation_source_kind_code(kind: AiCitationSourceKind) -> &'static str {
    match kind {
        AiCitationSourceKind::PetEvent => "pet_event",
        AiCitationSourceKind::DietAssignment => "diet_assignment",
        AiCitationSourceKind::FoodInventoryHint => "food_inventory_hint",
        AiCitationSourceKind::AttentionHint => "attention_hint",
        AiCitationSourceKind::ConfirmationTask => "confirmation_task",
        AiCitationSourceKind::AbnormalEpisode => "abnormal_episode",
    }
}

/// history_pet_snapshot 构造历史列表宠物快照
/// 核心职责：
/// - 保留会话创建时已持久化的宠物展示快照
/// - 对旧数据缺失的头像字段使用当前授权宠物档案补齐
fn history_pet_snapshot(
    snapshot: Option<&AiPetDisplaySnapshot>,
    primary_pet_id: Option<Uuid>,
    pet_candidates_by_id: &HashMap<Uuid, AiPetCandidate>,
) -> Option<AiPetDisplaySnapshot> {
    let candidate = primary_pet_id.and_then(|pet_id| pet_candidates_by_id.get(&pet_id));

    match (snapshot, candidate) {
        (Some(snapshot), Some(candidate)) => {
            let mut snapshot = snapshot.clone();
            if is_missing_url(snapshot.pet_avatar_url.as_deref()) {
                snapshot.pet_avatar_url.clone_from(&candidate.avatar_url);
            }
            if snapshot.pet_name.is_empty() {
                snapshot.pet_name.clone_from(&candidate.name);
            }
            if snapshot.pet_species.is_empty() {
                snapshot.pet_species.clone_from(&candidate.species);
            }
            if snapshot.profile_number.is_empty() {
                snapshot
                    .profile_number
                    .clone_from(&candidate.profile_number);
            }
            Some(snapshot)
        }
        (Some(snapshot), None) => Some(snapshot.clone()),
        (None, Some(candidate)) => Some(AiPetDisplaySnapshot::from(candidate)),
        (None, None) => None,
    }
}

/// is_missing_url 判断展示 URL 是否缺失
/// 核心职责：
/// - 统一处理 null、空串和纯空白字符串
/// - 避免历史 DTO 输出无效头像地址
fn is_missing_url(value: Option<&str>) -> bool {
    value.is_none_or(|value| value.trim().is_empty())
}

/// is_user_visible_role 判断历史接口可返回的消息角色
/// 核心职责：
/// - 仅让用户与助手消息进入前端聊天历史
/// - 将后台 planning system 消息保留在数据库审计层
fn is_user_visible_role(role: AiMessageRole) -> bool {
    matches!(role, AiMessageRole::User | AiMessageRole::Assistant)
}

/// pet_snapshot_dto 转换宠物快照 DTO
/// 核心职责：
/// - 隔离 domain 快照与 HTTP 响应结构
/// - 保持历史列表字段命名稳定
fn pet_snapshot_dto(snapshot: AiPetDisplaySnapshot) -> PetDisplaySnapshotDTO {
    PetDisplaySnapshotDTO {
        pet_id: snapshot.pet_id,
        pet_name: snapshot.pet_name,
        pet_avatar_url: snapshot.pet_avatar_url,
        pet_species: snapshot.pet_species,
        profile_number: snapshot.profile_number,
    }
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
