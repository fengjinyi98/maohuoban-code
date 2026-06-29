// memory_pack_isolation MemoryPack 作用域隔离测试
// 核心职责：
// - 验证无宠物公共问答不加载私域宠物记忆
// - 验证 filter_for_public_context 移除 Pet 和 Household scope 条目
// - 验证 filter_for_pet_context 按 pet_id 过滤 Pet scope，无 household_id 时移除全部 Household scope

use maohuoban_ai_domain::ai::{MemoryEntry, MemoryPack, MemoryScope};
use uuid::Uuid;

fn pet_id() -> Uuid {
    Uuid::parse_str("11111111-1111-1111-1111-111111111111").expect("pet id")
}

fn other_pet_id() -> Uuid {
    Uuid::parse_str("33333333-3333-3333-3333-333333333333").expect("other pet id")
}

fn user_id() -> Uuid {
    Uuid::parse_str("22222222-2222-2222-2222-222222222222").expect("user id")
}

fn household_id() -> Uuid {
    Uuid::parse_str("55555555-5555-5555-5555-555555555555").expect("household id")
}

#[test]
fn filter_for_public_context_removes_pet_and_household_scope_entries() {
    let pack = MemoryPack {
        entries: vec![
            MemoryEntry {
                scope: MemoryScope::User,
                subject_id: Some(user_id()),
                summary: "用户偏好：偏好简洁回答".to_owned(),
            },
            MemoryEntry {
                scope: MemoryScope::Pet,
                subject_id: Some(pet_id()),
                summary: "豆包对突然换粮比较敏感".to_owned(),
            },
            MemoryEntry {
                scope: MemoryScope::Household,
                subject_id: Some(pet_id()),
                summary: "家庭养宠习惯：每天早晚喂食".to_owned(),
            },
            MemoryEntry {
                scope: MemoryScope::Session,
                subject_id: None,
                summary: "用户正在询问猫拉肚子的观察要点".to_owned(),
            },
        ],
    };

    let filtered = pack.filter_for_public_context();

    let remaining_scopes: Vec<MemoryScope> = filtered.entries.iter().map(|e| e.scope).collect();
    assert!(
        !remaining_scopes.contains(&MemoryScope::Pet),
        "public context must not include Pet scope memories"
    );
    assert!(
        !remaining_scopes.contains(&MemoryScope::Household),
        "public context must not include Household scope memories"
    );
    assert!(filtered.entries.len() == 2);
}

#[test]
fn filter_for_public_context_preserves_user_and_session_scope_entries() {
    let pack = MemoryPack {
        entries: vec![
            MemoryEntry {
                scope: MemoryScope::User,
                subject_id: Some(user_id()),
                summary: "用户偏好简洁回答".to_owned(),
            },
            MemoryEntry {
                scope: MemoryScope::Session,
                subject_id: None,
                summary: "用户正在询问猫拉肚子".to_owned(),
            },
        ],
    };

    let filtered = pack.filter_for_public_context();
    assert_eq!(filtered.entries.len(), 2);
}

#[test]
fn filter_for_public_context_on_empty_pack_returns_empty() {
    let pack = MemoryPack {
        entries: Vec::new(),
    };
    let filtered = pack.filter_for_public_context();
    assert!(filtered.entries.is_empty());
}

#[test]
fn filter_for_pet_context_removes_pet_scope_entries_for_other_pets() {
    let pack = MemoryPack {
        entries: vec![
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
        ],
    };

    let filtered = pack.filter_for_pet_context(pet_id());
    assert_eq!(filtered.entries.len(), 1);
    assert_eq!(filtered.entries[0].subject_id, Some(pet_id()));
    assert_eq!(filtered.entries[0].summary, "豆包对换粮敏感");
}

