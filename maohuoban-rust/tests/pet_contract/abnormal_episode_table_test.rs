// AbnormalEpisode 数据表契约测试
// 核心职责：
// - 验证异常记录创建后 abnormal_episodes 表和 attention_hints 表有数据行
// - 该测试验证 Phase 3 目标文档要求的：异常提交时创建 episode 并生成轻提示

use super::*;

#[tokio::test]
async fn abnormal_symptom_writes_to_abnormal_episodes_table() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13900139133").await;

    let create_pet_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "测试喵",
                "species": "cat",
                "breed": "美短",
                "sex": "male",
                "birthday": "2025-01-01"
            }),
            Some(&user_id),
        ))
        .await
        .expect("create pet");
    assert_eq!(create_pet_response.status(), StatusCode::CREATED);
    let create_pet_body = response_json(create_pet_response).await;
    let pet_id = create_pet_body["data"]["id"]
        .as_str()
        .expect("pet id")
        .to_owned();

    // 创建 abnormal_symptom 事件
    let create_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/events"),
            json!({
                "event_kind": "health",
                "event_subkind": "abnormal_symptom",
                "title": "异常：食欲下降",
                "summary": "连续两天食欲下降",
                "visibility": "private",
                "occurred_at": "2026-06-26T10:00:00Z",
                "event_payload": {
                    "symptom_kinds": ["appetite"],
                    "severity": "obvious"
                }
            }),
            Some(&user_id),
        ))
        .await
        .expect("create abnormal event");
    assert_eq!(
        create_response.status(),
        StatusCode::CREATED,
        "abnormal_symptom event should be created"
    );

    // 验证 abnormal_episodes 表有数据行
    let episode_count: i64 =
        sqlx::query_scalar(r#"SELECT COUNT(*) FROM abnormal_episodes WHERE pet_id = $1::uuid"#)
            .bind(&pet_id)
            .fetch_one(app.pool())
            .await
            .expect("count abnormal_episodes");

    assert!(
        episode_count > 0,
        "abnormal_symptom should create row in abnormal_episodes table"
    );

    // 验证 attention_hints 表有 open_abnormal_episode 行
    let hint_count: i64 = sqlx::query_scalar(
        r#"SELECT COUNT(*) FROM attention_hints WHERE pet_id = $1::uuid AND kind = 'open_abnormal_episode' AND status = 'active'"#,
    )
    .bind(&pet_id)
    .fetch_one(app.pool())
    .await
    .expect("count attention_hints");

    assert!(
        hint_count > 0,
        "abnormal_symptom should create open_abnormal_episode hint in attention_hints table"
    );
}
