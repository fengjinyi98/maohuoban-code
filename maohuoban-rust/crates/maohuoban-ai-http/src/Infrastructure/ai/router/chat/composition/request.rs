use maohuoban_ai_domain::ai::AiConversationSurface;
use serde::Deserialize;
use uuid::Uuid;

/// ChatStreamRequest 流式聊天请求
/// 核心职责：
/// - 接收用户消息、入口上下文和会话 ID
/// - 不包含 actor_user_id，只从 token 注入
#[derive(Debug, Clone, Deserialize)]
pub(crate) struct ChatStreamRequest {
    pub message: String,
    #[serde(default)]
    pub selected_pet_id: Option<Uuid>,
    pub surface: AiConversationSurface,
    #[serde(default)]
    pub chat_session_id: Option<Uuid>,
    #[serde(default)]
    pub source_hint_id: Option<Uuid>,
    #[serde(default)]
    pub confirmation_task_id: Option<Uuid>,
    #[serde(default)]
    #[allow(dead_code)]
    pub client_message_id: Option<String>,
}
