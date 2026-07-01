use maohuoban_ai_application::ai::memory::MemoryCandidateService;
use maohuoban_ai_application::ai::ports::{
    MemoryCandidateRepository, MemoryQuery, MemoryRepository,
};
use maohuoban_ai_domain::ai::{MemoryCandidateKind, MemoryCandidateStatus, MemoryScope};
use maohuoban_ai_infrastructure::repository::{
    PostgresMemoryCandidateRepository, PostgresMemoryRepository,
};
use uuid::Uuid;

fn fixed_uuid(value: &str) -> Uuid {
    Uuid::parse_str(value).expect("fixed uuid")
}

/// Postgres 记忆候选仓储会持久化 Pending 候选并支持确认流转
#[tokio::test]
async fn postgres_memory_candidate_repository_persists_and_confirms_candidate() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;

    let repo = PostgresMemoryCandidateRepository::new(app.pool().clone());
    let service = MemoryCandidateService::new(std::sync::Arc::new(repo.clone()));
    let actor_user_id = fixed_uuid("11111111-1111-1111-1111-111111111111");
    let pet_id = fixed_uuid("22222222-2222-2222-2222-222222222222");

    let candidate_id = service
        .create_candidate(
            MemoryScope::Pet,
            pet_id,
            actor_user_id,
            MemoryCandidateKind::PetFactCandidate,
            "豆包最近换了低脂主粮".to_owned(),
            None,
            0.82,
        )
        .await
        .expect("create candidate");

    let pending = repo
        .get_pending_candidates(MemoryScope::Pet, pet_id, actor_user_id)
        .await
        .expect("load pending");
    assert_eq!(pending.len(), 1);
    assert_eq!(pending[0].id, candidate_id);
    assert_eq!(pending[0].status, MemoryCandidateStatus::Pending);

    service
        .confirm_candidate(candidate_id, actor_user_id)
        .await
        .expect("confirm candidate");

    let pending_after_confirm = repo
        .get_pending_candidates(MemoryScope::Pet, pet_id, actor_user_id)
        .await
        .expect("load pending after confirm");
    assert!(pending_after_confirm.is_empty());

    let stored = repo
        .get_by_id(candidate_id)
        .await
        .expect("get candidate")
        .expect("candidate exists");
    assert_eq!(stored.status, MemoryCandidateStatus::Confirmed);
    assert!(stored.confirmed_at.is_some());
}

/// Postgres 记忆仓储必须按用户、scope、宠物主体和状态过滤
#[tokio::test]
async fn postgres_memory_repository_filters_by_scope_actor_pet_and_status() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;

    let actor_user_id = fixed_uuid("33333333-3333-3333-3333-333333333333");
    let other_user_id = fixed_uuid("44444444-4444-4444-4444-444444444444");
    let pet_id = fixed_uuid("55555555-5555-5555-5555-555555555555");
    let other_pet_id = fixed_uuid("66666666-6666-6666-6666-666666666666");

    insert_memory_item(
        app.pool(),
        actor_user_id,
        MemoryScope::Pet,
        pet_id,
        Some(pet_id),
        "豆包喜欢低脂主粮",
        "active",
    )
    .await;
    insert_memory_item(
        app.pool(),
        other_user_id,
        MemoryScope::Pet,
        pet_id,
        Some(pet_id),
        "其他用户的宠物记忆",
        "active",
    )
    .await;
    insert_memory_item(
        app.pool(),
        actor_user_id,
        MemoryScope::Pet,
        other_pet_id,
        Some(other_pet_id),
        "其他宠物的记忆",
        "active",
    )
    .await;
    insert_memory_item(
        app.pool(),
        actor_user_id,
        MemoryScope::Pet,
        pet_id,
        Some(pet_id),
        "已删除记忆",
        "deleted",
    )
    .await;

    let repo = PostgresMemoryRepository::new(app.pool().clone());
    let query = MemoryQuery::new(MemoryScope::Pet, pet_id, actor_user_id).with_pet_id(pet_id);
    let memories = repo.find_memories(&query).await.expect("find memories");

    assert_eq!(memories.len(), 1);
    assert_eq!(memories[0].scope, MemoryScope::Pet);
    assert_eq!(memories[0].subject_id, Some(pet_id));
    assert_eq!(memories[0].summary, "豆包喜欢低脂主粮");
}

/// User scope 记忆带宠物上下文检索时仍必须保留用户记忆
#[tokio::test]
async fn postgres_memory_repository_does_not_apply_pet_filter_to_user_scope() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;

    let actor_user_id = fixed_uuid("77777777-7777-7777-7777-777777777777");
    let pet_id = fixed_uuid("88888888-8888-8888-8888-888888888888");

    insert_memory_item(
        app.pool(),
        actor_user_id,
        MemoryScope::User,
        actor_user_id,
        None,
        "用户偏好简短回答",
        "active",
    )
    .await;

    let repo = PostgresMemoryRepository::new(app.pool().clone());
    let query =
        MemoryQuery::new(MemoryScope::User, actor_user_id, actor_user_id).with_pet_id(pet_id);
    let memories = repo.find_memories(&query).await.expect("find memories");

    assert_eq!(memories.len(), 1);
    assert_eq!(memories[0].scope, MemoryScope::User);
    assert_eq!(memories[0].summary, "用户偏好简短回答");
}

async fn insert_memory_item(
    pool: &sqlx::PgPool,
    actor_user_id: Uuid,
    scope_type: MemoryScope,
    scope_id: Uuid,
    pet_id: Option<Uuid>,
    summary: &str,
    status: &str,
) {
    let scope = match scope_type {
        MemoryScope::User => "user",
        MemoryScope::Pet => "pet",
        MemoryScope::Household => "household",
        MemoryScope::Session => "session",
    };

    sqlx::query(
        r"
        INSERT INTO agent_memory_items
            (id, scope_type, scope_id, actor_user_id, pet_id, memory_kind,
             content, summary, source_ref, confidence, status)
        VALUES ($1, $2, $3, $4, $5, 'weak_memory', $6, $6, '{}'::jsonb, 0.9, $7)
        ",
    )
    .bind(Uuid::new_v4())
    .bind(scope)
    .bind(scope_id)
    .bind(actor_user_id)
    .bind(pet_id)
    .bind(summary)
    .bind(status)
    .execute(pool)
    .await
    .expect("insert memory item");
}
