use chrono::{DateTime, Utc};

use crate::pet::FoodInventoryCategory;

/// DietTrendFeedingSample 饮食趋势喂食样本
/// 核心职责：
/// - 承载事件账本中的可分析喂食事实
/// - 将持久化事件与饮食趋势纯规则解耦
#[derive(Debug, Clone, PartialEq)]
pub struct DietTrendFeedingSample {
    pub category: FoodInventoryCategory,
    pub amount_text: String,
    pub occurred_at: DateTime<Utc>,
    pub has_food_item: bool,
    pub has_inventory_snapshot: bool,
}