#[test]
fn filter_for_pet_context_removes_all_household_scope_entries_without_household_id() {
    // Household scope 的 subject_id 是 household_id，不是 pet_id。
    // 没有 household_id 时，Household 记忆必须全部移除，不能拿 pet_id 去匹配。
    let pack = MemoryPack {
        entries: vec![
            MemoryEntry {
                scope: MemoryScope::Household,
                subject_id: Some(pet_id()),
                summary: "家庭喂食习惯A".to_owned(),
            },
            MemoryEntry {
                scope: MemoryScope::Household,
                subject_id: Some(other_pet_id()),
                summary: "家庭喂食习惯B".to_owned(),
            },
        ],
    };

    let filtered = pack.filter_for_pet_context(pet_id());
    assert!(
        filtered.entries.is_empty(),
        "Household scope must be removed entirely when no household_id is provided"
    );
}

#[test]
fn filter_for_household_context_only_preserves_matching_household_scope_entries() {
    let pack = MemoryPack {
        entries: vec![
            MemoryEntry {
                scope: MemoryScope::Household,
                subject_id: Some(household_id()),
                summary: "当前家庭喂食习惯".to_owned(),
            },
            MemoryEntry {
                scope: MemoryScope::Household,
                subject_id: Some(other_pet_id()),
                summary: "其他家庭喂食习惯".to_owned(),
            },
            MemoryEntry {
                scope: MemoryScope::Pet,
                subject_id: Some(pet_id()),
                summary: "豆包体重 5kg".to_owned(),
            },
            MemoryEntry {
                scope: MemoryScope::User,
                subject_id: Some(user_id()),
                summary: "用户偏好简洁回答".to_owned(),
            },
        ],
    };

    let filtered = pack.filter_for_household_context(household_id());

    assert!(
        filtered
            .entries
            .iter()
            .any(|entry| entry.summary == "当前家庭喂食习惯")
    );
    assert!(
        !filtered
            .entries
            .iter()
            .any(|entry| entry.summary == "其他家庭喂食习惯")
    );
    assert!(
        !filtered
            .entries
            .iter()
            .any(|entry| entry.summary == "豆包体重 5kg")
    );
    assert!(
        filtered
            .entries
            .iter()
            .any(|entry| entry.summary == "用户偏好简洁回答")
    );
}

#[test]
fn filter_for_pet_context_preserves_user_and_session_and_matching_pet_scope_entries() {
    let pack = MemoryPack {
        entries: vec![
            MemoryEntry {
                scope: MemoryScope::User,
                subject_id: Some(user_id()),
                summary: "用户偏好简洁回答".to_owned(),
            },
            MemoryEntry {
                scope: MemoryScope::Session,
                subject_id: None,
                summary: "用户正在询问猫拉肚子".to_owned(),
            },
            MemoryEntry {
                scope: MemoryScope::Pet,
                subject_id: Some(pet_id()),
                summary: "豆包对换粮敏感".to_owned(),
            },
            MemoryEntry {
                scope: MemoryScope::Pet,
                subject_id: Some(other_pet_id()),
                summary: "饭团的记忆".to_owned(),
            },
            MemoryEntry {
                scope: MemoryScope::Household,
                subject_id: Some(pet_id()),
                summary: "家庭喂食习惯".to_owned(),
            },
        ],
    };

    let filtered = pack.filter_for_pet_context(pet_id());
    // User + Session + 匹配的 Pet = 3 条；Household 和其他 Pet 被移除
    assert_eq!(filtered.entries.len(), 3);
    let scopes: Vec<MemoryScope> = filtered.entries.iter().map(|e| e.scope).collect();
    assert!(scopes.contains(&MemoryScope::User));
    assert!(scopes.contains(&MemoryScope::Session));
    assert!(scopes.contains(&MemoryScope::Pet));
    assert!(!scopes.contains(&MemoryScope::Household));
}

#[test]
fn filter_for_pet_context_on_empty_pack_returns_empty() {
    let pack = MemoryPack {
        entries: Vec::new(),
    };
    let filtered = pack.filter_for_pet_context(pet_id());
    assert!(filtered.entries.is_empty());
}

#[test]
fn filter_for_public_context_with_only_pet_scope_returns_empty() {
    let pack = MemoryPack {
        entries: vec![MemoryEntry {
            scope: MemoryScope::Pet,
            subject_id: Some(pet_id()),
            summary: "豆包最近换了主粮".to_owned(),
        }],
    };
    let filtered = pack.filter_for_public_context();
    assert!(filtered.entries.is_empty());
}
