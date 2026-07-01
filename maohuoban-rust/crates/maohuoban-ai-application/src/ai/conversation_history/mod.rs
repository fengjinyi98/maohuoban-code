//! conversation_history 同会话历史投影 pipeline
//! 核心职责：
//! - 从仓储加载当前会话最近消息窗口（含归属校验）
//! - 把持久化 AiMessage 投影成模型可见 RecentConversationEntry
//! - 支持压缩边界：有活跃摘要时只加载 compressed_until_message_id 之后的消息

use std::sync::Arc;

use maohuoban_ai_domain::ai::{AiError, AiMessage, AiMessageRole, AiResult, SessionSummary};
pub use maohuoban_ai_domain::ai::{RecentConversationEntry, RecentConversationPack};
use uuid::Uuid;

use crate::ai::ports::{AiSessionRepository, SessionSummaryRepository};
use crate::ai::turn_context::ContextBudgetPolicy;

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

    /// project_messages_ref 把引用列表投影成模型可见历史包
    /// 核心职责：
    /// - 接收已过滤的 &[&AiMessage]，避免调用方额外 clone
    /// - 与 project_messages 行为一致
    #[must_use]
    pub fn project_messages_ref(&self, messages: &[&AiMessage]) -> RecentConversationPack {
        RecentConversationPack {
            entries: messages.iter().map(|m| Self::project_message(m)).collect(),
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
/// - 如果有活跃摘要，只加载 compressed_until_message_id 之后的消息
/// - 排除当前轮用户消息（按 exclude_message_id）
/// - 投影成模型可见历史
pub struct RecentConversationLoader {
    repo: Arc<dyn AiSessionRepository>,
    summary_repo: Arc<dyn SessionSummaryRepository>,
}

impl RecentConversationLoader {
    /// new 构造加载器
    #[must_use]
    pub fn new(
        repo: Arc<dyn AiSessionRepository>,
        summary_repo: Arc<dyn SessionSummaryRepository>,
    ) -> Self {
        Self { repo, summary_repo }
    }

    /// load_recent_conversation 加载最近会话历史
    /// 核心职责：
    /// - 校验 session 归属当前 actor_user_id
    /// - 如果有活跃摘要，只加载 compressed_until_message_id 之后的消息
    /// - 排除当前轮用户消息（按 exclude_message_id）
    /// - 投影成模型可见 RecentConversationPack
    pub async fn load_recent_conversation(
        &self,
        actor_user_id: Uuid,
        session_id: Uuid,
        exclude_message_id: Uuid,
        context_length: u32,
        token_budget: u32,
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

        // 如果有活跃摘要且有压缩边界，只保留边界之后的消息
        let active_summary = self.summary_repo.get_active_summary(session_id).await?;
        let filtered_messages: Vec<&AiMessage> = match &active_summary {
            Some(summary) if summary.compressed_until_message_id.is_some() => {
                Self::filter_after_compression_boundary(&messages, summary)
            }
            _ => messages.iter().collect(),
        };

        // 排除当前轮用户消息
        let history_messages: Vec<&AiMessage> = filtered_messages
            .into_iter()
            .filter(|m| m.id != exclude_message_id)
            .filter(|m| !is_blank_assistant_message(m))
            .collect();

        let entries = history_messages
            .iter()
            .map(|m| ConversationHistoryProjector::project_message(m))
            .collect();

        let pack = RecentConversationPack { entries };
        Ok(ContextBudgetPolicy::new(context_length as usize, token_budget as usize).trim(&pack))
    }

    /// filter_after_compression_boundary 过滤出压缩边界之后的消息
    /// 核心职责：
    /// - 找到 compressed_until_message_id 对应的消息位置
    /// - 只保留该位置之后的消息
    fn filter_after_compression_boundary<'a>(
        messages: &'a [AiMessage],
        summary: &SessionSummary,
    ) -> Vec<&'a AiMessage> {
        let Some(boundary_id) = summary.compressed_until_message_id else {
            return messages.iter().collect();
        };

        let boundary_pos = messages.iter().position(|m| m.id == boundary_id);

        match boundary_pos {
            Some(pos) => messages[pos + 1..].iter().collect(),
            None => {
                // 边界消息已被删除，按摘要创建时间过滤
                messages
                    .iter()
                    .filter(|m| m.created_at > summary.created_at)
                    .collect()
            }
        }
    }
}

fn is_blank_assistant_message(message: &AiMessage) -> bool {
    matches!(message.role, AiMessageRole::Assistant) && message.content.trim().is_empty()
}
