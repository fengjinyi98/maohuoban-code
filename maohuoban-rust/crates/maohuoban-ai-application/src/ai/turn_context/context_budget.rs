//! context_budget 上下文预算策略
//! 核心职责：
//! - 在本轮上下文组装边界决定哪些已投影历史进入 LlmChatRequest.messages
//! - 按 turn 数和字节数硬上限裁剪，优先保留最近轮次

use maohuoban_ai_domain::ai::{RecentConversationEntry, RecentConversationPack};

/// ContextBudgetPolicy 上下文预算策略
/// 核心职责：
/// - 按 turn 数和字节数硬上限裁剪已投影历史窗口
/// - 优先保留最近轮次，裁剪较早普通闲聊
pub struct ContextBudgetPolicy {
    max_turns: usize,
    max_bytes: usize,
}

impl ContextBudgetPolicy {
    /// new 构造预算策略
    /// 核心职责：
    /// - max_turns 限制保留的最大 user-assistant 对话轮数
    /// - max_bytes 限制历史条目 content 总字节数
    #[must_use]
    pub fn new(max_turns: usize, max_bytes: usize) -> Self {
        Self {
            max_turns,
            max_bytes,
        }
    }

    /// default_for_deepseek_1m DeepSeek 1M 默认预算
    /// 核心职责：
    /// - 提供较大最近窗口，保留 turn 数和字节数硬上限
    #[must_use]
    pub fn default_for_deepseek_1m() -> Self {
        Self {
            max_turns: 20,
            max_bytes: 200_000,
        }
    }

    /// trim 按预算裁剪历史窗口
    /// 核心职责：
    /// - 先按 max_turns 裁剪（保留最近 max_turns * 2 条）
    /// - 再按 max_bytes 裁剪（从最旧开始移除，至少保留 1 条）
    #[must_use]
    pub fn trim(&self, pack: &RecentConversationPack) -> RecentConversationPack {
        if pack.entries.is_empty() {
            return RecentConversationPack::empty();
        }

        // Step 1: 按 turn 数裁剪，保留最近 max_turns * 2 条
        let max_entries = self.max_turns.saturating_mul(2);
        let start = pack.entries.len().saturating_sub(max_entries);
        let after_turn_trim: &[RecentConversationEntry] = &pack.entries[start..];

        // Step 2: 按字节数裁剪，从最旧开始移除
        let total_bytes: usize = after_turn_trim.iter().map(|e| e.content.len()).sum();
        if total_bytes <= self.max_bytes {
            return RecentConversationPack {
                entries: after_turn_trim.to_vec(),
            };
        }

        let mut byte_start = 0;
        let mut remaining_bytes = total_bytes;
        while remaining_bytes > self.max_bytes && after_turn_trim.len() - byte_start > 1 {
            remaining_bytes -= after_turn_trim[byte_start].content.len();
            byte_start += 1;
        }

        RecentConversationPack {
            entries: after_turn_trim[byte_start..].to_vec(),
        }
    }
}
