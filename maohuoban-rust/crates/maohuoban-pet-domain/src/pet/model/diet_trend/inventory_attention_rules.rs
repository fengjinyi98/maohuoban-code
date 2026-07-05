use std::collections::HashMap;

use uuid::Uuid;

use crate::pet::{
    DietInventoryAttentionCandidate, DietInventoryConsumptionCycleSample,
    DietInventoryCycleCheckSample, DietTrendFeedingSample, FoodInventoryCategory,
    FoodInventoryItem,
};

const LOW_REMAINING_SCORE_RATIO: f64 = 0.2;
const FIRST_CYCLE_MIN_ACTIVE_DAYS: usize = 7;
const FIRST_CYCLE_MIN_TOTAL_SCORE: f64 = 14.0;

/// build_diet_inventory_attention_candidates 生成饮食库存提醒候选
/// 核心职责：
/// - 基于喂食样本、库存规格和已确认消耗周期判断当前包装进度
/// - 使用完整消耗周期作为当前包装边界，避免确认后继续提示
#[must_use]
pub fn build_diet_inventory_attention_candidates(
    food_inventory_items: &[FoodInventoryItem],
    feeding_samples: &[DietTrendFeedingSample],
    consumption_cycles: &[DietInventoryConsumptionCycleSample],
    cycle_checks: &[DietInventoryCycleCheckSample],
) -> Vec<DietInventoryAttentionCandidate> {
    let samples_by_item_id = feeding_samples_by_item_id(feeding_samples);
    let cycles_by_item_id = consumption_cycles_by_item_id(consumption_cycles);
    let checked_item_ids = cycle_checks
        .iter()
        .map(|check| check.food_item_id)
        .collect::<std::collections::HashSet<_>>();

    food_inventory_items
        .iter()
        .filter_map(|item| {
            let samples = samples_by_item_id.get(&item.id)?;
            let cycles = cycles_by_item_id
                .get(&item.id)
                .map_or(&[][..], Vec::as_slice);
            let has_still_using_check = checked_item_ids.contains(&item.id);
            diet_inventory_attention_candidate_for_item(
                item,
                samples,
                cycles,
                has_still_using_check,
            )
        })
        .collect()
}

fn diet_inventory_attention_candidate_for_item(
    item: &FoodInventoryItem,
    samples: &[&DietTrendFeedingSample],
    cycles: &[&DietInventoryConsumptionCycleSample],
    has_still_using_check: bool,
) -> Option<DietInventoryAttentionCandidate> {
    if item.quantity <= 0
        || item.package_weight_grams.is_none()
        || !supports_inventory_attention(item.category)
    {
        return None;
    }

    if cycles.is_empty() {
        if has_still_using_check {
            return None;
        }
        return first_cycle_confirmation_candidate_for_item(item, samples);
    }

    let capacity = learned_cycle_score_capacity(samples, cycles)?;
    let current_cycle_score = current_cycle_score(samples, cycles);
    if current_cycle_score <= 0.0 {
        return None;
    }
    let remaining_ratio = ((capacity - current_cycle_score) / capacity).clamp(0.0, 1.0);
    if remaining_ratio > LOW_REMAINING_SCORE_RATIO {
        return None;
    }

    Some(DietInventoryAttentionCandidate {
        food_item_id: item.id,
        prompt_kind: "low_inventory".to_owned(),
        title: format!("{}可能快吃完了", item.name),
        subtitle: "确认后会更新库存和饮食趋势".to_owned(),
        priority: 40,
        remaining_ratio: round_two(remaining_ratio),
    })
}

fn first_cycle_confirmation_candidate_for_item(
    item: &FoodInventoryItem,
    samples: &[&DietTrendFeedingSample],
) -> Option<DietInventoryAttentionCandidate> {
    let active_days = active_day_count(samples);
    let total_score = samples
        .iter()
        .map(|sample| amount_score(&sample.amount_text))
        .sum::<f64>();
    if active_days < FIRST_CYCLE_MIN_ACTIVE_DAYS || total_score < FIRST_CYCLE_MIN_TOTAL_SCORE {
        return None;
    }

    Some(DietInventoryAttentionCandidate {
        food_item_id: item.id,
        prompt_kind: "cycle_confirmation".to_owned(),
        title: format!("确认{}是否吃完一袋", item.name),
        subtitle: "确认后会开始校准饮食趋势".to_owned(),
        priority: 35,
        remaining_ratio: 1.0,
    })
}

