// MemoryRetriever 私域记忆检索器
// 核心职责：
// - 按 MemoryQuery 条件检索活跃记忆
// - 强制校验查询条件合法性（Pet 必须有 pet_id，Household 必须有 household_id）
// - 通过 MemoryPack 过滤层隔离私域记忆
// - 公共问答不加载 Pet / Household 私域记忆
// - 未授权 pet 记忆不可检索

use std::sync::Arc;

use maohuoban_ai_domain::ai::{AiResult, MemoryPack};

use crate::ai::ports::{MemoryQuery, MemoryRepository};

/// MemoryRetriever 私域记忆检索器
/// 核心职责：
/// - 校验检索条件合法性
/// - 从仓储加载记忆
/// - 通过 MemoryPack 过滤层隔离私域记忆
pub struct MemoryRetriever {
    repo: Arc<dyn MemoryRepository>,
}

impl MemoryRetriever {
    /// new 构造记忆检索器
    #[must_use]
    pub fn new(repo: Arc<dyn MemoryRepository>) -> Self {
        Self { repo }
    }

    /// retrieve 检索记忆
    /// 核心职责：
    /// - 校验查询条件合法性
    /// - 从仓储加载记忆
    /// - 按 pet_id / household_id 过滤私域记忆
    /// - 无 pet_id 和 household_id 时过滤所有私域记忆（公共问答场景）
    pub async fn retrieve(&self, query: MemoryQuery) -> AiResult<MemoryPack> {
        if !query.is_valid() {
            return Err(maohuoban_ai_domain::ai::AiError::Conflict(format!(
                "invalid memory query: scope {:?} requires missing field",
                query.scope_type
            )));
        }

        let entries = self.repo.find_memories(&query).await?;
        let pack = MemoryPack { entries };

        // 有 pet_id 时只保留该宠物的私域记忆
        // 有 household_id（无 pet_id）时只保留该家庭的私域记忆
        // 都没有时过滤所有私域记忆（公共问答场景）
        let filtered = match (query.pet_id, query.household_id) {
            (Some(pid), _) => pack.filter_for_pet_context(pid),
            (None, Some(hid)) => pack.filter_for_household_context(hid),
            (None, None) => pack.filter_for_public_context(),
        };

        Ok(filtered)
    }
}
