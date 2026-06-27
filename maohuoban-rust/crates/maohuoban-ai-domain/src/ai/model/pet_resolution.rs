use serde::{Deserialize, Serialize};
use uuid::Uuid;

use super::{AiPetCandidate, AiPetDisplaySnapshot};

/// AiPetResolution 宠物解析结果
/// 核心职责：
/// - 表达目标宠物的解析状态：已解析、需要选择、未授权或不存在、无宠物上下文
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "status", rename_all = "snake_case")]
pub enum AiPetResolution {
    Resolved {
        pet_id: Uuid,
        snapshot: AiPetDisplaySnapshot,
    },
    NeedsSelection {
        candidates: Vec<AiPetCandidate>,
    },
    UnauthorizedOrNotFound,
    NoPetContext,
}

impl AiPetResolution {
    /// resolved_pet_id 返回已解析宠物 ID，否则 None
    pub fn resolved_pet_id(&self) -> Option<Uuid> {
        match self {
            Self::Resolved { pet_id, .. } => Some(*pet_id),
            _ => None,
        }
    }

    /// is_resolved 判断是否解析到唯一授权宠物
    pub fn is_resolved(&self) -> bool {
        matches!(self, Self::Resolved { .. })
    }
}
