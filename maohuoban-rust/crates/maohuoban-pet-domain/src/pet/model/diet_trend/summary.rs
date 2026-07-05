use serde::{Deserialize, Serialize};

use super::{
    DietTrendCalibration, DietTrendConfidence, DietTrendExplanation, DietTrendHealthContext,
    DietTrendSegment,
};

/// DietTrendSummary 饮食趋势摘要
/// 核心职责：
/// - 表达储物柜饮食趋势总览卡所需后端读模型
/// - 暴露分品类占比、置信度和后端可运营说明文案
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct DietTrendSummary {
    pub window_days: i64,
    pub status: String,
    pub segments: Vec<DietTrendSegment>,
    pub confidence: DietTrendConfidence,
    pub health_context: DietTrendHealthContext,
    pub calibration: DietTrendCalibration,
    pub explanation: DietTrendExplanation,
}
