use chrono::{DateTime, Local, Utc};
use serde_json::{Value, json};

/// `time_basis_json` 生成诊断报告时间基准说明
/// 核心职责：
/// - 声明事件时间使用 UTC RFC3339 作为统一排序基准
/// - 暴露导出机器本地时区，辅助人工和 LLM 阅读报告
pub(super) fn time_basis_json() -> Value {
    let local_now = Local::now();
    json!({
        "event_timestamps": "utc_rfc3339",
        "local_previews": "export_machine_local_time",
        "local_timezone": local_now.format("%Z").to_string(),
        "local_utc_offset_seconds": local_now.offset().local_minus_utc(),
    })
}

/// `local_rfc3339` 转换本地时间预览
/// 核心职责：
/// - 保留原始 UTC 事件时间不变
/// - 为报告索引提供带本地时区偏移的阅读辅助字段
pub(super) fn local_rfc3339(timestamp: &DateTime<Utc>) -> String {
    timestamp.with_timezone(&Local).to_rfc3339()
}
