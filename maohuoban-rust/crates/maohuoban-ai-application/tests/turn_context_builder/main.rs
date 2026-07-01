// turn_context_builder TurnContextBuilder 测试
// 核心职责：
// - 验证 TurnContextBuilder 把安全裁决、会话摘要、宠物上下文、能力目录、记忆包从 LoopEngine 中拆出
// - 验证 LoopEngine 只负责模型循环和工具回灌
// - 验证无宠物用户仍可进入公共宠物能力
// - 验证私域工具按授权宠物启用

use maohuoban_ai_application::ai::turn_context::TurnContextBuilder;
use maohuoban_ai_domain::ai::{
    AiConversationSurface, AiPetDisplaySnapshot, CapabilityDomain, MemoryEntry, MemoryScope,
};
use uuid::Uuid;

fn pet_id() -> Uuid {
    Uuid::parse_str("11111111-1111-1111-1111-111111111111").expect("pet id")
}

fn other_pet_id() -> Uuid {
    Uuid::parse_str("33333333-3333-3333-3333-333333333333").expect("other pet id")
}

fn target_pet() -> AiPetDisplaySnapshot {
    AiPetDisplaySnapshot {
        pet_id: pet_id(),
        pet_name: "豆包".to_owned(),
        pet_avatar_url: None,
        pet_species: "cat".to_owned(),
        profile_number: "MHB001".to_owned(),
    }
}

#[test]
fn builder_without_pet_produces_public_only_capabilities() {
    let workbench = TurnContextBuilder::new(AiConversationSurface::HomePrivate).build();

    assert!(!workbench.capability_catalog.has_private_capabilities());
    assert!(!workbench.context_pack.has_private_context());

    let domains = workbench.agent_definition.capability_domains.clone();
    assert!(domains.contains(&CapabilityDomain::PublicPetDomain));
    assert!(domains.contains(&CapabilityDomain::TemporalReasoning));
    assert!(domains.contains(&CapabilityDomain::AppProductSupport));
    assert!(domains.contains(&CapabilityDomain::AssistantIdentity));
    assert!(
        !domains.contains(&CapabilityDomain::PrivatePetContext),
        "without selected pet, PrivatePetContext must not appear"
    );
}

#[test]
fn builder_exposes_temporal_date_calculation_capability_without_pet() {
    let workbench = TurnContextBuilder::new(AiConversationSurface::HomePrivate).build();

    let capability = workbench
        .capability_catalog
        .capabilities
        .iter()
        .find(|capability| capability.code == "temporal_date_calculation")
        .expect("temporal date calculation capability");

    assert_eq!(capability.domain, CapabilityDomain::TemporalReasoning);
    assert!(!capability.requires_private_context);
    assert!(
        capability.when_to_use.contains("生日")
            && capability.when_to_use.contains("相差天数")
            && capability.when_to_use.contains("提前")
    );
}

#[test]
fn builder_with_pet_adds_private_pet_context() {
    let workbench = TurnContextBuilder::new(AiConversationSurface::HomePrivate)
        .with_target_pet(Some(target_pet()))
        .build();

    assert!(workbench.capability_catalog.has_private_capabilities());
    assert!(workbench.context_pack.has_private_context());

    let domains = workbench.agent_definition.capability_domains.clone();
    assert!(domains.contains(&CapabilityDomain::PrivatePetContext));
    assert!(domains.contains(&CapabilityDomain::TemporalReasoning));
}

#[test]
fn builder_includes_session_summary_when_provided() {
    let workbench = TurnContextBuilder::new(AiConversationSurface::HomePrivate)
        .with_session_summary(Some("用户正在询问豆包近期饮食变化".to_owned()))
        .build();

    assert_eq!(
        workbench.context_pack.session_summary.as_deref(),
        Some("用户正在询问豆包近期饮食变化")
    );
}

#[test]
fn builder_without_session_summary_leaves_none() {
    let workbench = TurnContextBuilder::new(AiConversationSurface::HomePrivate).build();

    assert!(workbench.context_pack.session_summary.is_none());
}

#[test]
fn builder_without_pet_filters_out_private_scope_memories() {
    let workbench = TurnContextBuilder::new(AiConversationSurface::HomePrivate)
        .with_memory_entries(vec![
            MemoryEntry {
                scope: MemoryScope::User,
                subject_id: None,
                summary: "用户偏好简洁回答".to_owned(),
            },
            MemoryEntry {
                scope: MemoryScope::Pet,
                subject_id: Some(pet_id()),
                summary: "豆包对换粮敏感".to_owned(),
            },
        ])
        .build();

    let scopes: Vec<MemoryScope> = workbench
        .memory_pack
        .entries
        .iter()
        .map(|e| e.scope)
        .collect();
    assert!(
        !scopes.contains(&MemoryScope::Pet),
        "without selected pet, Pet scope memories must be filtered out"
    );
    assert_eq!(workbench.memory_pack.entries.len(), 1);
}

#[test]
fn builder_with_pet_keeps_private_scope_memories() {
    let workbench = TurnContextBuilder::new(AiConversationSurface::HomePrivate)
        .with_target_pet(Some(target_pet()))
        .with_memory_entries(vec![
            MemoryEntry {
                scope: MemoryScope::User,
                subject_id: None,
                summary: "用户偏好简洁回答".to_owned(),
            },
            MemoryEntry {
                scope: MemoryScope::Pet,
                subject_id: Some(pet_id()),
                summary: "豆包对换粮敏感".to_owned(),
            },
        ])
        .build();

    assert_eq!(workbench.memory_pack.entries.len(), 2);
}

#[test]
fn builder_with_pet_filters_out_other_pets_memories() {
    let workbench = TurnContextBuilder::new(AiConversationSurface::HomePrivate)
        .with_target_pet(Some(target_pet()))
        .with_memory_entries(vec![
            MemoryEntry {
                scope: MemoryScope::Pet,
                subject_id: Some(pet_id()),
                summary: "豆包对换粮敏感".to_owned(),
            },
            MemoryEntry {
                scope: MemoryScope::Pet,
                subject_id: Some(other_pet_id()),
                summary: "饭团最近食欲下降".to_owned(),
            },
            MemoryEntry {
                scope: MemoryScope::Household,
                subject_id: Some(other_pet_id()),
                summary: "饭团家庭的喂食习惯".to_owned(),
            },
        ])
        .build();

    assert_eq!(workbench.memory_pack.entries.len(), 1);
    assert_eq!(workbench.memory_pack.entries[0].subject_id, Some(pet_id()));
    assert_eq!(workbench.memory_pack.entries[0].summary, "豆包对换粮敏感");
}

#[test]
fn builder_sets_selected_pet_in_context_pack() {
    let pet = target_pet();
    let workbench = TurnContextBuilder::new(AiConversationSurface::HomePrivate)
        .with_target_pet(Some(pet.clone()))
        .build();

    let selected = workbench
        .context_pack
        .selected_pet
        .as_ref()
        .expect("selected pet must be set");
    assert_eq!(selected.pet_id, pet.pet_id);
    assert_eq!(selected.name, pet.pet_name);
    assert_eq!(selected.species, pet.pet_species);
}

#[test]
fn builder_without_pet_has_no_selected_pet() {
    let workbench = TurnContextBuilder::new(AiConversationSurface::HomePrivate).build();

    assert!(workbench.context_pack.selected_pet.is_none());
    assert!(workbench.context_pack.authorized_pets.is_empty());
}
