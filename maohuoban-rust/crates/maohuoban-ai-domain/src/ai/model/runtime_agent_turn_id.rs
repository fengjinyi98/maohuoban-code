use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// AgentTurnId Runtime turn 标识
/// 核心职责：
/// - 包装单轮对话 ID，避免与 chat session / message ID 混用
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(transparent)]
pub struct AgentTurnId(Uuid);

impl AgentTurnId {
    pub fn new() -> Self {
        Self(Uuid::new_v4())
    }

    pub fn from_uuid(id: Uuid) -> Self {
        Self(id)
    }

    pub fn as_uuid(self) -> Uuid {
        self.0
    }
}

impl Default for AgentTurnId {
    fn default() -> Self {
        Self::new()
    }
}
