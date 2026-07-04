use std::collections::{BTreeMap, BTreeSet, HashMap};

use chrono::NaiveDate;

use uuid::Uuid;

use crate::pet::{FoodInventoryCategory, FoodInventoryStatus};

use super::{
    DietTrendAnalysis, DietTrendCalibration, DietTrendConfidence, DietTrendExplanation,
    DietTrendFeedingSample, DietTrendHealthContext, DietTrendSegment, DietTrendSummary,
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
        (FoodInventoryCategory::Other, 0.0),
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
    let calibration = build_calibration(&included_samples);
    let analysis = build_analysis(
        window_days,
        total_score,
        &segments,
        &health_context,
        &calibration,
    );

    DietTrendSummary {
        window_days,
        status,
        segments,
        confidence,
        health_context,
        calibration,
        analysis,
        explanation: DietTrendExplanation {
            title: "饮食趋势是怎么生成的".to_owned(),
            body: "我们会结合喂食记录、储物柜食品分类和库存引用生成饮食趋势。记录越连续、食品引用越完整，趋势参考价值越高。当前结果用于日常观察，不等同于精准称重或诊断结论。".to_owned(),
        },
    }
}

fn build_calibration(samples: &[&DietTrendFeedingSample]) -> DietTrendCalibration {
    let Some(cycle) = completed_cycle_calibration(samples) else {
        return DietTrendCalibration {
            confidence: "low".to_owned(),
            grams_per_score: None,
            daily_grams: None,
            reason: "还没有形成可验证的库存消耗闭环，当前只输出相对趋势。".to_owned(),
        };
    };

    DietTrendCalibration {
        confidence: if cycle.cycle_count >= 2 {
            "high".to_owned()
        } else {
            "medium".to_owned()
        },
        grams_per_score: Some(cycle.grams_per_score),
        daily_grams: Some(cycle.daily_grams),
        reason: format!(
            "已根据 {} 个完整库存消耗周期估算：{}g / {:.2} score。",
            cycle.cycle_count, cycle.total_grams, cycle.total_score
        ),
    }
}

#[derive(Debug, Clone, Copy)]
struct CompletedCycleCalibration {
    cycle_count: usize,
    total_grams: i32,
    total_score: f64,
    grams_per_score: f64,
    daily_grams: f64,
}

fn completed_cycle_calibration(
    samples: &[&DietTrendFeedingSample],
) -> Option<CompletedCycleCalibration> {
    let mut cycles: HashMap<Uuid, CompletedCycleAccumulator> = HashMap::new();
    for sample in samples {
        if !is_baseline_health_context(&sample.health_context) {
            continue;
        }
        if sample.inventory_status != Some(FoodInventoryStatus::Depleted) {
            continue;
        }
        let food_item_id = sample.food_item_id?;
        let package_weight_grams = sample.package_weight_grams?;
        if package_weight_grams <= 0 {
            continue;
        }
        let cycle = cycles
            .entry(food_item_id)
            .or_insert(CompletedCycleAccumulator {
                package_weight_grams,
                total_score: 0.0,
                active_days: BTreeSet::new(),
            });
        if cycle.package_weight_grams != package_weight_grams {
            continue;
        }
        cycle.total_score += amount_score(&sample.amount_text);
        cycle.active_days.insert(sample.occurred_at.date_naive());
    }

    let completed_cycles = cycles
        .values()
        .filter(|cycle| cycle.total_score > 0.0 && !cycle.active_days.is_empty())
        .collect::<Vec<_>>();
    if completed_cycles.is_empty() {
        return None;
    }

    let total_grams = completed_cycles
        .iter()
        .map(|cycle| cycle.package_weight_grams)
        .sum::<i32>();
    let total_score = completed_cycles
        .iter()
        .map(|cycle| cycle.total_score)
        .sum::<f64>();
    let active_day_count = completed_cycles
        .iter()
        .map(|cycle| cycle.active_days.len())
        .sum::<usize>();
    if total_grams <= 0 || total_score <= 0.0 || active_day_count == 0 {
        return None;
    }

    let grams_per_score = f64::from(total_grams) / total_score;
    let daily_average_score = total_score / count_to_f64(active_day_count);
    Some(CompletedCycleCalibration {
        cycle_count: completed_cycles.len(),
        total_grams,
        total_score: round_two(total_score),
        grams_per_score: round_two(grams_per_score),
        daily_grams: round_two(daily_average_score * grams_per_score),
    })
}

