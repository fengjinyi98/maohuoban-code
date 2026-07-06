// AbnormalEpisode 异常追踪合约测试
// 核心职责：
// - 验证异常记录创建时生成 episode + pet event
// - 验证追加观察和创建异常不会生成旧 open_abnormal_episode hint
// - 验证标记恢复后 attention_hints 为空

use super::*;

#[tokio::test]
async fn create_abnormal_episode_writes_episode_and_event() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13900139130").await;

    let create_pet_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "小小",
                "species": "cat",
                "breed": "美短",
                "sex": "male",
                "birthday": "2025-06-01"
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
    assert_eq!(create_response.status(), StatusCode::CREATED);

    let create_body = response_json(create_response).await;
    let event_id = create_body["data"]["id"].as_str().expect("event id");

    // 验证首页不再出现旧 open_abnormal_episode attention_hint
    let dashboard_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/home/dashboard?selected_pet_id={pet_id}"),
            Some(&user_id),
        ))
        .await
        .expect("load dashboard");
    assert_eq!(dashboard_response.status(), StatusCode::OK);
    let dashboard = response_json(dashboard_response).await;
    let hints = dashboard["data"]["attention_hints"].as_array().unwrap();

    assert!(
        hints
            .iter()
            .all(|hint| hint["kind"] != "open_abnormal_episode"),
        "abnormal creation should not create legacy open_abnormal_episode hint: {hints:?}"
    );

    let detail_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/pet-events/{event_id}"),
            Some(&user_id),
        ))
        .await
        .expect("load abnormal event detail from hint route");
    assert_eq!(
        detail_response.status(),
        StatusCode::OK,
        "abnormal hint event_id should resolve to pet event detail"
    );
}

#[tokio::test]
#[allow(clippy::too_many_lines)]
async fn deleting_abnormal_event_resolves_episode_and_attention_hint() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13900139136").await;

    let create_pet_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "花卷",
                "species": "cat",
                "breed": "狸花",
                "sex": "female",
                "birthday": "2025-03-01"
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

    let create_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/events"),
            json!({
                "event_kind": "health",
                "event_subkind": "abnormal_symptom",
                "title": "异常：精神差",
                "summary": "今天精神变差",
                "visibility": "private",
                "occurred_at": "2026-06-27T10:00:00Z",
                "event_payload": {
                    "symptom_kinds": ["energy"],
                    "severity": "obvious"
                }
            }),
            Some(&user_id),
        ))
        .await
        .expect("create abnormal event");
    assert_eq!(create_response.status(), StatusCode::CREATED);
    let create_body = response_json(create_response).await;
    let event_id = create_body["data"]["id"]
        .as_str()
        .expect("event id")
        .to_owned();
    let episode_id = create_body["data"]["event_payload"]["episode_id"]
        .as_str()
        .expect("episode id")
        .to_owned();

    let followup_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/events"),
            json!({
                "event_kind": "health",
                "event_subkind": "symptom_followup",
                "title": "追加观察",
                "summary": "精神一般",
                "visibility": "private",
                "occurred_at": "2026-06-27T13:00:00Z",
                "event_payload": {
                    "episode_id": episode_id,
                    "note": "精神一般"
                }
            }),
            Some(&user_id),
        ))
        .await
        .expect("create symptom followup");
    assert_eq!(followup_response.status(), StatusCode::CREATED);
    let followup_body = response_json(followup_response).await;
    let followup_id = followup_body["data"]["id"]
        .as_str()
        .expect("followup id")
        .to_owned();

    let recovery_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/events"),
            json!({
                "event_kind": "health",
                "event_subkind": "abnormal_recovery",
                "title": "标记恢复",
                "summary": "精神恢复",
                "visibility": "private",
                "occurred_at": "2026-06-27T16:00:00Z",
                "event_payload": {
                    "episode_id": episode_id,
                    "recovery_note": "精神恢复"
                }
            }),
            Some(&user_id),
        ))
        .await
        .expect("create recovery event");
    assert_eq!(recovery_response.status(), StatusCode::CREATED);
    let recovery_body = response_json(recovery_response).await;
    let recovery_id = recovery_body["data"]["id"]
        .as_str()
        .expect("recovery id")
        .to_owned();

    let delete_response = app
        .router()
        .oneshot(empty_request(
            "DELETE",
            &format!("/api/v1/pet-events/{event_id}"),
            Some(&user_id),
        ))
        .await
        .expect("delete abnormal event");
    assert_eq!(delete_response.status(), StatusCode::OK);

    let episode_status: String =
        sqlx::query_scalar(r"SELECT status FROM abnormal_episodes WHERE id = $1::uuid")
            .bind(&episode_id)
            .fetch_one(app.pool())
            .await
            .expect("load episode status");
    assert_eq!(episode_status, "closed");

    let active_hint_count: i64 = sqlx::query_scalar(
        r"
        SELECT COUNT(*)
        FROM attention_hints
        WHERE source_ref_id = $1::uuid
          AND source_ref_type = 'abnormal_episode'
          AND kind = 'open_abnormal_episode'
          AND status = 'active'
        ",
    )
    .bind(&episode_id)
    .fetch_one(app.pool())
    .await
    .expect("count active abnormal hints");
    assert_eq!(active_hint_count, 0);

    let dashboard_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/home/dashboard?selected_pet_id={pet_id}"),
            Some(&user_id),
        ))
        .await
        .expect("load dashboard");
    assert_eq!(dashboard_response.status(), StatusCode::OK);
    let dashboard = response_json(dashboard_response).await;
    let hints = dashboard["data"]["attention_hints"].as_array().unwrap();
    assert!(
        hints.is_empty(),
        "deleted abnormal event must remove home attention hint"
    );

    let timeline_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/pets/{pet_id}/timeline"),
            Some(&user_id),
        ))
        .await
        .expect("load timeline after delete");
    assert_eq!(timeline_response.status(), StatusCode::OK);
    let timeline = response_json(timeline_response).await;
    let events = timeline["data"]["events"].as_array().unwrap();
    assert!(
        events.iter().all(|item| item["id"] != event_id
            && item["id"] != followup_id
            && item["id"] != recovery_id),
        "deleting abnormal event must remove the whole episode timeline"
    );
}

