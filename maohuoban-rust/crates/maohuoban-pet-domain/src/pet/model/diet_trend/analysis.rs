use serde::{Deserialize, Serialize};

/// DietTrendAnalysis 饮食趋势用户可读分析
/// 核心职责：
/// - 承载面向用户的趋势结论
/// - 隔离算法中间指标和页面展示文案
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct DietTrendAnalysis {
    pub headline: String,
    pub summary: String,
    pub observations: Vec<String>,
}
