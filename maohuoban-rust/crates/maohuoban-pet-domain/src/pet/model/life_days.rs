use chrono::NaiveDate;

/// days_since_date 计算宠物日期到指定日期的间隔天数
/// 核心职责：
/// - 为首页和 Agent 宠物档案提供统一天数口径
/// - 保证未来日期不会产生负数展示
#[must_use]
pub fn days_since_date(start_date: NaiveDate, today: NaiveDate) -> i64 {
    (today - start_date).num_days().max(0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn days_since_date_returns_elapsed_days() {
        let start_date = NaiveDate::from_ymd_opt(2024, 3, 1).expect("start date");
        let today = NaiveDate::from_ymd_opt(2024, 3, 6).expect("today");

        assert_eq!(days_since_date(start_date, today), 5);
    }

    #[test]
    fn days_since_date_clamps_future_date_to_zero() {
        let start_date = NaiveDate::from_ymd_opt(2024, 3, 6).expect("start date");
        let today = NaiveDate::from_ymd_opt(2024, 3, 1).expect("today");

        assert_eq!(days_since_date(start_date, today), 0);
    }
}
