use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// FeedingPayload 喂食事件载荷
/// 核心职责：
/// - 在 pet_events.event_payload 中记录喂食详细数据
/// - 保存 food_item_id 和当时食品快照以对抗后续编辑
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct FeedingPayload {
    pub food_item_id: Option<Uuid>,
    pub food_role: String,
    pub amount_text: String,
    pub food_snapshot: Option<FoodSnapshot>,
    pub is_default_food: bool,
    pub note: Option<String>,
    pub attachment_asset_ids: Vec<Uuid>,
}

/// FoodSnapshot 喂食时的食品快照
/// 核心职责：
/// - 保留喂食时刻的食品名称、品牌、分类、规格和封面
/// - 不受后续食品资产编辑影响
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct FoodSnapshot {
    pub name: String,
    pub brand: Option<String>,
    pub category: String,
    pub spec: Option<String>,
    pub package_weight_grams: Option<i32>,
    pub package_count: Option<i32>,
    pub package_unit: Option<String>,
    pub cover_asset_id: Option<Uuid>,
    pub cover_url: Option<String>,
}

/// DietChangePayload 饮食配置变更事件载荷
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct DietChangePayload {
    pub from_food_item_id: Option<Uuid>,
    pub to_food_item_id: Uuid,
    pub assignment_id: Uuid,
    pub transition_state: String,
    pub started_at: chrono::DateTime<chrono::Utc>,
    pub confirmed_by_user_id: Uuid,
}

/// FoodInventoryAddedPayload 储物柜新增食品事件载荷
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct FoodInventoryAddedPayload {
    pub food_item_id: Uuid,
    pub category: String,
    pub source_kind: String,
    pub scope_type: String,
    pub scope_id: Uuid,
}

/// AgentConfirmedFactPayload Agent 确认事实事件载荷
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct AgentConfirmedFactPayload {
    pub confirmed_fact_kind: String,
    pub linked_food_item_id: Option<Uuid>,
    pub linked_pet_id: Option<Uuid>,
    pub confidence: String,
    pub source_question: String,
}

/// FeedingCorrectionPayload 喂食修正确认事件载荷
/// 核心职责：
/// - 记录用户确认后的实际食品引用
/// - 关联 Agent 确认事实事件以保持追溯链路
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct FeedingCorrectionPayload {
    pub food_item_id: Uuid,
    pub linked_pet_id: Uuid,
    pub confirmed_event_id: Uuid,
    pub source_question: String,
    pub corrected_by_user_id: Uuid,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn feeding_payload_roundtrip() {
        let payload = FeedingPayload {
            food_item_id: Some(Uuid::new_v4()),
            food_role: "main_food".to_string(),
            amount_text: "正常".to_string(),
            food_snapshot: Some(FoodSnapshot {
                name: "六种鱼".to_string(),
                brand: Some("Orijen".to_string()),
                category: "main_food".to_string(),
                spec: Some("5.4kg".to_string()),
                package_weight_grams: Some(5400),
                package_count: Some(1),
                package_unit: Some("袋".to_string()),
                cover_asset_id: None,
                cover_url: None,
            }),
            is_default_food: true,
            note: Some("换新粮了".to_string()),
            attachment_asset_ids: vec![],
        };
        let json = serde_json::to_value(&payload).expect("serialize");
        let parsed: FeedingPayload = serde_json::from_value(json).expect("deserialize");
        assert_eq!(parsed.food_role, "main_food");
        assert!(parsed.is_default_food);
        assert_eq!(parsed.food_snapshot.unwrap().name, "六种鱼");
    }

    #[test]
    fn food_snapshot_immutable() {
        let snapshot = FoodSnapshot {
            name: "原始名称".to_string(),
            brand: Some("原始品牌".to_string()),
            category: "main_food".to_string(),
            spec: Some("5.4kg".to_string()),
            package_weight_grams: Some(5400),
            package_count: Some(1),
            package_unit: Some("袋".to_string()),
            cover_asset_id: None,
            cover_url: None,
        };
        let json = serde_json::to_string(&snapshot).expect("serialize");
        assert!(json.contains("原始名称"));
    }
}
