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

/// MemoryRecallBudget 记忆召回预算
/// 核心职责：
/// - 限制本轮进入 MemoryPack 的最大条目数
/// - 限制本轮进入 MemoryPack 的摘要总字节数
/// - 预算裁剪发生在 scope 隔离之后，避免未授权记忆影响裁剪结果
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct MemoryRecallBudget {
    max_entries: usize,
    max_bytes: usize,
}

impl MemoryRecallBudget {
    /// new 构造记忆召回预算
    #[must_use]
    pub fn new(max_entries: usize, max_bytes: usize) -> Self {
        Self {
            max_entries,
            max_bytes,
        }
    }

    /// default_for_deepseek_1m DeepSeek 1M 默认记忆预算
    #[must_use]
    pub fn default_for_deepseek_1m() -> Self {
        Self {
            max_entries: 8,
            max_bytes: 12_000,
        }
    }

    /// trim 裁剪已隔离的 MemoryPack
    /// 核心职责：
    /// - 保持仓储返回顺序作为召回排序结果
    /// - 先应用 top-k，再应用摘要字节预算
    #[must_use]
    pub fn trim(self, pack: MemoryPack) -> MemoryPack {
        if self.max_entries == 0 || self.max_bytes == 0 || pack.entries.is_empty() {
            return MemoryPack {
                entries: Vec::new(),
            };
        }

        let mut total_bytes = 0usize;
        let entries = pack
            .entries
            .into_iter()
            .take(self.max_entries)
            .filter(|entry| {
                let next_bytes = total_bytes.saturating_add(entry.summary.len());
                if next_bytes > self.max_bytes {
                    return false;
                }
                total_bytes = next_bytes;
                true
            })
            .collect();

        MemoryPack { entries }
    }
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
        self.retrieve_with_budget(query, MemoryRecallBudget::default_for_deepseek_1m())
            .await
    }

    /// retrieve_with_budget 按预算检索记忆
    /// 核心职责：
    /// - 先执行查询合法性校验
    /// - 从仓储加载已授权候选记忆
    /// - 按当前上下文 scope 隔离私域记忆
    /// - 在隔离后执行 top-k 和字节预算裁剪
    pub async fn retrieve_with_budget(
        &self,
        query: MemoryQuery,
        budget: MemoryRecallBudget,
    ) -> AiResult<MemoryPack> {
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

        Ok(budget.trim(filtered))
    }
}
