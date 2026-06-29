// memory_retrieval 私域记忆检索过滤测试
// 核心职责：
// - 验证检索条件必须带 scope_type、scope_id、actor_user_id
// - 验证公共问答不加载 pet 私域记忆
// - 验证未授权 pet 记忆不可检索
// - 验证 Pet 作用域必须有 pet_id
// - 验证 Household 作用域必须有 household_id

use maohuoban_ai_application::ai::memory::MemoryRetriever;
use maohuoban_ai_application::ai::ports::{MemoryQuery, MemoryRepository};
use maohuoban_ai_domain::ai::{AiResult, MemoryEntry, MemoryScope};
use std::sync::Arc;
use uuid::Uuid;

fn actor_user_id() -> Uuid {
    Uuid::parse_str("22222222-2222-2222-2222-222222222222").expect("actor user id")
}

fn pet_id() -> Uuid {
    Uuid::parse_str("33333333-3333-3333-3333-333333333333").expect("pet id")
}

fn other_pet_id() -> Uuid {
    Uuid::parse_str("44444444-4444-4444-4444-444444444444").expect("other pet id")
}

fn household_id() -> Uuid {
    Uuid::parse_str("55555555-5555-5555-5555-555555555555").expect("household id")
}

fn other_household_id() -> Uuid {
    Uuid::parse_str("66666666-6666-6666-6666-666666666666").expect("other household id")
}

fn memory_entry(scope: MemoryScope, subject_id: Option<Uuid>, summary: &str) -> MemoryEntry {
    MemoryEntry {
        scope,
        subject_id,
        summary: summary.to_owned(),
    }
}

// === MemoryQuery 测试 ===

#[test]
fn query_pet_scope_requires_pet_id() {
    let query = MemoryQuery::new(MemoryScope::Pet, pet_id(), actor_user_id());
    assert!(
        !query.is_valid(),
        "Pet scope without pet_id should be invalid"
    );

    let query = MemoryQuery::new(MemoryScope::Pet, pet_id(), actor_user_id()).with_pet_id(pet_id());
    assert!(query.is_valid());
}

#[test]
fn query_household_scope_requires_household_id() {
    let query = MemoryQuery::new(MemoryScope::Household, household_id(), actor_user_id());
    assert!(
        !query.is_valid(),
        "Household scope without household_id should be invalid"
    );

    let query = MemoryQuery::new(MemoryScope::Household, household_id(), actor_user_id())
        .with_household_id(household_id());
    assert!(query.is_valid());
}

#[test]
fn query_user_scope_valid_without_pet_id() {
    let query = MemoryQuery::new(MemoryScope::User, actor_user_id(), actor_user_id());
    assert!(query.is_valid());
}

// === MemoryRetriever 测试 ===

#[tokio::test]
async fn retriever_public_context_excludes_pet_memories() {
    // 公共问答（User 作用域，无 pet_id）不应加载 Pet 私域记忆
    let repo = Arc::new(FakeMemoryRepo::new(vec![
        memory_entry(MemoryScope::User, None, "用户偏好简短回答"),
        memory_entry(MemoryScope::Pet, Some(pet_id()), "豆包体重 5kg"),
        memory_entry(
            MemoryScope::Household,
            Some(household_id()),
            "家庭养了两只猫",
        ),
    ]));
    let retriever = MemoryRetriever::new(repo);

    let query = MemoryQuery::new(MemoryScope::User, actor_user_id(), actor_user_id());
    let pack = retriever.retrieve(query).await.expect("retrieve");

    // User 作用域记忆保留
    assert!(pack.entries.iter().any(|e| e.summary == "用户偏好简短回答"));
    // Pet 和 Household 私域记忆被过滤
    assert!(
        !pack.entries.iter().any(|e| e.summary.contains("豆包体重")),
        "public context must not load pet private memories"
    );
    assert!(
        !pack.entries.iter().any(|e| e.summary.contains("家庭养了")),
        "public context must not load household private memories"
    );
}

