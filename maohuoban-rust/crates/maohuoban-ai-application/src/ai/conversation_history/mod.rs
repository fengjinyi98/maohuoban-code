//! conversation_history 同会话历史投影 pipeline
//! 核心职责：
//! - 从仓储加载当前会话最近消息窗口（含归属校验）
//! - 把持久化 AiMessage 投影成模型可见 RecentConversationEntry
//! - ContextBudgetPolicy 已迁移到 turn_context 模块

use std::sync::Arc;

use maohuoban_ai_domain::ai::{AiError, AiMessage, AiResult};
pub use maohuoban_ai_domain::ai::{RecentConversationEntry, RecentConversationPack};
use uuid::Uuid;

use crate::ai::ports::AiSessionRepository;

/// ConversationHistoryProjector 历史投影器
/// 核心职责：
/// - 把持久化 AiMessage 投影成模型可见 RecentConversationEntry
/// - 类型层面保证内部字段（provider、model、finish_reason、usage、verification）不进入历史
pub struct ConversationHistoryProjector;

impl ConversationHistoryProjector {
    /// new 构造历史投影器
    #[must_use]
    pub fn new() -> Self {
        Self
    }

    /// project_messages 把持久化消息列表投影成模型可见历史包
    /// 核心职责：
    /// - 只保留 role 和 content
    /// - 丢弃 provider、model、finish_reason、usage、verification、citations
    #[must_use]
    pub fn project_messages(&self, messages: &[AiMessage]) -> RecentConversationPack {
        RecentConversationPack {
            entries: messages.iter().map(Self::project_message).collect(),
        }
    }

    /// project_message 投影单条持久化消息
    fn project_message(msg: &AiMessage) -> RecentConversationEntry {
        RecentConversationEntry {
            role: msg.role,
            content: msg.content.clone(),
            tool_call_id: None,
            tool_calls: Vec::new(),
        }
    }
}

impl Default for ConversationHistoryProjector {
    fn default() -> Self {
        Self::new()
    }
}

/// RecentConversationLoader 最近会话加载器
/// 核心职责：
/// - 校验会话归属后从仓储加载当前会话的最近消息窗口
/// - 排除当前轮用户消息（按 exclude_message_id）
/// - 投影成模型可见历史
pub struct RecentConversationLoader {
    repo: Arc<dyn AiSessionRepository>,
}

impl RecentConversationLoader {
    /// new 构造加载器
    #[must_use]
    pub fn new(repo: Arc<dyn AiSessionRepository>) -> Self {
        Self { repo }
    }

    /// load_recent_conversation 加载最近会话历史
    /// 核心职责：
    /// - 校验 session 归属当前 actor_user_id
    /// - 从仓储读取会话消息
    /// - 排除当前轮用户消息（按 exclude_message_id）
    /// - 投影成模型可见 RecentConversationPack
    pub async fn load_recent_conversation(
        &self,
        actor_user_id: Uuid,
        session_id: Uuid,
        exclude_message_id: Uuid,
        _context_length: u32,
        _token_budget: u32,
    ) -> AiResult<RecentConversationPack> {
        // 归属校验：session 必须归属当前用户
        let session = self.repo.get_session(session_id).await?;
        match session {
            None => {
                return Err(AiError::Infrastructure(format!(
                    "session {session_id} not found"
                )));
            }
            Some(s) if s.actor_user_id != actor_user_id => {
                return Err(AiError::Infrastructure(format!(
                    "session {session_id} does not belong to actor {actor_user_id}"
                )));
            }
            _ => {}
        }

        let messages = self.repo.list_messages_by_session(session_id).await?;

        // 排除当前轮用户消息
        let history_messages: Vec<&AiMessage> = messages
            .iter()
            .filter(|m| m.id != exclude_message_id)
            .collect();

        let entries = history_messages
            .iter()
            .map(|m| ConversationHistoryProjector::project_message(m))
            .collect();

        Ok(RecentConversationPack { entries })
    }
}
