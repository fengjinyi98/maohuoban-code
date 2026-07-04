use std::collections::{BTreeMap, BTreeSet, HashMap};

use chrono::NaiveDate;

use crate::pet::FoodInventoryCategory;

use super::{
    DietTrendConfidence, DietTrendExplanation, DietTrendFeedingSample, DietTrendHealthContext,
    DietTrendSegment, DietTrendSummary,
};

const LOW_CONFIDENCE_THRESHOLD: f64 = 0.35;
const MEDIUM_CONFIDENCE_THRESHOLD: f64 = 0.85;
const MIN_BASELINE_SAMPLE_DAYS: usize = 14;
const EMA_ALPHA: f64 = 0.25;

/// build_diet_trend_summary 生成饮食趋势摘要
/// 核心职责：
/// - 对可分析饮食品类做分段占比计算
/// - 基于样本数量、连续性和库存证据生成动态置信度
#[must_use]
pub fn build_diet_trend_summary(
    samples: &[DietTrendFeedingSample],
    window_days: i64,
) -> DietTrendSummary {
    let categories = vec![
        (FoodInventoryCategory::MainFood, 0.0),
        (FoodInventoryCategory::WetFood, 0.0),
        (FoodInventoryCategory::Treats, 0.0),
        (FoodInventoryCategory::Nutrition, 0.0),
    ];

    let mut included_samples = Vec::new();
    let mut excluded_reasons = BTreeSet::new();
    for sample in samples {
        if !is_supported_food_category(sample.category) {
            continue;
        }
        included_samples.push(sample);
        if !is_baseline_health_context(&sample.health_context) {
            excluded_reasons.insert(sample.health_context.clone());
        }
    }

    let daily_scores = build_daily_scores(samples);
    let category_scores = categories
        .into_iter()
        .map(|(category, _)| {
            let total = daily_scores.get(&category).map_or(0.0, |scores| {
                scores.values().map(|score| score.total_score).sum()
            });
            (category, total)
        })
        .collect::<Vec<_>>();
    let total_score: f64 = category_scores.iter().map(|(_, score)| score).sum();
    let segments = build_segments(category_scores, total_score, &daily_scores);
    let confidence = build_confidence(&included_samples, window_days);
    let health_context = build_health_context(&included_samples, excluded_reasons);
    let status = if total_score == 0.0 {
        "insufficient_data"
    } else if segments
        .iter()
        .all(|segment| segment.baseline_score.is_none())
    {
        "collecting_baseline"
    } else if confidence.score < LOW_CONFIDENCE_THRESHOLD {
        "collecting"
    } else {
        "observing"
    }
    .to_owned();

    DietTrendSummary {
        window_days,
        status,
        segments,
        confidence,
        health_context,
        explanation: DietTrendExplanation {
            title: "饮食趋势是怎么生成的".to_owned(),
            body: "我们会结合喂食记录、储物柜食品分类和库存引用生成饮食趋势。记录越连续、食品引用越完整，趋势参考价值越高。饮食趋势用于日常观察和就诊沟通参考，不构成诊断结论。".to_owned(),
        },
    }
}

fn build_segments(
    category_scores: Vec<(FoodInventoryCategory, f64)>,
    total_score: f64,
    daily_scores: &HashMap<FoodInventoryCategory, BTreeMap<NaiveDate, DailyScore>>,
) -> Vec<DietTrendSegment> {
    let mut remaining_percentage = 100;
    let last_non_zero_index = category_scores.iter().rposition(|(_, score)| *score > 0.0);

    category_scores
        .into_iter()
        .enumerate()
        .map(|(index, (category, score))| {
            let percentage = if score == 0.0 || total_score == 0.0 {
                0
            } else if Some(index) == last_non_zero_index {
                remaining_percentage
            } else {
                let value = rounded_percentage(score, total_score);
                remaining_percentage -= value;
                value
            };
            DietTrendSegment {
                category: category.as_str().to_owned(),
                title: category_title(category).to_owned(),
                score,
                percentage,
                baseline_score: category_baseline_score(category, daily_scores),
                baseline_sample_days: category_baseline_sample_days(category, daily_scores),
                current_ratio: category_current_ratio(category, daily_scores),
                ema_score: category_ema_score(category, daily_scores),
            }
        })
        .collect()
}