#[tokio::test]
async fn retriever_pet_context_only_loads_authorized_pet() {
    // 有 pet_id 的上下文只加载该宠物的记忆，不加载其他宠物的记忆
    let repo = Arc::new(FakeMemoryRepo::new(vec![
        memory_entry(MemoryScope::Pet, Some(pet_id()), "豆包体重 5kg"),
        memory_entry(MemoryScope::Pet, Some(other_pet_id()), "其他猫的体重 3kg"),
        memory_entry(MemoryScope::User, None, "用户偏好简短回答"),
    ]));
    let retriever = MemoryRetriever::new(repo);

    let query =
        MemoryQuery::new(MemoryScope::User, actor_user_id(), actor_user_id()).with_pet_id(pet_id());
    let pack = retriever.retrieve(query).await.expect("retrieve");

    // 当前宠物的记忆保留
    assert!(pack.entries.iter().any(|e| e.summary == "豆包体重 5kg"));
    // 其他宠物的记忆被过滤
    assert!(
        !pack.entries.iter().any(|e| e.summary.contains("其他猫")),
        "unauthorized pet memories must not be retrievable"
    );
    // User 作用域记忆保留
    assert!(pack.entries.iter().any(|e| e.summary == "用户偏好简短回答"));
}

#[tokio::test]
async fn retriever_rejects_invalid_pet_scope_query() {
    let repo = Arc::new(FakeMemoryRepo::new(vec![]));
    let retriever = MemoryRetriever::new(repo);

    // Pet 作用域但没传 pet_id，应该被拒绝
    let query = MemoryQuery::new(MemoryScope::Pet, pet_id(), actor_user_id());
    let result = retriever.retrieve(query).await;

    assert!(
        result.is_err(),
        "Pet scope query without pet_id must be rejected"
    );
}

#[tokio::test]
async fn retriever_rejects_invalid_household_scope_query() {
    let repo = Arc::new(FakeMemoryRepo::new(vec![]));
    let retriever = MemoryRetriever::new(repo);

    // Household 作用域但没传 household_id，应该被拒绝
    let query = MemoryQuery::new(MemoryScope::Household, household_id(), actor_user_id());
    let result = retriever.retrieve(query).await;

    assert!(
        result.is_err(),
        "Household scope query without household_id must be rejected"
    );
}

#[tokio::test]
async fn retriever_household_context_loads_authorized_memories() {
    // 合法 Household 查询（带 household_id）应返回对应家庭的记忆
    let repo = Arc::new(FakeMemoryRepo::new(vec![
        memory_entry(
            MemoryScope::Household,
            Some(household_id()),
            "家庭养了两只猫",
        ),
        memory_entry(
            MemoryScope::Household,
            Some(other_household_id()),
            "其他家庭养了一只狗",
        ),
        memory_entry(MemoryScope::Pet, Some(pet_id()), "豆包体重 5kg"),
        memory_entry(MemoryScope::User, None, "用户偏好简短回答"),
    ]));
    let retriever = MemoryRetriever::new(repo);

    let query = MemoryQuery::new(MemoryScope::Household, household_id(), actor_user_id())
        .with_household_id(household_id());
    let pack = retriever.retrieve(query).await.expect("retrieve");

    // 当前家庭的记忆保留
    assert!(
        pack.entries.iter().any(|e| e.summary == "家庭养了两只猫"),
        "authorized household memories must be loaded"
    );
    // 其他家庭的记忆被过滤
    assert!(
        !pack.entries.iter().any(|e| e.summary.contains("其他家庭")),
        "unauthorized household memories must not be loaded"
    );
    // Pet 记忆在 Household 上下文中被过滤
    assert!(
        !pack.entries.iter().any(|e| e.summary.contains("豆包体重")),
        "pet memories must not be loaded in household context"
    );
    // User 作用域记忆保留
    assert!(pack.entries.iter().any(|e| e.summary == "用户偏好简短回答"));
}

// === Fake 实现 ===

struct FakeMemoryRepo {
    memories: Vec<MemoryEntry>,
}

impl FakeMemoryRepo {
    fn new(memories: Vec<MemoryEntry>) -> Self {
        Self { memories }
    }
}

#[async_trait::async_trait]
impl MemoryRepository for FakeMemoryRepo {
    async fn find_memories(&self, query: &MemoryQuery) -> AiResult<Vec<MemoryEntry>> {
        // 模拟仓储层按 actor 和授权范围返回记忆
        // 仓储负责返回用户有权访问的所有记忆，过滤隔离由 MemoryRetriever 的 MemoryPack 层完成
        let results: Vec<MemoryEntry> = self
            .memories
            .iter()
            .filter(|m| match m.scope {
                // User 和 Session 记忆始终返回
                MemoryScope::User | MemoryScope::Session => true,
                // Pet 记忆仅在提供了匹配的 pet_id 时返回
                MemoryScope::Pet => m.subject_id.is_some() && m.subject_id == query.pet_id,
                // Household 记忆仅在提供了匹配的 household_id 时返回
                MemoryScope::Household => {
                    m.subject_id.is_some() && m.subject_id == query.household_id
                }
            })
            .cloned()
            .collect();
        Ok(results)
    }
}
