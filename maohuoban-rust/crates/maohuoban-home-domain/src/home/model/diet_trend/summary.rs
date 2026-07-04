use serde::{Deserialize, Serialize};

use super::{HomeDietTrendConfidence, HomeDietTrendExplanation, HomeDietTrendSegment};

/// HomeDietTrendSummary 首页饮食趋势摘要
/// 核心职责：
/// - 承载当前宠物整体饮食趋势的首页读模型
/// - 保持首页聚合与宠物饮食分析实现解耦
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct HomeDietTrendSummary {
    pub window_days: i64,
    pub status: String,
    pub segments: Vec<HomeDietTrendSegment>,
    pub confidence: HomeDietTrendConfidence,
    pub explanation: HomeDietTrendExplanation,
}