#[derive(Debug, Clone, Copy, Default)]
struct DailyScore {
    total_score: f64,
    baseline_score: f64,
    included_in_baseline: bool,
}

fn build_daily_scores(
    samples: &[DietTrendFeedingSample],
) -> HashMap<FoodInventoryCategory, BTreeMap<NaiveDate, DailyScore>> {
    let mut scores: HashMap<FoodInventoryCategory, BTreeMap<NaiveDate, DailyScore>> =
        HashMap::new();
    for sample in samples {
        if !is_supported_food_category(sample.category) {
            continue;
        }
        let category_scores = scores.entry(sample.category).or_default();
        let day_score = category_scores
            .entry(sample.occurred_at.date_naive())
            .or_default();
        let amount = amount_score(&sample.amount_text);
        day_score.total_score += amount;
        if is_baseline_health_context(&sample.health_context) {
            day_score.baseline_score += amount;
            day_score.included_in_baseline = true;
        }
    }
    scores
}

fn category_baseline_scores(
    category: FoodInventoryCategory,
    daily_scores: &HashMap<FoodInventoryCategory, BTreeMap<NaiveDate, DailyScore>>,
) -> Vec<f64> {
    daily_scores
        .get(&category)
        .into_iter()
        .flat_map(|scores| scores.values())
        .filter(|score| score.included_in_baseline)
        .map(|score| score.baseline_score)
        .collect()
}

fn category_baseline_score(
    category: FoodInventoryCategory,
    daily_scores: &HashMap<FoodInventoryCategory, BTreeMap<NaiveDate, DailyScore>>,
) -> Option<f64> {
    let mut scores = category_baseline_scores(category, daily_scores);
    if scores.len() < MIN_BASELINE_SAMPLE_DAYS {
        return None;
    }
    scores.sort_by(f64::total_cmp);
    let middle = scores.len() / 2;
    if scores.len().is_multiple_of(2) {
        Some(round_two(f64::midpoint(scores[middle - 1], scores[middle])))
    } else {
        Some(round_two(scores[middle]))
    }
}

fn category_baseline_sample_days(
    category: FoodInventoryCategory,
    daily_scores: &HashMap<FoodInventoryCategory, BTreeMap<NaiveDate, DailyScore>>,
) -> i64 {
    i64::try_from(category_baseline_scores(category, daily_scores).len()).unwrap_or(i64::MAX)
}

fn category_current_ratio(
    category: FoodInventoryCategory,
    daily_scores: &HashMap<FoodInventoryCategory, BTreeMap<NaiveDate, DailyScore>>,
) -> Option<f64> {
    let baseline = category_baseline_score(category, daily_scores)?;
    if baseline == 0.0 {
        return None;
    }
    let latest_score = daily_scores
        .get(&category)?
        .iter()
        .next_back()
        .map(|(_, score)| score.total_score)?;
    Some(round_two(latest_score / baseline))
}

fn category_ema_score(
    category: FoodInventoryCategory,
    daily_scores: &HashMap<FoodInventoryCategory, BTreeMap<NaiveDate, DailyScore>>,
) -> Option<f64> {
    let mut scores = daily_scores
        .get(&category)?
        .values()
        .map(|score| score.total_score);
    let first = scores.next()?;
    let ema = scores.fold(first, |previous, current| {
        EMA_ALPHA * current + (1.0 - EMA_ALPHA) * previous
    });
    Some(round_two(ema))
}

fn build_health_context(
    samples: &[&DietTrendFeedingSample],
    excluded_reasons: BTreeSet<String>,
) -> DietTrendHealthContext {
    let included_sample_count = samples
        .iter()
        .filter(|sample| is_baseline_health_context(&sample.health_context))
        .count();
    let excluded_sample_count = samples.len().saturating_sub(included_sample_count);
    DietTrendHealthContext {
        included_sample_count: i64::try_from(included_sample_count).unwrap_or(i64::MAX),
        excluded_sample_count: i64::try_from(excluded_sample_count).unwrap_or(i64::MAX),
        excluded_reasons: excluded_reasons.into_iter().collect(),
    }
}