fn active_day_count(samples: &[&DietTrendFeedingSample]) -> usize {
    samples
        .iter()
        .map(|sample| sample.occurred_at.date_naive())
        .collect::<std::collections::HashSet<_>>()
        .len()
}

fn feeding_samples_by_item_id(
    feeding_samples: &[DietTrendFeedingSample],
) -> HashMap<Uuid, Vec<&DietTrendFeedingSample>> {
    let mut samples_by_item_id: HashMap<Uuid, Vec<&DietTrendFeedingSample>> = HashMap::new();
    for sample in feeding_samples {
        let Some(food_item_id) = sample.food_item_id else {
            continue;
        };
        samples_by_item_id
            .entry(food_item_id)
            .or_default()
            .push(sample);
    }
    samples_by_item_id
}

fn consumption_cycles_by_item_id(
    consumption_cycles: &[DietInventoryConsumptionCycleSample],
) -> HashMap<Uuid, Vec<&DietInventoryConsumptionCycleSample>> {
    let mut cycles_by_item_id: HashMap<Uuid, Vec<&DietInventoryConsumptionCycleSample>> =
        HashMap::new();
    for cycle in consumption_cycles {
        cycles_by_item_id
            .entry(cycle.food_item_id)
            .or_default()
            .push(cycle);
    }
    for cycles in cycles_by_item_id.values_mut() {
        cycles.sort_by_key(|cycle| cycle.confirmed_at);
    }
    cycles_by_item_id
}

fn learned_cycle_score_capacity(
    samples: &[&DietTrendFeedingSample],
    cycles: &[&DietInventoryConsumptionCycleSample],
) -> Option<f64> {
    let mut previous_confirmed_at = None;
    let mut completed_cycle_scores = Vec::new();
    for cycle in cycles {
        let score = samples
            .iter()
            .filter(|sample| {
                previous_confirmed_at.is_none_or(|confirmed_at| sample.occurred_at > confirmed_at)
                    && sample.occurred_at <= cycle.confirmed_at
            })
            .map(|sample| amount_score(&sample.amount_text))
            .sum::<f64>();
        previous_confirmed_at = Some(cycle.confirmed_at);
        if score > 0.0 {
            completed_cycle_scores.push(score);
        }
    }
    if completed_cycle_scores.is_empty() {
        return None;
    }
    Some(median_score(&mut completed_cycle_scores))
}

fn current_cycle_score(
    samples: &[&DietTrendFeedingSample],
    cycles: &[&DietInventoryConsumptionCycleSample],
) -> f64 {
    let latest_confirmed_at = cycles.iter().map(|cycle| cycle.confirmed_at).max();
    samples
        .iter()
        .filter(|sample| {
            latest_confirmed_at.is_none_or(|confirmed_at| sample.occurred_at > confirmed_at)
        })
        .map(|sample| amount_score(&sample.amount_text))
        .sum()
}

fn supports_inventory_attention(category: FoodInventoryCategory) -> bool {
    matches!(
        category,
        FoodInventoryCategory::MainFood
            | FoodInventoryCategory::WetFood
            | FoodInventoryCategory::Treats
            | FoodInventoryCategory::Nutrition
            | FoodInventoryCategory::Other
    )
}

fn amount_score(amount_text: &str) -> f64 {
    match amount_text.trim() {
        "少一点" => 0.75,
        "多一点" => 1.25,
        _ => 1.0,
    }
}

fn median_score(scores: &mut [f64]) -> f64 {
    scores.sort_by(f64::total_cmp);
    let middle = scores.len() / 2;
    if scores.len().is_multiple_of(2) {
        f64::midpoint(scores[middle - 1], scores[middle])
    } else {
        scores[middle]
    }
}

fn round_two(value: f64) -> f64 {
    (value * 100.0).round() / 100.0
}

#[cfg(test)]
mod tests {
    use chrono::{Duration, TimeZone, Utc};