#[tokio::test]
async fn symptom_followup_does_not_create_extra_hints() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13900139131").await;

    let create_pet_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "大毛",
                "species": "cat",
                "breed": "橘猫",
                "sex": "male",
                "birthday": "2024-01-01"
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

    // 创建初始 abnormal_symptom 事件
    let _ = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/events"),
            json!({
                "event_kind": "health",
                "event_subkind": "abnormal_symptom",
                "title": "异常：呕吐",
                "summary": "早上呕吐一次",
                "visibility": "private",
                "occurred_at": "2026-06-26T08:00:00Z",
                "event_payload": {
                    "symptom_kinds": ["vomit"],
                    "severity": "mild"
                }
            }),
            Some(&user_id),
        ))
        .await
        .expect("create first abnormal event");

    // 追加观察（symptom_followup）
    let _ = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/events"),
            json!({
                "event_kind": "health",
                "event_subkind": "symptom_followup",
                "title": "追加观察：呕吐缓解",
                "summary": "下午状态好转",
                "visibility": "private",
                "occurred_at": "2026-06-26T14:00:00Z",
                "event_payload": {
                    "condition_change": "improved"
                }
            }),
            Some(&user_id),
        ))
        .await
        .expect("create followup event");

    // 验证首页仍然没有旧 open_abnormal_episode hint
    let dashboard_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/home/dashboard?selected_pet_id={pet_id}"),
            Some(&user_id),
        ))
        .await
        .expect("load dashboard");
    assert_eq!(dashboard_response.status(), StatusCode::OK);
    let dashboard = response_json(dashboard_response).await;
    let hints = dashboard["data"]["attention_hints"].as_array().unwrap();

    assert!(
        hints
            .iter()
            .all(|hint| hint["kind"] != "open_abnormal_episode"),
        "followup should not create legacy open_abnormal_episode hint: {hints:?}"
    );
}

#[tokio::test]
async fn abnormal_recovery_removes_hints() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13900139132").await;

    let create_pet_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "咪咪",
                "species": "cat",
                "breed": "英短",
                "sex": "female",
                "birthday": "2024-03-15"
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

    // 创建 abnormal_symptom
    let _ = app
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

    // 确认创建异常后不写旧 open_abnormal_episode hint
    let check = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/home/dashboard?selected_pet_id={pet_id}"),
            Some(&user_id),
        ))
        .await
        .expect("load dashboard");
    let check_body = response_json(check).await;
    let hints_before = check_body["data"]["attention_hints"].as_array().unwrap();
    assert!(
        hints_before
            .iter()
            .all(|hint| hint["kind"] != "open_abnormal_episode"),
        "abnormal creation should not create legacy open_abnormal_episode hint: {hints_before:?}"
    );

    // 创建 recovery 事件
    let _ = app
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

    // 验证恢复后仍无旧 open_abnormal_episode hint
    let after = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/home/dashboard?selected_pet_id={pet_id}"),
            Some(&user_id),
        ))
        .await
        .expect("load dashboard");
    let after_body = response_json(after).await;
    let hints_after = after_body["data"]["attention_hints"].as_array().unwrap();
    assert!(
        hints_after
            .iter()
            .all(|hint| hint["kind"] != "open_abnormal_episode"),
        "recovery should keep legacy open_abnormal_episode hint absent: {hints_after:?}"
    );
}
