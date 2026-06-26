// AbnormalEpisode 异常追踪合约测试
// 核心职责：
// - 验证异常记录创建时生成 episode + pet event
// - 验证追加观察不会重复生成 hint
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

    // 验证首页出现 attention_hint
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

    assert!(!hints.is_empty(), "expected at least one attention_hint");
    assert_eq!(
        hints[0]["kind"], "open_abnormal_episode",
        "first hint should be open_abnormal_episode"
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

    // 验证首页仍然只有 1 个 open_abnormal_episode hint
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

    // 追加观察不应生成新 hint
    assert!(!hints.is_empty(), "should still have the original hint");
    assert_eq!(hints.len(), 1, "followup should not add extra hints");
    assert_eq!(
        hints[0]["kind"], "open_abnormal_episode",
        "should still be open_abnormal_episode"
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

    // 确认 hint 存在
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
    assert!(!hints_before.is_empty(), "should have hint before recovery");

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

    // 验证 hint 已消除
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
    assert!(hints_after.is_empty(), "recovery should remove hints");
}
