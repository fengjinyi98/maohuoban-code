use maohuoban_home_domain::home::{
    AttentionHint, AttentionHintCreator, AttentionHintKind, AttentionHintRoute,
    AttentionHintRouteKind, AttentionHintStatus, AttentionHintTone,
};
use maohuoban_pet_domain::pet::DietInventoryAttentionCandidate;
use uuid::Uuid;

/// `home_attention_hints` 聚合首页轻提醒
/// 核心职责：
/// - 汇总饮食算法候选和持久化轻提醒
/// - 只做首页 `AttentionHint` 映射，不参与业务算法
pub fn home_attention_hints(
    pet_id: Uuid,
    diet_inventory_candidates: &[DietInventoryAttentionCandidate],
    stored_attention_hints: &mut Vec<AttentionHint>,
) -> Vec<AttentionHint> {
    let mut hints = diet_inventory_candidates
        .iter()
        .map(|candidate| diet_inventory_attention_hint(pet_id, candidate))
        .collect::<Vec<_>>();
    hints.append(stored_attention_hints);
    hints
}

fn diet_inventory_attention_hint(
    pet_id: Uuid,
    candidate: &DietInventoryAttentionCandidate,
) -> AttentionHint {
    let now = chrono::Utc::now();
    AttentionHint {
        id: Uuid::new_v4(),
        pet_id,
        kind: AttentionHintKind::FeedingPatternChanged,
        title: candidate.title.clone(),
        subtitle: candidate.subtitle.clone(),
        icon: "takeoutbag.and.cup.and.straw.fill".to_owned(),
        tone: AttentionHintTone::Notice,
        priority: candidate.priority,
        status: AttentionHintStatus::Active,
        source_ref_type: Some("food_inventory_item".to_owned()),
        source_ref_id: Some(candidate.food_item_id),
        route: AttentionHintRoute {
            kind: AttentionHintRouteKind::PantryItemDetail,
            payload: Some(serde_json::json!({
                "food_item_id": candidate.food_item_id,
                "inventory_prompt_kind": candidate.prompt_kind
            })),
        },
        display_from: None,
        display_until: None,
        created_by: AttentionHintCreator::BusinessRule,
        created_at: now,
        updated_at: now,
        resolved_at: None,
    }
}