    use super::*;
    use crate::pet::{FoodInventoryStatus, FoodScopeType, FoodSourceKind};

    #[test]
    fn inventory_attention_learns_capacity_from_each_item_completed_cycle() {
        let pet_food_id = Uuid::new_v4();
        let cat_food_id = Uuid::new_v4();
        let items = vec![
            food_item(
                pet_food_id,
                "小容量主粮",
                FoodInventoryCategory::MainFood,
                2,
            ),
            food_item(
                cat_food_id,
                "大容量主粮",
                FoodInventoryCategory::MainFood,
                2,
            ),
        ];
        let mut samples = Vec::new();
        samples.extend(feeding_sample_days(
            pet_food_id,
            FoodInventoryCategory::MainFood,
            1..=20,
            2026,
            5,
        ));
        samples.extend(feeding_sample_days(
            pet_food_id,
            FoodInventoryCategory::MainFood,
            1..=17,
            2026,
            6,
        ));
        samples.extend(feeding_sample_count(
            cat_food_id,
            FoodInventoryCategory::MainFood,
            60,
            Utc.with_ymd_and_hms(2026, 5, 1, 8, 0, 0).unwrap(),
        ));
        samples.extend(feeding_sample_count(
            cat_food_id,
            FoodInventoryCategory::MainFood,
            40,
            Utc.with_ymd_and_hms(2026, 6, 1, 8, 0, 0).unwrap(),
        ));
        let cycles = vec![
            consumption_cycle(pet_food_id, 2026, 5, 21),
            consumption_cycle(cat_food_id, 2026, 5, 31),
        ];

        let candidates = build_diet_inventory_attention_candidates(&items, &samples, &cycles, &[]);

        assert_eq!(candidates.len(), 1);
        assert_eq!(candidates[0].food_item_id, pet_food_id);
        assert_approx_eq(candidates[0].remaining_ratio, 0.15);
    }

    #[test]
    fn inventory_attention_clears_after_current_package_is_confirmed_consumed() {
        let food_item_id = Uuid::new_v4();
        let item = food_item(
            food_item_id,
            "高爷家益生菌猫粮",
            FoodInventoryCategory::MainFood,
            1,
        );
        let mut samples = feeding_sample_count(
            food_item_id,
            FoodInventoryCategory::MainFood,
            60,
            Utc.with_ymd_and_hms(2026, 5, 1, 8, 0, 0).unwrap(),
        );
        samples.extend(feeding_sample_count(
            food_item_id,
            FoodInventoryCategory::MainFood,
            50,
            Utc.with_ymd_and_hms(2026, 6, 1, 8, 0, 0).unwrap(),
        ));
        let cycles = vec![
            consumption_cycle(food_item_id, 2026, 5, 31),
            consumption_cycle(food_item_id, 2026, 6, 26),
        ];

        let candidates = build_diet_inventory_attention_candidates(&[item], &samples, &cycles, &[]);

        assert!(candidates.is_empty());
    }

    #[test]
    fn inventory_attention_supports_wet_food_when_cycle_evidence_exists() {
        let food_item_id = Uuid::new_v4();
        let item = food_item(food_item_id, "主食罐", FoodInventoryCategory::WetFood, 12);
        let mut samples = feeding_sample_days(
            food_item_id,
            FoodInventoryCategory::WetFood,
            1..=12,
            2026,
            5,
        );
        samples.extend(feeding_sample_days(
            food_item_id,
            FoodInventoryCategory::WetFood,
            1..=10,
            2026,
            6,
        ));
        let cycles = vec![consumption_cycle(food_item_id, 2026, 5, 13)];

        let candidates = build_diet_inventory_attention_candidates(&[item], &samples, &cycles, &[]);

        assert_eq!(candidates.len(), 1);
        assert_eq!(candidates[0].food_item_id, food_item_id);
        assert_approx_eq(candidates[0].remaining_ratio, 0.17);
    }