#[derive(Debug, Clone)]
struct CompletedCycleAccumulator {
    package_weight_grams: i32,
    total_score: f64,
    active_days: BTreeSet<NaiveDate>,
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

fn build_analysis(
    window_days: i64,
    total_score: f64,
    segments: &[DietTrendSegment],
    health_context: &DietTrendHealthContext,
    calibration: &DietTrendCalibration,
) -> DietTrendAnalysis {
    if total_score == 0.0 {
        return DietTrendAnalysis {
            headline: format!("近 {window_days} 天还没有可分析饮食记录"),
            summary: "继续记录喂食后，会开始形成饮食结构和个体习惯参考。".to_owned(),
            observations: vec!["当前样本不足，只展示记录，不做趋势判断。".to_owned()],
        };
    }

    let active_segments = segments
        .iter()
        .filter(|segment| segment.percentage > 0)
        .collect::<Vec<_>>();
    let leading = active_segments
        .first()
        .map_or("饮食记录".to_owned(), |segment| {
            format!("{}占比最高", segment.title)
        });
    let structure = active_segments
        .iter()
        .take(4)
        .map(|segment| format!("{} {}%", segment.title, segment.percentage))
        .collect::<Vec<_>>()
        .join("，");
    let baseline_titles = segments
        .iter()
        .filter(|segment| segment.baseline_score.is_some())
        .map(|segment| segment.title.clone())
        .collect::<Vec<_>>();

    let headline = if baseline_titles.is_empty() {
        format!("近 {window_days} 天正在积累饮食样本")
    } else {
        format!("近 {window_days} 天已形成饮食结构参考")
    };
    let summary = if structure.is_empty() {
        format!("{leading}，当前已开始形成饮食结构。")
    } else {
        format!("{leading}，当前结构为{structure}。")
    };

    let mut observations = Vec::new();
    if baseline_titles.is_empty() {
        observations.push("健康记录还在积累中，暂时只做结构观察。".to_owned());
    } else {
        observations.push(format!(
            "{}已形成个体习惯参考，后续会持续观察是否偏离自身习惯。",
            baseline_titles.join("、")
        ));
    }
    if health_context.excluded_sample_count == 0 {
        observations.push("当前没有异常或就医期喂食样本参与对照。".to_owned());
    } else {
        observations.push(format!(
            "{} 条异常或就医期样本已单独保留，没有进入健康基线。",
            health_context.excluded_sample_count
        ));
    }
    if calibration.daily_grams.is_some() {
        observations.push("已形成完整库存消耗闭环，可输出日均克数估算。".to_owned());
    } else {
        observations.push("还没有形成完整库存消耗闭环，暂不输出克数估算。".to_owned());
    }

    DietTrendAnalysis {
        headline,
        summary,
        observations,
    }
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
    if !supports_category_baseline(category) {
        return Vec::new();
    }
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
            | FoodInventoryCategory::Other
    )
}

