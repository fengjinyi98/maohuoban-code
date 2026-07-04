use serde::{Deserialize, Serialize};

/// HomeDietTrendConfidence 首页饮食趋势置信度
/// 核心职责：
/// - 表达饮食趋势摘要的可参考程度
/// - 让客户端展示后端判断依据而非自行推断
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct HomeDietTrendConfidence {
    pub level: String,
    pub score: f64,
    pub basis: Vec<String>,
}