    #[test]
    fn inventory_attention_prompts_cycle_confirmation_without_completed_cycle() {
        let food_item_id = Uuid::new_v4();
        let item = food_item(
            food_item_id,
            "高爷家益生菌猫粮",
            FoodInventoryCategory::MainFood,
            2,
        );
        let samples = feeding_sample_days(
            food_item_id,
            FoodInventoryCategory::MainFood,
            1..=14,
            2026,
            7,
        );

        let candidates = build_diet_inventory_attention_candidates(&[item], &samples, &[], &[]);

        assert_eq!(candidates.len(), 1);
        assert_eq!(candidates[0].food_item_id, food_item_id);
        assert_eq!(candidates[0].title, "确认高爷家益生菌猫粮是否吃完一袋");
        assert_eq!(candidates[0].prompt_kind, "cycle_confirmation");
    }

    #[test]
    fn inventory_attention_does_not_prompt_cycle_confirmation_for_single_touch() {
        let food_item_id = Uuid::new_v4();
        let item = food_item(food_item_id, "主食罐", FoodInventoryCategory::WetFood, 12);
        let samples =
            feeding_sample_days(food_item_id, FoodInventoryCategory::WetFood, 1..=1, 2026, 7);

        let candidates = build_diet_inventory_attention_candidates(&[item], &samples, &[], &[]);

        assert!(candidates.is_empty());
    }

    fn assert_approx_eq(actual: f64, expected: f64) {
        assert!(
            (actual - expected).abs() < f64::EPSILON,
            "expected {expected}, got {actual}"
        );
    }

    fn food_item(
        id: Uuid,
        name: &str,
        category: FoodInventoryCategory,
        quantity: i32,
    ) -> FoodInventoryItem {
        let now = Utc.with_ymd_and_hms(2026, 7, 4, 8, 0, 0).unwrap();
        FoodInventoryItem {
            id,
            scope_type: FoodScopeType::User,
            scope_id: Uuid::new_v4(),
            created_by_user_id: Uuid::new_v4(),
            name: name.to_owned(),
            brand: None,
            category,
            inventory_status: FoodInventoryStatus::InUse,
            quantity,
            unit: Some("袋".to_owned()),
            spec: Some("1.5kg".to_owned()),
            package_weight_grams: Some(1_500),
            package_count: 1,
            package_unit: Some("袋".to_owned()),
            production_date: None,
            shelf_life_months: None,
            expiry_date: None,
            cover_asset_id: None,
            cover_url: None,
            barcode: None,
            source_kind: FoodSourceKind::Manual,
            note: None,
            created_at: now,
            updated_at: now,
            archived_at: None,
        }
    }

    fn feeding_sample_days(
        food_item_id: Uuid,
        category: FoodInventoryCategory,
        days: std::ops::RangeInclusive<u32>,
        year: i32,
        month: u32,
    ) -> Vec<DietTrendFeedingSample> {
        days.map(|day| DietTrendFeedingSample {
            category,
            amount_text: "正常".to_owned(),
            occurred_at: Utc.with_ymd_and_hms(year, month, day, 8, 0, 0).unwrap(),
            food_item_id: Some(food_item_id),
            package_weight_grams: Some(1_500),
            inventory_status: Some(FoodInventoryStatus::InUse),
            has_food_item: true,
            has_inventory_snapshot: true,
            health_context: "healthy".to_owned(),
        })
        .collect()
    }

    fn feeding_sample_count(
        food_item_id: Uuid,
        category: FoodInventoryCategory,
        count: i64,
        start_at: chrono::DateTime<Utc>,
    ) -> Vec<DietTrendFeedingSample> {
        (0..count)
            .map(|index| DietTrendFeedingSample {
                category,
                amount_text: "正常".to_owned(),
                occurred_at: start_at + Duration::hours(index),
                food_item_id: Some(food_item_id),
                package_weight_grams: Some(1_500),
                inventory_status: Some(FoodInventoryStatus::InUse),
                has_food_item: true,
                has_inventory_snapshot: true,
                health_context: "healthy".to_owned(),
            })
            .collect()
    }

    fn consumption_cycle(
        food_item_id: Uuid,
        year: i32,
        month: u32,
        day: u32,
    ) -> DietInventoryConsumptionCycleSample {
        DietInventoryConsumptionCycleSample {
            food_item_id,
            package_weight_grams: Some(1_500),
            confirmed_at: Utc.with_ymd_and_hms(year, month, day, 20, 0, 0).unwrap(),
        }
    }
}
