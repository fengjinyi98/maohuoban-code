use serde::{Deserialize, Serialize};
use uuid::Uuid;

use super::{MemoryEntry, MemoryScope};

/// MemoryPack 本轮可见记忆包
/// 核心职责：
/// - 汇总已通过隔离与裁剪的记忆摘要
/// - 作为 Workbench 的可选上下文组成部分
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct MemoryPack {
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub entries: Vec<MemoryEntry>,
}

impl MemoryPack {
    /// filter_for_public_context 过滤掉私域记忆
    /// 核心职责：
    /// - 移除 Pet 和 Household scope 的记忆条目
    /// - 保留 User 和 Session scope 的记忆条目
    /// - 无宠物公共问答不加载私域宠物记忆
    #[must_use]
    pub fn filter_for_public_context(self) -> Self {
        Self {
            entries: self
                .entries
                .into_iter()
                .filter(|entry| !matches!(entry.scope, MemoryScope::Pet | MemoryScope::Household))
                .collect(),
        }
    }

    /// filter_for_pet_context 按目标宠物过滤私域记忆
    /// 核心职责：
    /// - Pet scope：仅保留 subject_id 匹配当前 pet_id 的条目
    /// - Household scope：无 household_id 时全部移除（subject_id 是 household_id 而非 pet_id）
    /// - 保留 User 和 Session scope 的全部条目
    /// - 防止其他宠物的记忆进入当前 turn
    #[must_use]
    pub fn filter_for_pet_context(self, pet_id: Uuid) -> Self {
        Self {
            entries: self
                .entries
                .into_iter()
                .filter(|entry| match entry.scope {
                    MemoryScope::Pet => entry.subject_id == Some(pet_id),
                    MemoryScope::Household => false,
                    MemoryScope::User | MemoryScope::Session => true,
                })
                .collect(),
        }
    }
}
