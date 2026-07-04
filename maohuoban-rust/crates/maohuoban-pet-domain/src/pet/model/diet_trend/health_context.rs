use serde::{Deserialize, Serialize};

/// DietTrendHealthContext 饮食趋势健康上下文摘要
/// 核心职责：
/// - 表达异常和医疗期样本隔离结果
/// - 支撑前端解释基线样本是否被排除
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct DietTrendHealthContext {
    pub included_sample_count: i64,
    pub excluded_sample_count: i64,
    pub excluded_reasons: Vec<String>,
}