fn build_confidence(
    included_samples: &[&DietTrendFeedingSample],
    window_days: i64,
) -> DietTrendConfidence {
    let sample_count = included_samples.len();
    let referenced_count = included_samples
        .iter()
        .filter(|sample| sample.has_food_item)
        .count();
    let snapshot_count = included_samples
        .iter()
        .filter(|sample| sample.has_inventory_snapshot)
        .count();
    let active_days = active_day_count(included_samples);

    let sample_score = (count_to_f64(sample_count) / 7.0).min(1.0);
    let reference_score = if sample_count == 0 {
        0.0
    } else {
        count_to_f64(referenced_count) / count_to_f64(sample_count)
    };
    let snapshot_score = if sample_count == 0 {
        0.0
    } else {
        count_to_f64(snapshot_count) / count_to_f64(sample_count)
    };
    let continuity_score = if window_days <= 0 {
        0.0
    } else {
        count_to_f64(active_days) / positive_days_to_f64(window_days)
    };
    let score = round_two(
        sample_score * 0.35
            + reference_score * 0.25
            + snapshot_score * 0.25
            + continuity_score * 0.15,
    );

    let level = if score >= MEDIUM_CONFIDENCE_THRESHOLD {
        "high"
    } else if score >= LOW_CONFIDENCE_THRESHOLD {
        "medium"
    } else {
        "low"
    }
    .to_owned();

    DietTrendConfidence {
        level,
        score,
        basis: vec![
            format!("近 {window_days} 天有 {sample_count} 条可分析喂食记录"),
            format!("其中 {referenced_count} 条关联了储物柜食品"),
            format!("覆盖 {active_days} 个记录日"),
        ],
    }
}

fn active_day_count(samples: &[&DietTrendFeedingSample]) -> usize {
    let mut days = samples
        .iter()
        .map(|sample| sample.occurred_at.date_naive())
        .collect::<Vec<_>>();
    days.sort_unstable();
    days.dedup();
    days.len()
}

fn amount_score(amount_text: &str) -> f64 {
    match amount_text.trim() {
        "少量" | "少一点" => 0.75,
        "多一点" | "多量" => 1.25,
        _ => 1.0,
    }
}

fn is_supported_food_category(category: FoodInventoryCategory) -> bool {
    matches!(
        category,
        FoodInventoryCategory::MainFood
            | FoodInventoryCategory::WetFood
            | FoodInventoryCategory::Treats
            | FoodInventoryCategory::Nutrition
    )
}

fn is_baseline_health_context(health_context: &str) -> bool {
    health_context == "healthy"
}

fn category_title(category: FoodInventoryCategory) -> &'static str {
    match category {
        FoodInventoryCategory::MainFood => "主粮",
        FoodInventoryCategory::WetFood => "湿粮/罐头",
        FoodInventoryCategory::Treats => "零食",
        FoodInventoryCategory::Nutrition => "营养品",
        FoodInventoryCategory::Other => "其他",
        FoodInventoryCategory::CatLitter => "猫砂",
        FoodInventoryCategory::Medicine => "药品",
    }
}

fn round_two(value: f64) -> f64 {
    (value * 100.0).round() / 100.0
}

fn count_to_f64(value: usize) -> f64 {
    f64::from(u32::try_from(value).unwrap_or(u32::MAX))
}

fn positive_days_to_f64(value: i64) -> f64 {
    f64::from(u32::try_from(value).unwrap_or(u32::MAX))
}

fn rounded_percentage(score: f64, total_score: f64) -> i64 {
    let value = ((score / total_score) * 100.0).round().clamp(0.0, 100.0);
    #[expect(
        clippy::cast_possible_truncation,
        reason = "百分比已四舍五入并限制在 0..=100"
    )]
    {
        value as i64
    }
}

#[cfg(test)]
mod tests {
    use chrono::{TimeZone, Utc};

    use super::*;

    #[test]
    fn diet_trend_summary_excludes_non_food_categories() {
        let samples = vec![
            sample(FoodInventoryCategory::MainFood, "正常", true),
            sample(FoodInventoryCategory::CatLitter, "正常", true),
            sample(FoodInventoryCategory::Medicine, "正常", true),
        ];

        let summary = build_diet_trend_summary(&samples, 7);

        assert_eq!(summary.segments[0].percentage, 100);
        assert_eq!(summary.segments[1].percentage, 0);
        assert_eq!(summary.segments[2].percentage, 0);
        assert_eq!(summary.segments[3].percentage, 0);
    }

