use serde::{Deserialize, Serialize};

use crate::ai::{AiMessageRole, LlmMessage, LlmRole, LlmToolCall};

/// RecentConversationEntry 模型可见会话消息条目
/// 核心职责：
/// - 承载同会话最近一轮或多轮的模型可见消息
/// - 类型层面保证不包含 provider_raw、reasoning_content 等内部字段
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RecentConversationEntry {
    pub role: AiMessageRole,
    pub content: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub tool_call_id: Option<String>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub tool_calls: Vec<LlmToolCall>,
}

impl From<&RecentConversationEntry> for LlmMessage {
    fn from(entry: &RecentConversationEntry) -> Self {
        Self {
            role: match entry.role {
                AiMessageRole::User => LlmRole::User,
                AiMessageRole::Assistant => LlmRole::Assistant,
                AiMessageRole::System => LlmRole::System,
            },
            content: entry.content.clone(),
            tool_call_id: entry.tool_call_id.clone(),
            tool_calls: entry.tool_calls.clone(),
        }
    }
}

/// RecentConversationPack 模型可见最近会话窗口
/// 核心职责：
/// - 保存当前 chat_session_id 的已投影历史窗口
/// - 由 TurnContextBuilder 和 Runtime 组装器消费
/// - 类型层面保证只包含模型可见消息
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RecentConversationPack {
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub entries: Vec<RecentConversationEntry>,
}

impl RecentConversationPack {
    /// empty 构造空历史窗口
    #[must_use]
    pub fn empty() -> Self {
        Self {
            entries: Vec::new(),
        }
    }

    /// to_messages 转换为 LLM 消息
    #[must_use]
    pub fn to_messages(&self) -> Vec<LlmMessage> {
        self.entries.iter().map(LlmMessage::from).collect()
    }
}
