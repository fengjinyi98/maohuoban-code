use serde::{Deserialize, Serialize};

use super::MemoryEntry;

/// MemoryPack 本轮可见记忆包
/// 核心职责：
/// - 汇总已通过隔离与裁剪的记忆摘要
/// - 作为 Workbench 的可选上下文组成部分
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct MemoryPack {
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub entries: Vec<MemoryEntry>,
}
