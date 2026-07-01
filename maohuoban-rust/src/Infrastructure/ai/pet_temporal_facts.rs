use chrono::{Datelike, NaiveDate};
use maohuoban_ai_domain::ai::{AiFactEntry, AiFactStrength};
use maohuoban_pet_domain::pet::IdentitySummary;

/// `pet_temporal_computed_facts` 构造宠物时间派生事实
/// 核心职责：
/// - 基于可信本地日期和宠物档案日期计算生日、年龄和陪伴天数
/// - 将派生结果写入 computed 桶，避免模型自行推算
pub(super) fn pet_temporal_computed_facts(
    identity: &IdentitySummary,
    local_date: NaiveDate,
) -> Vec<AiFactEntry> {
    let mut facts = Vec::new();

    if let Some(birthday) = identity
        .birthday
        .as_deref()
        .and_then(|value| NaiveDate::parse_from_str(value, "%Y-%m-%d").ok())
    {
        facts.push(computed_fact(
            "pet_identity.birthday_passed_this_year",
            birthday_passed_text(birthday, local_date),
        ));
        facts.push(computed_fact(
            "pet_identity.next_birthday",
            format!("下次生日是 {}", next_birthday(birthday, local_date)),
        ));
        facts.push(computed_fact(
            "pet_identity.age_display",
            age_display_text(birthday, local_date),
        ));
    }

    if let Some(arrival_date) = identity
        .arrival_date
        .as_deref()
        .and_then(|value| NaiveDate::parse_from_str(value, "%Y-%m-%d").ok())
        && local_date >= arrival_date
    {
        facts.push(computed_fact(
            "pet_identity.companionship_display",
            format!("到家陪伴 {} 天", (local_date - arrival_date).num_days()),
        ));
    }

    facts
}

fn birthday_passed_text(birthday: NaiveDate, local_date: NaiveDate) -> String {
    let Some(this_year_birthday) =
        NaiveDate::from_ymd_opt(local_date.year(), birthday.month(), birthday.day())
    else {
        return "今年生日日期不可计算".to_owned();
    };
    if local_date >= this_year_birthday {
        format!(
            "今年生日 {} 已经过了 {} 天",
            month_day_text(this_year_birthday),
            (local_date - this_year_birthday).num_days()
        )
    } else {
        format!(
            "今年生日 {} 还有 {} 天",
            month_day_text(this_year_birthday),
            (this_year_birthday - local_date).num_days()
        )
    }
}

fn next_birthday(birthday: NaiveDate, local_date: NaiveDate) -> NaiveDate {
    let this_year = NaiveDate::from_ymd_opt(local_date.year(), birthday.month(), birthday.day())
        .expect("birthday month/day must be valid in current year");
    if local_date < this_year {
        this_year
    } else {
        NaiveDate::from_ymd_opt(local_date.year() + 1, birthday.month(), birthday.day())
            .expect("birthday month/day must be valid in next year")
    }
}

fn age_display_text(birthday: NaiveDate, local_date: NaiveDate) -> String {
    if local_date < birthday {
        return "生日晚于当前日期，年龄不可计算".to_owned();
    }
    let mut years = local_date.year() - birthday.year();
    let birthday_this_year =
        NaiveDate::from_ymd_opt(local_date.year(), birthday.month(), birthday.day())
            .expect("birthday month/day must be valid in current year");
    if local_date < birthday_this_year {
        years -= 1;
    }
    let last_birthday =
        NaiveDate::from_ymd_opt(birthday.year() + years, birthday.month(), birthday.day())
            .expect("birthday month/day must be valid in age year");
    let days = (local_date - last_birthday).num_days();
    format!("当前年龄约 {years}岁{days}天")
}

fn month_day_text(date: NaiveDate) -> String {
    format!("{}月{}日", date.month(), date.day())
}

fn computed_fact(key: &str, value: String) -> AiFactEntry {
    AiFactEntry {
        key: key.to_owned(),
        value,
        strength: AiFactStrength::Strong,
        citation_id: None,
    }
}
