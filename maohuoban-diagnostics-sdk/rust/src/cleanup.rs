use serde::{Deserialize, Serialize};
use std::time::Duration;

/// `CleanupPolicy` 本地清理策略
/// 核心职责：
/// - 控制诊断段文件保留时间与磁盘上限
/// - 控制导出包保留时间
#[derive(Clone, Debug)]
pub struct CleanupPolicy {
    pub max_total_bytes: u64,
    pub max_segment_age: Duration,
    pub max_export_age: Duration,
}

impl Default for CleanupPolicy {
    fn default() -> Self {
        Self {
            max_total_bytes: 50 * 1024 * 1024,
            max_segment_age: Duration::from_secs(7 * 24 * 60 * 60),
            max_export_age: Duration::from_secs(24 * 60 * 60),
        }
    }
}

/// `CleanupReport` 清理执行结果
/// 核心职责：
/// - 记录被删除的段文件与导出包数量
/// - 为调试清理策略提供可观测结果
#[derive(Clone, Debug, Default, Deserialize, Serialize)]
pub struct CleanupReport {
    pub removed_segments: usize,
    pub removed_exports: usize,
    pub freed_bytes: u64,
}
