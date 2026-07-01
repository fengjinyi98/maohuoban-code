// fact_package_diet_hints 饮食事实包强弱分离测试
// 核心职责：
// - 验证当前主粮/喂食进入 strong facts
// - 验证待确认事实进入 pending_confirmations，不与强事实混合
// - 验证储物柜变化只进入 weak_hints / missing_info，不进入 strong facts
// - 遵循 TDD：先写失败测试（red），再实现事实包构建器（green）

use maohuoban_ai_application::ai::context::AiFactPackageBuilder;
use maohuoban_ai_domain::ai::{
    AiCitation, AiCitationSourceKind, AiFactEntry, AiFactStrength, AiPetCandidate,
};
use uuid::Uuid;

fn candidate(name: &str) -> AiPetCandidate {
    AiPetCandidate {
        pet_id: Uuid::new_v4(),
        name: name.to_owned(),
        avatar_url: None,
        species: "cat".to_owned(),
        profile_number: "P001".to_owned(),
    }
}

#[test]
fn food_inventory_hint_does_not_enter_strong_facts() {
    let pet = candidate("毛球");
    let mut builder = AiFactPackageBuilder::new(&pet);

    let hint_citation_id = Uuid::new_v4();
    builder.add_weak_hint(AiFactEntry {
        key: "inventory_new_food".to_owned(),
        value: "新增主粮: 渴望六种鱼".to_owned(),
        strength: AiFactStrength::Weak,
        citation_id: Some(hint_citation_id),
    });
    builder.add_citation(AiCitation {
        source_kind: AiCitationSourceKind::FoodInventoryHint,
        source_id: hint_citation_id,
        label: "储物柜新增".to_owned(),
    });
    builder.add_missing_info("尚未配置当前主粮".to_owned());

    let package = builder.build();

    assert!(
        package.strong_fact_values().is_empty(),
        "weak hint should not appear in strong facts"
    );
    assert_eq!(package.weak_hint_values(), vec!["新增主粮: 渴望六种鱼"]);
    assert!(package.missing_info.iter().any(|m| m.contains("主粮")));
    assert_eq!(package.fact_strength, AiFactStrength::Weak);
}

#[test]
fn confirmed_diet_facts_enter_strong_facts() {
    let pet = candidate("毛球");
    let mut builder = AiFactPackageBuilder::new(&pet);

    let citation_id = Uuid::new_v4();
    builder.add_strong_fact(AiFactEntry {
        key: "current_staple".to_owned(),
        value: "渴望六种鱼".to_owned(),
        strength: AiFactStrength::Strong,
        citation_id: Some(citation_id),
    });
    builder.add_citation(AiCitation {
        source_kind: AiCitationSourceKind::DietAssignment,
        source_id: citation_id,
        label: "当前主粮".to_owned(),
    });

    let package = builder.build();

    assert_eq!(package.strong_fact_values(), vec!["渴望六种鱼"]);
    assert!(package.weak_hint_values().is_empty());
    assert_eq!(package.fact_strength, AiFactStrength::Strong);
}

#[test]
fn mixed_strong_and_weak_facts_separate_correctly() {
    let pet = candidate("毛球");
    let mut builder = AiFactPackageBuilder::new(&pet);

    let strong_id = Uuid::new_v4();
    builder.add_strong_fact(AiFactEntry {
        key: "current_staple".to_owned(),
        value: "渴望六种鱼".to_owned(),
        strength: AiFactStrength::Strong,
        citation_id: Some(strong_id),
    });

    let weak_id = Uuid::new_v4();
    builder.add_weak_hint(AiFactEntry {
        key: "inventory_hint".to_owned(),
        value: "新增零食".to_owned(),
        strength: AiFactStrength::Weak,
        citation_id: Some(weak_id),
    });

    let pending_id = Uuid::new_v4();
    builder.add_pending_confirmation(AiFactEntry {
        key: "diet_change_candidate".to_owned(),
        value: "待确认换粮".to_owned(),
        strength: AiFactStrength::PendingConfirmation,
        citation_id: Some(pending_id),
    });

    let package = builder.build();

    assert_eq!(package.strong_fact_values(), vec!["渴望六种鱼"]);
    assert_eq!(package.weak_hint_values(), vec!["新增零食"]);
    assert_eq!(package.facts.len(), 1); // 只有强事实在 facts 桶
    assert_eq!(package.pending_confirmations.len(), 1); // 待确认在独立桶
    assert_eq!(package.weak_hints.len(), 1);
    // 整体强度为强（有强事实时提升）
    assert_eq!(package.fact_strength, AiFactStrength::Strong);
}
