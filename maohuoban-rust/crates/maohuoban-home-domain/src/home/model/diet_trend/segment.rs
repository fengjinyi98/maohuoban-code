use serde::{Deserialize, Serialize};

/// HomeDietTrendSegment 首页饮食趋势分段
/// 核心职责：
/// - 表达单个饮食品类在趋势窗口内的估算占比
/// - 为客户端渲染趋势条和图例提供稳定字段
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct HomeDietTrendSegment {
    pub category: String,
    pub title: String,
    pub score: f64,
    pub percentage: i64,
}
