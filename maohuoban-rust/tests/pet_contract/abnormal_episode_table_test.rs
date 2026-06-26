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

    // 验证响应中 event_payload 包含 episode_id
    let create_body = response_json(create_response).await;
    let episode_id = create_body["data"]["event_payload"]["episode_id"]
        .as_str()
        .map(ToOwned::to_owned);
    assert!(
        episode_id.is_some(),
        "event_payload should contain episode_id in response"
    );
    let _episode_id = episode_id.unwrap();

    // 验证 pet_events 表持久化的 event_payload 也包含 episode_id
    // 查找该宠物最新 health/abnormal_symptom 事件
    let stored_payload: serde_json::Value = sqlx::query_scalar(
        r"SELECT event_payload FROM pet_events WHERE pet_id = $1::uuid AND event_subkind = 'abnormal_symptom' ORDER BY created_at DESC LIMIT 1",
    )
    .bind(&pet_id)
    .fetch_one(app.pool())
    .await
    .expect("read stored event_payload");
    assert!(
        stored_payload["episode_id"].as_str().is_some(),
        "stored event_payload should contain episode_id, got: {stored_payload:?}"
    );

    // 验证 abnormal_episodes 表有数据行
    let episode_count: i64 =
        sqlx::query_scalar(r"SELECT COUNT(*) FROM abnormal_episodes WHERE pet_id = $1::uuid")
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
        r"SELECT COUNT(*) FROM attention_hints WHERE pet_id = $1::uuid AND kind = 'open_abnormal_episode' AND status = 'active'",
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

#[tokio::test]
async fn abnormal_recovery_updates_episode_and_hints_in_database() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13900139134").await;

    // 创建宠物
    let create_pet_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "康复咪",
                "species": "cat",
                "breed": "布偶",
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

    // 创建 abnormal_symptom 事件
    let symptom_resp = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/events"),
            json!({
                "event_kind": "health",
                "event_subkind": "abnormal_symptom",
                "title": "异常：腹泻",
                "summary": "软便两天",
                "visibility": "private",
                "occurred_at": "2026-06-25T08:00:00Z",
                "event_payload": {
                    "symptom_kinds": ["stool"],
                    "severity": "obvious"
                }
            }),
            Some(&user_id),
        ))
        .await
        .expect("create abnormal event");
    assert_eq!(symptom_resp.status(), StatusCode::CREATED);
    let symptom_body = response_json(symptom_resp).await;
    let episode_id = symptom_body["data"]["event_payload"]["episode_id"]
        .as_str()
        .expect("episode_id")
        .to_owned();

    // 创建 abnormal_recovery 事件（当前只写 pet_events，不更新 DB 表）
    let _recovery_resp = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/events"),
            json!({
                "event_kind": "health",
                "event_subkind": "abnormal_recovery",
                "title": "异常恢复：腹泻已好转",
                "summary": "大便已恢复正常",
                "visibility": "private",
                "occurred_at": "2026-06-26T10:00:00Z",
                "event_payload": {
                    "recovery_note": "饮食调理后恢复正常"
                }
            }),
            Some(&user_id),
        ))
        .await
        .expect("create recovery event");

    // 验证 abnormal_episodes 表 status 变为 recovered
    let episode_status: String =
        sqlx::query_scalar(r"SELECT status FROM abnormal_episodes WHERE id = $1::uuid")
            .bind(&episode_id)
            .fetch_one(app.pool())
            .await
            .expect("read episode status");

    assert_eq!(
        episode_status, "recovered",
        "abnormal_recovery should set episode status to recovered, got: {episode_status}"
    );

    // 验证 attention_hints 表 status 变为 resolved
    let hint_count: i64 = sqlx::query_scalar(
        r"SELECT COUNT(*) FROM attention_hints WHERE pet_id = $1::uuid AND kind = 'open_abnormal_episode' AND status = 'active'"
    )
    .bind(&pet_id)
    .fetch_one(app.pool())
    .await
    .expect("count active hints");

    assert_eq!(
        hint_count, 0,
        "abnormal_recovery should resolve all active open_abnormal_episode hints"
    );
}

#[tokio::test]
async fn symptom_followup_updates_episode_last_observed_at() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13900139135").await;

    // 创建宠物
    let create_pet_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "观察喵",
                "species": "cat",
                "breed": "狸花",
                "sex": "female",
                "birthday": "2024-06-01"
            }),
            Some(&user_id),
        ))
        .await
        .expect("create pet");
    assert_eq!(create_pet_response.status(), StatusCode::CREATED);
    let pet_body = response_json(create_pet_response).await;
    let pet_id = pet_body["data"]["id"].as_str().expect("pet id").to_owned();

    // 创建 abnormal_symptom 事件
    let symptom_resp = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/events"),
            json!({
                "event_kind": "health",
                "event_subkind": "abnormal_symptom",
                "title": "异常：食欲下降",
                "summary": "第一天",
                "visibility": "private",
                "occurred_at": "2026-06-26T08:00:00Z",
                "event_payload": {
                    "symptom_kinds": ["appetite"],
                    "severity": "obvious"
                }
            }),
            Some(&user_id),
        ))
        .await
        .expect("create abnormal event");
    assert_eq!(symptom_resp.status(), StatusCode::CREATED);
    let symptom_body = response_json(symptom_resp).await;
    let episode_id = symptom_body["data"]["event_payload"]["episode_id"]
        .as_str()
        .expect("episode_id")
        .to_owned();

    // 记录创建后的 last_observed_at（应等于 started_at）
    let initial_observed: Option<chrono::DateTime<chrono::Utc>> =
        sqlx::query_scalar(r"SELECT last_observed_at FROM abnormal_episodes WHERE id = $1::uuid")
            .bind(&episode_id)
            .fetch_one(app.pool())
            .await
            .expect("read last_observed_at");
    assert!(
        initial_observed.is_none(),
        "new episode should have null last_observed_at"
    );

    // 创建 symptom_followup 事件
    let _followup_resp = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/events"),
            json!({
                "event_kind": "health",
                "event_subkind": "symptom_followup",
                "title": "追加观察：缓解",
                "summary": "第二天好转",
                "visibility": "private",
                "occurred_at": "2026-06-27T10:00:00Z",
                "event_payload": {
                    "condition_change": "improved"
                }
            }),
            Some(&user_id),
        ))
        .await
        .expect("create followup event");

    // 验证 abnormal_episodes.last_observed_at 已更新
    let updated_observed: Option<chrono::DateTime<chrono::Utc>> =
        sqlx::query_scalar(r"SELECT last_observed_at FROM abnormal_episodes WHERE id = $1::uuid")
            .bind(&episode_id)
            .fetch_one(app.pool())
            .await
            .expect("read updated last_observed_at");

    assert!(
        updated_observed.is_some(),
        "symptom_followup should update last_observed_at from NULL to Some"
    );
}
