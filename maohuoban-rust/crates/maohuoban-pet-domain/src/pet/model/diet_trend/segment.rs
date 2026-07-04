use serde::{Deserialize, Serialize};

/// DietTrendSegment 饮食趋势分段
/// 核心职责：
/// - 表达一个饮食品类在总摄入趋势中的占比
/// - 支撑前端分段占比条渲染
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct DietTrendSegment {
    pub category: String,
    pub title: String,
    pub score: f64,
    pub percentage: i64,
}
