use serde::{Deserialize, Serialize};

/// DietTrendCalibration 饮食趋势库存校准
/// 核心职责：
/// - 表达相对份量是否已经具备库存克数校准证据
/// - 在缺少库存闭环时显式禁止输出克数估算
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct DietTrendCalibration {
    pub confidence: String,
    pub grams_per_score: Option<f64>,
    pub daily_grams: Option<f64>,
    pub reason: String,
}
