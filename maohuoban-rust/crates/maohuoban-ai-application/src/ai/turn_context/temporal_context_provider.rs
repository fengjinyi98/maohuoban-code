use chrono::{DateTime, FixedOffset, Utc};
use maohuoban_ai_domain::ai::TemporalContext;

/// TemporalContextProvider 本轮时间上下文提供器
/// 核心职责：
/// - 将服务端 UTC 时间转换为模型可见本地时间
/// - 为本轮 Workbench 提供可信日期基准
pub struct TemporalContextProvider;

impl TemporalContextProvider {
    /// now_for_timezone 生成指定时区的当前时间上下文
    #[must_use]
    pub fn now_for_timezone(timezone: &str) -> TemporalContext {
        Self::from_utc(timezone, Utc::now())
    }

    /// from_utc 将 UTC 时间转换为指定时区上下文
    #[must_use]
    pub fn from_utc(timezone: &str, now_utc: DateTime<Utc>) -> TemporalContext {
        let offset = fixed_offset_for_timezone(timezone);
        let local = now_utc.with_timezone(&offset);
        TemporalContext {
            local_date: local.format("%Y-%m-%d").to_string(),
            local_datetime: local.to_rfc3339(),
            timezone: timezone.to_owned(),
        }
    }
}

/// fixed_offset_for_timezone 将产品当前支持时区映射为固定偏移
/// 核心职责：
/// - 当前先覆盖毛伙伴主时区 Asia/Shanghai
/// - 未识别时区使用 UTC，避免构造错误本地日期
fn fixed_offset_for_timezone(timezone: &str) -> FixedOffset {
    match timezone {
        "Asia/Shanghai" => FixedOffset::east_opt(8 * 60 * 60).expect("valid shanghai offset"),
        _ => FixedOffset::east_opt(0).expect("valid utc offset"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn temporal_context_provider_projects_shanghai_local_date() {
        let now = DateTime::parse_from_rfc3339("2026-07-01T20:30:29Z")
            .expect("parse time")
            .with_timezone(&Utc);

        let context = TemporalContextProvider::from_utc("Asia/Shanghai", now);

        assert_eq!(context.local_date, "2026-07-02");
        assert_eq!(context.local_datetime, "2026-07-02T04:30:29+08:00");
        assert_eq!(context.timezone, "Asia/Shanghai");
    }
}
