use serde::{Deserialize, Serialize};

/// HomeDietTrendHealthContext 首页饮食趋势健康上下文
/// 核心职责：
/// - 承载异常和医疗样本隔离结果
/// - 保持首页聚合读模型与宠物饮食趋势读模型字段一致
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct HomeDietTrendHealthContext {
    pub included_sample_count: i64,
    pub excluded_sample_count: i64,
    pub excluded_reasons: Vec<String>,
}
