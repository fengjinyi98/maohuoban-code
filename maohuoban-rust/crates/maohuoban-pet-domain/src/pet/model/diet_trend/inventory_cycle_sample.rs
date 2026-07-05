use chrono::{DateTime, Utc};
use uuid::Uuid;

/// DietInventoryConsumptionCycleSample 饮食库存消耗周期样本
/// 核心职责：
/// - 表达用户确认吃完一个库存包装单位的事实
/// - 为当前包装周期进度算法提供周期边界
#[derive(Debug, Clone, PartialEq)]
pub struct DietInventoryConsumptionCycleSample {
    pub food_item_id: Uuid,
    pub package_weight_grams: Option<i32>,
    pub confirmed_at: DateTime<Utc>,
}
