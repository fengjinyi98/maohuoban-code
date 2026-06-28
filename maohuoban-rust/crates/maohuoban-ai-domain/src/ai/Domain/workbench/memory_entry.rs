use serde::{Deserialize, Serialize};
use uuid::Uuid;

use super::MemoryScope;

/// MemoryEntry 模型可见记忆摘要
/// 核心职责：
/// - 承载已裁剪的记忆摘要
/// - 保留作用域和主体标识用于上下文归属
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct MemoryEntry {
    pub scope: MemoryScope,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub subject_id: Option<Uuid>,
    pub summary: String,
}