    #[test]
    fn diet_trend_summary_confidence_is_dynamic() {
        let low =
            build_diet_trend_summary(&[sample(FoodInventoryCategory::MainFood, "正常", false)], 7);
        let high = build_diet_trend_summary(
            &[
                sample(FoodInventoryCategory::MainFood, "正常", true),
                sample(FoodInventoryCategory::WetFood, "正常", true),
                sample(FoodInventoryCategory::Treats, "少量", true),
                sample(FoodInventoryCategory::Nutrition, "少量", true),
            ],
            7,
        );

        assert!(low.confidence.score < high.confidence.score);
        assert_eq!(low.confidence.level, "low");
        assert_eq!(high.confidence.level, "medium");
    }

    #[test]
    fn diet_trend_summary_builds_category_baseline_from_healthy_daily_scores() {
        let samples = (1..=14)
            .map(|day| {
                dated_sample(
                    FoodInventoryCategory::MainFood,
                    "正常",
                    true,
                    2026,
                    7,
                    day,
                    "healthy",
                )
            })
            .collect::<Vec<_>>();

        let summary = build_diet_trend_summary(&samples, 30);
        let main_food = summary
            .segments
            .iter()
            .find(|segment| segment.category == "main_food")
            .expect("main food segment");

        assert_eq!(main_food.baseline_score, Some(1.0));
        assert_eq!(main_food.baseline_sample_days, 14);
        assert_eq!(main_food.current_ratio, Some(1.0));
        assert!(main_food.ema_score.is_some());
    }

    #[test]
    fn diet_trend_summary_excludes_abnormal_and_medical_samples_from_baseline() {
        let mut samples = (1..=13)
            .map(|day| {
                dated_sample(
                    FoodInventoryCategory::MainFood,
                    "正常",
                    true,
                    2026,
                    7,
                    day,
                    "healthy",
                )
            })
            .collect::<Vec<_>>();
        samples.push(dated_sample(
            FoodInventoryCategory::MainFood,
            "多一点",
            true,
            2026,
            7,
            14,
            "abnormal",
        ));
        samples.push(dated_sample(
            FoodInventoryCategory::MainFood,
            "少一点",
            true,
            2026,
            7,
            15,
            "medical",
        ));

        let summary = build_diet_trend_summary(&samples, 30);
        let main_food = summary
            .segments
            .iter()
            .find(|segment| segment.category == "main_food")
            .expect("main food segment");

        assert_eq!(main_food.baseline_score, None);
        assert_eq!(main_food.baseline_sample_days, 13);
        assert_eq!(summary.health_context.excluded_sample_count, 2);
        assert!(
            summary
                .health_context
                .excluded_reasons
                .contains(&"abnormal".to_owned())
        );
        assert!(
            summary
                .health_context
                .excluded_reasons
                .contains(&"medical".to_owned())
        );
    }

    fn sample(
        category: FoodInventoryCategory,
        amount_text: &str,
        has_food_item: bool,
    ) -> DietTrendFeedingSample {
        DietTrendFeedingSample {
            category,
            amount_text: amount_text.to_owned(),
            occurred_at: Utc.with_ymd_and_hms(2026, 7, 4, 8, 0, 0).unwrap(),
            has_food_item,
            has_inventory_snapshot: has_food_item,
            health_context: "healthy".to_owned(),
        }
    }

    fn dated_sample(
        category: FoodInventoryCategory,
        amount_text: &str,
        has_food_item: bool,
        year: i32,
        month: u32,
        day: u32,
        health_context: &str,
    ) -> DietTrendFeedingSample {
        DietTrendFeedingSample {
            category,
            amount_text: amount_text.to_owned(),
            occurred_at: Utc.with_ymd_and_hms(year, month, day, 8, 0, 0).unwrap(),
            has_food_item,
            has_inventory_snapshot: has_food_item,
            health_context: health_context.to_owned(),
        }
    }
}
