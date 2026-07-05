use uuid::Uuid;

/// DietInventoryAttentionCandidate 饮食库存提醒候选
/// 核心职责：
/// - 承载饮食库存算法输出的可提醒信号
/// - 让首页只消费候选结果，不参与算法判断
#[derive(Debug, Clone, PartialEq)]
pub struct DietInventoryAttentionCandidate {
    pub food_item_id: Uuid,
    pub prompt_kind: String,
    pub title: String,
    pub subtitle: String,
    pub priority: i32,
    pub remaining_ratio: f64,
}

/// DietInventoryCycleCheckSample 饮食库存周期检查样本
/// 核心职责：
/// - 表达用户已处理“还在吃”的轻提醒事实
/// - 为首个周期确认提醒提供后端冷却依据
#[derive(Debug, Clone, PartialEq)]
pub struct DietInventoryCycleCheckSample {
    pub food_item_id: Uuid,
    pub checked_at: chrono::DateTime<chrono::Utc>,
}