fn supports_category_baseline(category: FoodInventoryCategory) -> bool {
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
    use uuid::Uuid;

    use crate::pet::FoodInventoryStatus;

    use super::*;

    #[test]
    fn diet_trend_summary_excludes_non_food_categories() {
        let samples = vec![
            sample(FoodInventoryCategory::MainFood, "正常", true),
            sample(FoodInventoryCategory::Other, "正常", true),
            sample(FoodInventoryCategory::CatLitter, "正常", true),
            sample(FoodInventoryCategory::Medicine, "正常", true),
        ];

        let summary = build_diet_trend_summary(&samples, 7);

        assert_eq!(summary.segments[0].percentage, 50);
        assert_eq!(summary.segments[1].percentage, 0);
        assert_eq!(summary.segments[2].percentage, 0);
        assert_eq!(summary.segments[3].percentage, 0);
        assert_eq!(summary.segments[4].category, "other");
        assert_eq!(summary.segments[4].percentage, 50);
        assert_eq!(summary.segments[4].baseline_score, None);
        assert_eq!(summary.segments[4].baseline_sample_days, 0);
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
    fn diet_trend_summary_exposes_user_readable_analysis() {
        let mut samples = Vec::new();
        for day in 1..=14 {
            samples.push(dated_sample(
                FoodInventoryCategory::MainFood,
                "正常",
                true,
                2026,
                7,
                day,
                "healthy",
            ));
            samples.push(dated_sample(
                FoodInventoryCategory::WetFood,
                "正常",
                true,
                2026,
                7,
                day,
                "healthy",
            ));
        }

        let summary = build_diet_trend_summary(&samples, 30);

        assert_eq!(summary.analysis.headline, "近 30 天已形成饮食结构参考");
        assert!(summary.analysis.summary.contains("主粮"));
        assert!(summary.analysis.summary.contains("湿粮/罐头"));
        assert!(
            summary
                .analysis
                .observations
                .iter()
                .any(|item| item.contains("已形成个体习惯参考"))
        );
        assert!(
            summary
                .analysis
                .observations
                .iter()
                .any(|item| item.contains("暂不输出克数估算"))
        );
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

    #[test]
    fn diet_trend_summary_calibrates_grams_from_completed_inventory_cycle() {
        let food_item_id = Uuid::new_v4();
        let samples = (1..=30)
            .flat_map(|day| {
                [
                    completed_cycle_sample(food_item_id, day, "正常"),
                    completed_cycle_sample(food_item_id, day, "正常"),
                ]
            })
            .collect::<Vec<_>>();

        let summary = build_diet_trend_summary(&samples, 60);

        assert_eq!(summary.calibration.confidence, "medium");
        assert_eq!(summary.calibration.grams_per_score, Some(25.0));
        assert_eq!(summary.calibration.daily_grams, Some(50.0));
        assert!(summary.calibration.reason.contains("完整库存消耗周期"));
        assert!(
            summary
                .analysis
                .observations
                .iter()
                .any(|item| item.contains("已形成完整库存消耗闭环"))
        );
        assert!(
            summary
                .analysis
                .observations
                .iter()
                .all(|item| !item.contains("暂不输出克数估算"))
        );
    }

    #[test]
    fn diet_trend_summary_cross_validates_multiple_completed_cycles() {
        let first_food_item_id = Uuid::new_v4();
        let second_food_item_id = Uuid::new_v4();
        let mut samples = Vec::new();
        for day in 1..=30 {
            samples.push(dated_completed_cycle_sample(
                first_food_item_id,
                2026,
                5,
                day,
                "正常",
            ));
            samples.push(dated_completed_cycle_sample(
                first_food_item_id,
                2026,
                5,
                day,
                "正常",
            ));
            samples.push(dated_completed_cycle_sample(
                second_food_item_id,
                2026,
                6,
                day,
                "少一点",
            ));
            samples.push(dated_completed_cycle_sample(
                second_food_item_id,
                2026,
                6,
                day,
                "少一点",
            ));
        }

        let summary = build_diet_trend_summary(&samples, 60);

        assert_eq!(summary.calibration.confidence, "high");
        assert_eq!(summary.calibration.grams_per_score, Some(28.57));
        assert_eq!(summary.calibration.daily_grams, Some(50.0));
        assert!(summary.calibration.reason.contains("2 个完整库存消耗周期"));
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
            food_item_id: has_food_item.then(Uuid::new_v4),
            package_weight_grams: None,
            inventory_status: None,
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
            food_item_id: has_food_item.then(Uuid::new_v4),
            package_weight_grams: None,
            inventory_status: None,
            has_food_item,
            has_inventory_snapshot: has_food_item,
            health_context: health_context.to_owned(),
        }
    }

    fn completed_cycle_sample(
        food_item_id: Uuid,
        day: u32,
        amount_text: &str,
    ) -> DietTrendFeedingSample {
        dated_completed_cycle_sample(food_item_id, 2026, 6, day, amount_text)
    }

    fn dated_completed_cycle_sample(
        food_item_id: Uuid,
        year: i32,
        month: u32,
        day: u32,
        amount_text: &str,
    ) -> DietTrendFeedingSample {
        DietTrendFeedingSample {
            category: FoodInventoryCategory::MainFood,
            amount_text: amount_text.to_owned(),
            occurred_at: Utc.with_ymd_and_hms(year, month, day, 8, 0, 0).unwrap(),
            food_item_id: Some(food_item_id),
            package_weight_grams: Some(1500),
            inventory_status: Some(FoodInventoryStatus::Depleted),
            has_food_item: true,
            has_inventory_snapshot: true,
            health_context: "healthy".to_owned(),
        }
    }
}
