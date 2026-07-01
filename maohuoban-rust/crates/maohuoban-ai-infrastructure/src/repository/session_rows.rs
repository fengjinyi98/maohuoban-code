//! session_rows AI 会话仓储行映射
//! 核心职责：
//! - 隔离 SQL 查询行结构与 domain 模型转换
//! - 让 PostgresAiSessionRepository 聚焦仓储命令编排

use chrono::Utc;
use maohuoban_ai_domain::ai::{
    AiChatSession, AiChatSessionStatus, AiContentBlock, AiConversationSurface, AiMessage,
    AiMessageRole, AiMessageStatus, AiPetDisplaySnapshot,
};
use uuid::Uuid;

/// SessionRow AI 会话查询行
/// 核心职责：
/// - 承载 ai_chat_sessions 查询字段
/// - 转换为领域会话模型
#[derive(sqlx::FromRow)]
pub(super) struct SessionRow {
    id: Uuid,
    actor_user_id: Uuid,
    primary_pet_id: Option<Uuid>,
    surface: String,
    source_hint_id: Option<Uuid>,
    source_task_id: Option<Uuid>,
    title: String,
    is_pinned: bool,
    pet_display_snapshot: Option<serde_json::Value>,
    status: String,
    created_at: chrono::DateTime<Utc>,
    updated_at: chrono::DateTime<Utc>,
}

impl From<SessionRow> for AiChatSession {
    fn from(row: SessionRow) -> Self {
        let surface = match row.surface.as_str() {
            "pet_profile" => AiConversationSurface::PetProfile,
            "abnormal_detail" => AiConversationSurface::AbnormalDetail,
            "confirmation_task" => AiConversationSurface::ConfirmationTask,
            "ugc_comment" => AiConversationSurface::UgcComment,
            _ => AiConversationSurface::HomePrivate,
        };

        let status = match row.status.as_str() {
            "archived" => AiChatSessionStatus::Archived,
            _ => AiChatSessionStatus::Active,
        };

        let pet_display_snapshot = row
            .pet_display_snapshot
            .and_then(|value| serde_json::from_value::<AiPetDisplaySnapshot>(value).ok());

        Self {
            id: row.id,
            actor_user_id: row.actor_user_id,
            primary_pet_id: row.primary_pet_id,
            surface,
            source_hint_id: row.source_hint_id,
            source_task_id: row.source_task_id,
            title: row.title,
            is_pinned: row.is_pinned,
            pet_display_snapshot,
            status,
            created_at: row.created_at,
            updated_at: row.updated_at,
        }
    }
}

/// MessageRow AI 消息查询行
/// 核心职责：
/// - 承载 ai_messages 查询字段
/// - 转换为领域消息模型
#[derive(sqlx::FromRow)]
pub(super) struct MessageRow {
    id: Uuid,
    session_id: Uuid,
    turn_id: Option<Uuid>,
    role: String,
    content: String,
    content_blocks: serde_json::Value,
    status: String,
    citations: serde_json::Value,
    model: Option<String>,
    provider: Option<String>,
    finish_reason: Option<String>,
    usage_input_tokens: Option<i32>,
    usage_output_tokens: Option<i32>,
    verification: Option<serde_json::Value>,
    created_at: chrono::DateTime<Utc>,
}

impl From<MessageRow> for AiMessage {
    fn from(row: MessageRow) -> Self {
        let role = match row.role.as_str() {
            "assistant" => AiMessageRole::Assistant,
            "system" => AiMessageRole::System,
            _ => AiMessageRole::User,
        };

        let status = match row.status.as_str() {
            "streaming" => AiMessageStatus::Streaming,
            "failed" => AiMessageStatus::Failed,
            _ => AiMessageStatus::Completed,
        };

        let citations: Vec<Uuid> = row
            .citations
            .as_array()
            .map(|arr| {
                arr.iter()
                    .filter_map(|value| value.as_str().and_then(|s| Uuid::parse_str(s).ok()))
                    .collect()
            })
            .unwrap_or_default();

        let verification = row
            .verification
            .and_then(|value| serde_json::from_value(value).ok());
        let content_blocks =
            serde_json::from_value::<Vec<AiContentBlock>>(row.content_blocks).unwrap_or_default();

        Self {
            id: row.id,
            session_id: row.session_id,
            turn_id: row.turn_id,
            role,
            content: row.content,
            content_blocks,
            status,
            citations,
            model: row.model,
            provider: row.provider,
            finish_reason: row.finish_reason,
            usage_input_tokens: row.usage_input_tokens.map(|tokens| tokens as u32),
            usage_output_tokens: row.usage_output_tokens.map(|tokens| tokens as u32),
            verification,
            created_at: row.created_at,
        }
    }
}
