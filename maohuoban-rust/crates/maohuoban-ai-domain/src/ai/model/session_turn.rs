use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use super::AiConversationSurface;

/// AiSessionTurnStatus Turn 执行状态
/// 核心职责：
/// - 表达单轮 turn 的完整生命周期状态
/// - 区分运行中、完成、失败、中断和等待确认
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AiSessionTurnStatus {
    Running,
    Completed,
    Failed,
    Interrupted,
    RequiresConfirmation,
}

impl AiSessionTurnStatus {
    /// as_str 返回数据库存储用稳定字符串
    #[must_use]
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Running => "running",
            Self::Completed => "completed",
            Self::Failed => "failed",
            Self::Interrupted => "interrupted",
            Self::RequiresConfirmation => "requires_confirmation",
        }
    }

    /// parse_from_str 从数据库字符串解析状态
    #[must_use]
    pub fn parse_from_str(s: &str) -> Option<Self> {
        match s {
            "running" => Some(Self::Running),
            "completed" => Some(Self::Completed),
            "failed" => Some(Self::Failed),
            "interrupted" => Some(Self::Interrupted),
            "requires_confirmation" => Some(Self::RequiresConfirmation),
            _ => None,
        }
    }

    /// is_terminal 判断是否为终态
    #[must_use]
    pub fn is_terminal(self) -> bool {
        matches!(self, Self::Completed | Self::Failed | Self::Interrupted)
    }
}

/// AiSessionTurn Turn 账本行
/// 核心职责：
/// - 作为一次完整 Agent 执行单元的数据库一等对象
/// - 关联 user message、assistant message、runtime event 和 provider diagnostics
/// - 承载 turn 级状态、意图、gate 摘要和终态信息
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AiSessionTurn {
    pub id: Uuid,
    pub session_id: Uuid,
    pub actor_user_id: Uuid,
    pub user_message_id: Uuid,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub assistant_message_id: Option<Uuid>,
    pub intent: String,
    pub gate_decision: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub resolved_pet_id: Option<Uuid>,
    pub engine_mode: String,
    pub surface: AiConversationSurface,
    pub status: AiSessionTurnStatus,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub finish_reason: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub error_code: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub retryable: Option<bool>,
    pub started_at: DateTime<Utc>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub finished_at: Option<DateTime<Utc>>,
}
