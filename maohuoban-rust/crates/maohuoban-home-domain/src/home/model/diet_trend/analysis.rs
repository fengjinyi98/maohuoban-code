use serde::{Deserialize, Serialize};

/// HomeDietTrendAnalysis 首页饮食趋势分析结论
/// 核心职责：
/// - 对齐宠物饮食趋势分析读模型
/// - 保持首页聚合 DTO 与详情接口契约一致
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct HomeDietTrendAnalysis {
    pub headline: String,
    pub summary: String,
    pub observations: Vec<String>,
}
