// AgentConfirmationTask 合约测试
// 核心职责：
// - 验证 agent_confirmation_tasks 的创建、查询和状态更新在 PostgreSQL 中真实持久化

use super::*;
use maohuoban_pet_application::pet::AgentConfirmationTaskRepository;
use maohuoban_pet_domain::pet::{
    AgentConfirmationTask, ConfirmationTaskKind, ConfirmationTaskStatus,
};
use maohuoban_pet_infrastructure::postgres::PostgresAgentConfirmationTaskRepository;
use uuid::Uuid;

#[tokio::test]
async fn agent_confirmation_task_create_persists_to_database() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13900139136").await;

    // 创建宠物
    let create_pet_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "任务喵",
                "species": "cat",
                "breed": "英短",
                "sex": "male",
                "birthday": "2024-01-01"
            }),
            Some(&user_id),
        ))
        .await
        .expect("create pet");
    assert_eq!(create_pet_response.status(), StatusCode::CREATED);
    let pet_body = response_json(create_pet_response).await;
    let pet_id = pet_body["data"]["id"].as_str().expect("pet id").to_owned();
    let pet_uuid: Uuid = Uuid::parse_str(&pet_id).unwrap();

    let repo = PostgresAgentConfirmationTaskRepository::new(app.pool().clone());

    let task = AgentConfirmationTask {
        id: Uuid::new_v4(),
        pet_id: pet_uuid,
        task_kind: ConfirmationTaskKind::DietChangeConfirmation,
        question_text: "最近是否更换了主粮？".to_string(),
        candidate_payload: Some(serde_json::json!({
            "new_brand": "渴望六种鱼",
            "inventory_changed": true
        })),
        source_hint_id: None,
        source_ref_type: Some("food_inventory_change".to_string()),
        source_ref_id: None,
        status: ConfirmationTaskStatus::Pending,
        answer_payload: None,
        resolved_event_id: None,
        created_at: chrono::DateTime::from_timestamp_nanos(0),
        resolved_at: None,
    };

    let saved = repo.create(task.clone()).await.expect("create task");
    assert_eq!(saved.id, task.id);
    assert_eq!(saved.task_kind, task.task_kind);
    assert_eq!(saved.question_text, task.question_text);
    assert_eq!(saved.status, ConfirmationTaskStatus::Pending);

    // 验证 DB 表有数据行
    let db_count: i64 =
        sqlx::query_scalar(r"SELECT COUNT(*) FROM agent_confirmation_tasks WHERE id = $1::uuid")
            .bind(saved.id)
            .fetch_one(app.pool())
            .await
            .expect("count tasks");
    assert_eq!(db_count, 1, "task should be persisted in DB");

    // list_pending_by_pet 验证
    let pending = repo
        .list_pending_by_pet(pet_uuid)
        .await
        .expect("list pending");
    assert_eq!(pending.len(), 1);
    assert_eq!(pending[0].id, task.id);
}

#[tokio::test]
async fn agent_confirmation_task_update_status_resolves_task() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13900139137").await;

    let create_pet_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "确认喵",
                "species": "cat",
                "breed": "美短",
                "sex": "female",
                "birthday": "2024-03-01"
            }),
            Some(&user_id),
        ))
        .await
        .expect("create pet");
    assert_eq!(create_pet_response.status(), StatusCode::CREATED);
    let pet_body = response_json(create_pet_response).await;
    let pet_id = pet_body["data"]["id"].as_str().expect("pet id").to_owned();

    let repo = PostgresAgentConfirmationTaskRepository::new(app.pool().clone());
    let task_id = Uuid::new_v4();

    let task = AgentConfirmationTask {
        id: task_id,
        pet_id: Uuid::parse_str(&pet_id).unwrap(),
        task_kind: ConfirmationTaskKind::SymptomFollowup,
        question_text: "症状是否好转？".to_string(),
        candidate_payload: None,
        source_hint_id: None,
        source_ref_type: None,
        source_ref_id: None,
        status: ConfirmationTaskStatus::Pending,
        answer_payload: None,
        resolved_event_id: None,
        created_at: chrono::DateTime::from_timestamp_nanos(0),
        resolved_at: None,
    };

    let _ = repo.create(task).await.expect("create task");

    let event_id = Uuid::new_v4();
    repo.update_status(
        task_id,
        "answered",
        Some(serde_json::json!({"confirmed": true, "note": "症状已缓解"})),
        Some(event_id),
    )
    .await
    .expect("update status");

    let updated = repo.get_by_id(task_id).await.expect("get by id");
    assert_eq!(
        updated.status,
        ConfirmationTaskStatus::Answered,
        "status should be answered"
    );
    assert!(updated.answer_payload.is_some(), "should have answer");
    assert!(updated.resolved_at.is_some(), "should have resolved_at");
    assert_eq!(
        updated.resolved_event_id,
        Some(event_id),
        "should track resolved event"
    );

    let pending = repo
        .list_pending_by_pet(Uuid::parse_str(&pet_id).unwrap())
        .await
        .expect("list pending");
    assert!(pending.is_empty(), "answered task should not be pending");
}
