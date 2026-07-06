use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use super::{AiAnswerVerification, AiContentBlock, AiConversationSurface, AiPetDisplaySnapshot};

/// AiMessageRole AI 消息角色
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AiMessageRole {
    User,
    Assistant,
    System,
}

/// AiMessageStatus AI 消息流式状态
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AiMessageStatus {
    Streaming,
    Completed,
    Failed,
}

/// AiMessage AI 消息
/// 核心职责：
/// - 持久化用户、助手、系统消息及其流式状态、引用、usage、provider 和 finish reason
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AiMessage {
    pub id: Uuid,
    pub session_id: Uuid,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub turn_id: Option<Uuid>,
    pub role: AiMessageRole,
    pub content: String,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub content_blocks: Vec<AiContentBlock>,
    pub status: AiMessageStatus,
    pub citations: Vec<uuid::Uuid>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub model: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub provider: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub finish_reason: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub usage_input_tokens: Option<u32>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub usage_output_tokens: Option<u32>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub verification: Option<AiAnswerVerification>,
    pub created_at: DateTime<Utc>,
}

/// AiChatSessionStatus AI 会话状态
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AiChatSessionStatus {
    Active,
    Archived,
}

/// AiChatSessionVisibility AI 会话可见性
/// 核心职责：
/// - 区分用户可见聊天记录与后台追踪上下文
/// - 避免用归档状态表达非聊天历史语义
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AiChatSessionVisibility {
    Visible,
    Background,
}

/// AiChatSessionContextStatus AI 会话上下文状态
/// 核心职责：
/// - 表达异常等业务上下文相对聊天记录的独立生命周期
/// - 保持聊天记录可见性和业务上下文关闭互不替代
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AiChatSessionContextStatus {
    Active,
    Deleted,
    Closed,
}

/// AiChatSession AI 会话
/// 核心职责：
/// - 持久化会话、actor user、primary pet、surface、来源上下文、标题、置顶和宠物展示快照
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AiChatSession {
    pub id: Uuid,
    pub actor_user_id: Uuid,
    pub primary_pet_id: Option<Uuid>,
    pub surface: AiConversationSurface,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub source_hint_id: Option<Uuid>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub source_task_id: Option<Uuid>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub chat_context_kind: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub abnormal_episode_id: Option<Uuid>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub agent_followup_id: Option<Uuid>,
    pub title: String,
    pub is_pinned: bool,
    pub pet_display_snapshot: Option<AiPetDisplaySnapshot>,
    pub status: AiChatSessionStatus,
    pub session_visibility: AiChatSessionVisibility,
    pub context_status: AiChatSessionContextStatus,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub activated_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// AiToolAccessLog 工具访问审计日志
/// 核心职责：
/// - 记录工具调用、授权结果、目标 scope、returned ref IDs、拒绝原因和风险信号
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AiToolAccessLog {
    pub id: Uuid,
    pub session_id: Option<Uuid>,
    pub actor_user_id: Uuid,
    pub tool_name: String,
    pub requested_scope: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub target_pet_id: Option<Uuid>,
    pub allowed: bool,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub denied_reason: Option<String>,
    pub returned_ref_ids: Vec<String>,
    pub duration_ms: i64,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub risk_signal: Option<String>,
    pub created_at: DateTime<Utc>,
}

/// AiRequestGateLog 意图闸门审计日志
/// 核心职责：
/// - 记录 intent、gate decision、是否加载上下文、成本估算和风险信号
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AiRequestGateLog {
    pub id: Uuid,
    pub session_id: Option<Uuid>,
    pub actor_user_id: Uuid,
    pub intent: String,
    pub gate_decision: String,
    pub context_loaded: bool,
    pub request_hash: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub resolved_pet_id: Option<Uuid>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub selected_pet_id: Option<Uuid>,
    pub risk_signal: Option<String>,
    pub estimated_input_tokens: u32,
    pub created_at: DateTime<Utc>,
}
