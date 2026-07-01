use serde::{Deserialize, Serialize};

/// TemporalContext 本轮可信时间上下文
/// 核心职责：
/// - 承载服务端在本轮生成的本地日期和时间
/// - 为模型回答今天、明天、生日和提醒类问题提供可信时间基准
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct TemporalContext {
    pub local_date: String,
    pub local_datetime: String,
    pub timezone: String,
}
