use serde::{Deserialize, Serialize};

/// HomeDietTrendExplanation 首页饮食趋势说明
/// 核心职责：
/// - 承载用户可见的趋势生成说明
/// - 保持说明内容由后端统一下发
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct HomeDietTrendExplanation {
    pub title: String,
    pub body: String,
}
