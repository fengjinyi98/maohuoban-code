use serde::{Deserialize, Serialize};

/// HomeDietTrendCalibration 首页饮食趋势库存校准
/// 核心职责：
/// - 转发后端饮食趋势克数校准证据
/// - 明确低置信时不输出克数估算
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct HomeDietTrendCalibration {
    pub confidence: String,
    pub grams_per_score: Option<f64>,
    pub daily_grams: Option<f64>,
    pub reason: String,
}
