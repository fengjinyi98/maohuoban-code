// MHB_STRUCTURE_EXEMPTION: WT04 目标文档冻结该 Rust domain module 路径，保持现有 AI crate 模块形态。
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// AgentSessionEventEntry Agent runtime 会话事件
/// 核心职责：
/// - 以 append-only entry 关联 session、turn、事件名和结构化 payload
/// - 为 replay、诊断和历史消息关联提供稳定事件记录
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AgentSessionEventEntry {
    pub id: Uuid,
    pub session_id: Uuid,
    pub turn_id: Uuid,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub parent_event_id: Option<Uuid>,
    pub event_name: String,
    pub payload: serde_json::Value,
    pub created_at: DateTime<Utc>,
}

impl AgentSessionEventEntry {
    /// new 构造新的 session event entry
    /// 核心职责：
    /// - 为测试和 runtime 写入路径提供统一默认 id / created_at
    /// - 保留调用方传入的冻结事件名和 payload
    #[must_use]
    pub fn new(
        session_id: Uuid,
        turn_id: Uuid,
        event_name: impl Into<String>,
        payload: serde_json::Value,
    ) -> Self {
        Self {
            id: Uuid::new_v4(),
            session_id,
            turn_id,
            parent_event_id: None,
            event_name: event_name.into(),
            payload,
            created_at: Utc::now(),
        }
    }

    /// with_parent_event_id 设置父事件
    /// 核心职责：
    /// - 预留会话分叉或事件因果链路
    /// - 不改变 append-only entry 其他字段
    #[must_use]
    pub fn with_parent_event_id(mut self, parent_event_id: Uuid) -> Self {
        self.parent_event_id = Some(parent_event_id);
        self
    }
}
