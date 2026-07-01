//! entries 事实包条目合并
//! 核心职责：
//! - 将事实包四个桶的条目合并为扁平列表，保留每条条目的 strength 标签
//! - 供工具结果回灌和 Prompt 上下文投影使用

use maohuoban_ai_domain::ai::{AiFactEntry, AiFactPackage};

/// package_entries 合并事实包内可回灌给模型的事实条目
/// 核心职责：
/// - 返回全部四个桶的事实条目，保留每条条目的 strength 标签
/// - 模型侧通过 certainty 标签区分强事实/待确认/弱线索
pub(super) fn package_entries(package: &AiFactPackage) -> Vec<AiFactEntry> {
    package
        .facts
        .iter()
        .chain(package.computed.iter())
        .chain(package.pending_confirmations.iter())
        .chain(package.weak_hints.iter())
        .cloned()
        .collect()
}
