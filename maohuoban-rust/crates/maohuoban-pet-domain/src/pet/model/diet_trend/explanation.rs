use serde::{Deserialize, Serialize};

/// DietTrendExplanation 饮食趋势说明
/// 核心职责：
/// - 由后端提供运营可调整的说明内容
/// - 避免前端硬编码算法解释
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct DietTrendExplanation {
    pub title: String,
    pub body: String,
}
