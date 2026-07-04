use crate::pet::FoodInventoryCategory;

use super::{
    DietTrendConfidence, DietTrendExplanation, DietTrendFeedingSample, DietTrendSegment,
    DietTrendSummary,
};

const LOW_CONFIDENCE_THRESHOLD: f64 = 0.35;
const MEDIUM_CONFIDENCE_THRESHOLD: f64 = 0.85;

/// build_diet_trend_summary 生成饮食趋势摘要
/// 核心职责：
/// - 对可分析饮食品类做分段占比计算
/// - 基于样本数量、连续性和库存证据生成动态置信度
#[must_use]
pub fn build_diet_trend_summary(
    samples: &[DietTrendFeedingSample],
    window_days: i64,
) -> DietTrendSummary {
    let mut category_scores = vec![
        (FoodInventoryCategory::MainFood, 0.0),
        (FoodInventoryCategory::WetFood, 0.0),
        (FoodInventoryCategory::Treats, 0.0),
        (FoodInventoryCategory::Nutrition, 0.0),
    ];

    let mut included_samples = Vec::new();
    for sample in samples {
        let Some((_, score)) = category_scores
            .iter_mut()
            .find(|(category, _)| *category == sample.category)
        else {
            continue;
        };
        *score += amount_score(&sample.amount_text);
        included_samples.push(sample);
    }

    let total_score: f64 = category_scores.iter().map(|(_, score)| score).sum();
    let segments = build_segments(category_scores, total_score);
    let confidence = build_confidence(&included_samples, window_days);
    let status = if total_score == 0.0 {
        "insufficient_data"
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
        explanation: DietTrendExplanation {
            title: "饮食趋势是怎么生成的".to_owned(),
            body: "我们会结合喂食记录、储物柜食品分类和库存引用生成饮食趋势。记录越连续、食品引用越完整，趋势参考价值越高。饮食趋势用于日常观察和就诊沟通参考，不构成诊断结论。".to_owned(),
        },
    }
}

fn build_segments(
    category_scores: Vec<(FoodInventoryCategory, f64)>,
    total_score: f64,
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
            }
        })
        .collect()
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
        }
    }
}
