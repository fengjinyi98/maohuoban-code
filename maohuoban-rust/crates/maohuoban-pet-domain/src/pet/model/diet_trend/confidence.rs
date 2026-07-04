use serde::{Deserialize, Serialize};

/// DietTrendConfidence 饮食趋势置信度
/// 核心职责：
/// - 表达算法是否具备足够证据输出趋势
/// - 给前端展示透明但不暴露内部公式的依据
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct DietTrendConfidence {
    pub level: String,
    pub score: f64,
    pub basis: Vec<String>,
}
