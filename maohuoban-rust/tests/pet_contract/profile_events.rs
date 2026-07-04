use super::*;

#[tokio::test]
async fn pet_profile_event_and_timeline_are_persisted() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138110").await;

    let create_pet_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "糯米",
                "species": "dog",
                "breed": "比熊犬",
                "sex": "female",
                "birthday": "2024-04-01"
            }),
            Some(&user_id),
        ))
        .await
        .expect("create pet");
    assert_eq!(create_pet_response.status(), StatusCode::CREATED);
    let create_pet_body = response_json(create_pet_response).await;
    assert_eq!(create_pet_body["success"], true);
    assert_eq!(create_pet_body["code"], "pet.created");
    assert_eq!(create_pet_body["message"], "宠物档案已创建");
    assert_eq!(create_pet_body["data"]["name"], "糯米");
    assert_eq!(create_pet_body["data"]["owner_user_id"], user_id);
    let pet_id = create_pet_body["data"]["id"]
        .as_str()
        .expect("pet id")
        .to_owned();
    uuid::Uuid::parse_str(&pet_id).expect("pet id should be uuid");

    let create_event_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/events"),
            json!({
                "event_kind": "health",
                "event_subkind": "weight",
                "title": "体重记录",
                "summary": "5.2kg，较上次稳定",
                "visibility": "private",
                "occurred_at": "2026-06-13T09:20:00Z",
                "event_payload": {
                    "weight_kg": 5.2
                }
            }),
            Some(&user_id),
        ))
        .await
        .expect("create pet event");
    assert_eq!(create_event_response.status(), StatusCode::CREATED);
    let create_event_body = response_json(create_event_response).await;
    assert_eq!(create_event_body["success"], true);
    assert_eq!(create_event_body["code"], "pet.event_created");
    assert_eq!(create_event_body["data"]["pet_id"], pet_id);
    assert_eq!(create_event_body["data"]["event_kind"], "health");
    assert_eq!(create_event_body["data"]["event_subkind"], "weight");
    assert_eq!(create_event_body["data"]["record_revision"], 1);

    let timeline_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/pets/{pet_id}/timeline"),
            Some(&user_id),
        ))
        .await
        .expect("load pet timeline");
    assert_eq!(timeline_response.status(), StatusCode::OK);
    let timeline_body = response_json(timeline_response).await;
    assert_eq!(timeline_body["success"], true);
    assert_eq!(timeline_body["code"], "pet.timeline_loaded");
    assert_eq!(timeline_body["data"]["pet_id"], pet_id);
    assert_eq!(timeline_body["data"]["events"][0]["title"], "体重记录");
    assert_eq!(
        timeline_body["data"]["events"][0]["summary"],
        "5.2kg，较上次稳定"
    );
}

#[tokio::test]
async fn pet_timeline_includes_profile_lifecycle_facts_and_events() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138116").await;

    let create_pet_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "糯米",
                "species": "dog",
                "sex": "female",
                "birthday": "2024-04-01",
                "arrival_date": "2024-06-16"
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

    let create_event_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/events"),
            json!({
                "event_kind": "health",
                "event_subkind": "appetite_normal",
                "title": "食欲正常",
                "summary": "今天食欲正常",
                "visibility": "private",
                "occurred_at": "2026-06-13T09:20:00Z",
                "event_payload": {
                    "quick_fact_kind": "appetite_normal"
                }
            }),
            Some(&user_id),
        ))
        .await
        .expect("create pet event");
    assert_eq!(create_event_response.status(), StatusCode::CREATED);
    let create_event_body = response_json(create_event_response).await;
    let event_id = create_event_body["data"]["id"]
        .as_str()
        .expect("event id")
        .to_owned();

    let timeline_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/pets/{pet_id}/timeline"),
            Some(&user_id),
        ))
        .await
        .expect("load pet timeline");
    assert_eq!(timeline_response.status(), StatusCode::OK);
    let timeline_body = response_json(timeline_response).await;
    let events = timeline_body["data"]["events"]
        .as_array()
        .expect("timeline events");

    assert_eq!(events.len(), 3);
    assert_eq!(events[0]["id"], event_id);
    assert_eq!(events[0]["title"], "食欲正常");
    assert_eq!(events[1]["id"], format!("{pet_id}-homecoming"));
    assert_eq!(events[1]["event_subkind"], "homecoming");
    assert_eq!(events[1]["title"], "到家的第一天");
    assert_eq!(events[1]["occurred_at"], "2024-06-16T00:00:00Z");
    assert_eq!(events[2]["id"], format!("{pet_id}-birth"));
    assert_eq!(events[2]["event_subkind"], "birth");
    assert_eq!(events[2]["title"], "第一次来到这个世界");
    assert_eq!(events[2]["occurred_at"], "2024-04-01T00:00:00Z");
}

#[tokio::test]
async fn pet_quick_fact_rejects_duplicate_submission_for_same_pet() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138117").await;

    let create_pet_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "糯米",
                "species": "dog",
                "sex": "female"
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
    let submission_id = "00000000-0000-0000-0000-000000000111";

    for occurred_at in ["2026-06-13T09:20:10Z", "2026-06-13T12:35:00Z"] {
        let response = app
            .router()
            .oneshot(json_request(
                "POST",
                &format!("/api/v1/pets/{pet_id}/events"),
                json!({
                    "event_kind": "daily",
                    "event_subkind": "quick_fact",
                    "title": "便便正常",
                    "summary": "粪便状态：健康成型",
                    "visibility": "private",
                    "occurred_at": occurred_at,
                    "event_payload": {
                        "quick_fact_kind": "poop_normal",
                        "quick_fact_submission_id": submission_id
                    }
                }),
                Some(&user_id),
            ))
            .await
            .expect("create quick fact");

        if occurred_at == "2026-06-13T09:20:10Z" {
            assert_eq!(response.status(), StatusCode::CREATED);
        } else {
            assert_eq!(response.status(), StatusCode::CONFLICT);
            let body = response_json(response).await;
            assert_eq!(body["success"], false);
            assert_eq!(body["code"], "pet.quick_fact_duplicate");
            assert_eq!(body["message"], "今天已经记录过这个快捷状态");
        }
    }

    let timeline_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/pets/{pet_id}/timeline"),
            Some(&user_id),
        ))
        .await
        .expect("load pet timeline");
    assert_eq!(timeline_response.status(), StatusCode::OK);
    let timeline_body = response_json(timeline_response).await;
    let quick_fact_events = timeline_body["data"]["events"]
        .as_array()
        .expect("timeline events")
        .iter()
        .filter(|event| event["event_payload"]["quick_fact_kind"] == "poop_normal")
        .count();
    assert_eq!(quick_fact_events, 1);
}

#[tokio::test]
async fn pet_quick_fact_allows_same_kind_on_same_day_with_different_submissions() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138120").await;

    let create_pet_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "糯米",
                "species": "dog",
                "sex": "female"
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

    for (occurred_at, submission_id) in [
        (
            "2026-06-13T09:20:10Z",
            "00000000-0000-0000-0000-000000000121",
        ),
        (
            "2026-06-13T12:35:00Z",
            "00000000-0000-0000-0000-000000000122",
        ),
    ] {
        let response = app
            .router()
            .oneshot(json_request(
                "POST",
                &format!("/api/v1/pets/{pet_id}/events"),
                json!({
                    "event_kind": "daily",
                    "event_subkind": "quick_fact",
                    "title": "便便正常",
                    "summary": "粪便状态：健康成型",
                    "visibility": "private",
                    "occurred_at": occurred_at,
                    "event_payload": {
                        "quick_fact_kind": "poop_normal",
                        "quick_fact_submission_id": submission_id
                    }
                }),
                Some(&user_id),
            ))
            .await
            .expect("create quick fact");

        assert_eq!(response.status(), StatusCode::CREATED);
    }

    let timeline_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/pets/{pet_id}/timeline"),
            Some(&user_id),
        ))
        .await
        .expect("load pet timeline");
    assert_eq!(timeline_response.status(), StatusCode::OK);
    let timeline_body = response_json(timeline_response).await;
    let quick_fact_events = timeline_body["data"]["events"]
        .as_array()
        .expect("timeline events")
        .iter()
        .filter(|event| event["event_payload"]["quick_fact_kind"] == "poop_normal")
        .count();
    assert_eq!(quick_fact_events, 2);
}

#[tokio::test]
async fn pet_quick_fact_allows_different_kind_on_same_day() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138118").await;

    let create_pet_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "糯米",
                "species": "dog",
                "sex": "female"
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

    for (title, summary, quick_fact_kind) in [
        ("便便正常", "粪便状态：健康成型", "poop_normal"),
        ("精神不错", "精神与活力：正常平稳", "energy_normal"),
    ] {
        let response = app
            .router()
            .oneshot(json_request(
                "POST",
                &format!("/api/v1/pets/{pet_id}/events"),
                json!({
                    "event_kind": "daily",
                    "event_subkind": "quick_fact",
                    "title": title,
                    "summary": summary,
                    "visibility": "private",
                    "occurred_at": "2026-06-13T09:20:00Z",
                    "event_payload": {
                        "quick_fact_kind": quick_fact_kind,
                        "quick_fact_submission_id": format!("00000000-0000-0000-0000-00000000013{}", if quick_fact_kind == "poop_normal" { "1" } else { "2" })
                    }
                }),
                Some(&user_id),
            ))
            .await
            .expect("create quick fact");

        assert_eq!(response.status(), StatusCode::CREATED);
    }
}

#[tokio::test]
async fn pet_quick_fact_rejects_missing_or_unknown_kind() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138119").await;

    let create_pet_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "糯米",
                "species": "dog",
                "sex": "female"
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

    for (payload, expected_message) in [
        (json!({}), "快捷状态缺少类型"),
        (
            json!({ "quick_fact_kind": "fed", "quick_fact_submission_id": "00000000-0000-0000-0000-000000000141" }),
            "快捷状态类型无效",
        ),
        (
            json!({ "quick_fact_kind": "poop_normal" }),
            "快捷状态缺少提交标识",
        ),
        (
            json!({ "quick_fact_kind": "poop_normal", "quick_fact_submission_id": "bad-submission-id" }),
            "快捷状态提交标识无效",
        ),
    ] {
        let response = app
            .router()
            .oneshot(json_request(
                "POST",
                &format!("/api/v1/pets/{pet_id}/events"),
                json!({
                    "event_kind": "daily",
                    "event_subkind": "quick_fact",
                    "title": "便便正常",
                    "summary": "粪便状态：健康成型",
                    "visibility": "private",
                    "occurred_at": "2026-06-13T09:20:00Z",
                    "event_payload": payload
                }),
                Some(&user_id),
            ))
            .await
            .expect("create quick fact");

        assert_eq!(response.status(), StatusCode::BAD_REQUEST);
        let body = response_json(response).await;
        assert_eq!(body["success"], false);
        assert_eq!(body["code"], "pet.invalid_input");
        assert_eq!(body["message"], expected_message);
    }
}

#[tokio::test]
async fn pet_profile_create_normalizes_name_and_breed_whitespace() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138111").await;

    let create_pet_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "奶  盖 宝 宝 兔 兔",
                "species": "cat",
                "breed": "英 国 长 毛 猫 稀 有 毛 色 版 本",
                "sex": "female",
                "birthday": "2024-04-01"
            }),
            Some(&user_id),
        ))
        .await
        .expect("create pet");

    assert_eq!(create_pet_response.status(), StatusCode::CREATED);
    let body = response_json(create_pet_response).await;
    assert_eq!(body["data"]["name"], "奶盖宝宝兔兔");
    assert_eq!(body["data"]["breed"], "英国长毛猫稀有毛色版本");
}

#[tokio::test]
async fn pet_profile_update_allows_six_name_characters_after_whitespace_normalization() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138112").await;

    let create_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "汤圆",
                "species": "dog",
                "sex": "male"
            }),
            Some(&user_id),
        ))
        .await
        .expect("create pet");
    assert_eq!(create_response.status(), StatusCode::CREATED);
    let create_body = response_json(create_response).await;
    let pet_id = create_body["data"]["id"].as_str().expect("pet id");

    let update_response = app
        .router()
        .oneshot(json_request(
            "PATCH",
            &format!("/api/v1/pets/{pet_id}"),
            json!({
                "name": "奶 盖 宝 宝 兔 兔",
                "breed": "超 长 长 长 长 长 长 长 长 长 长 品 种"
            }),
            Some(&user_id),
        ))
        .await
        .expect("update pet");

    assert_eq!(update_response.status(), StatusCode::OK);
    let body = response_json(update_response).await;
    assert_eq!(body["data"]["name"], "奶盖宝宝兔兔");
    assert_eq!(body["data"]["breed"], "超长长长长长长长长长长品种");
}

#[tokio::test]
async fn pet_profile_rejects_name_over_six_non_whitespace_characters() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138113").await;

    let create_pet_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "一 二 三 四 五 六 七",
                "species": "cat",
                "sex": "female"
            }),
            Some(&user_id),
        ))
        .await
        .expect("create pet");

    assert_eq!(create_pet_response.status(), StatusCode::BAD_REQUEST);
    let body = response_json(create_pet_response).await;
    assert_eq!(body["success"], false);
    assert_eq!(body["code"], "pet.invalid_input");
    assert_eq!(body["message"], "宠物名称最多 6 个字");
}

#[tokio::test]
async fn pet_event_detail_returns_current_user_event() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138114").await;

    let create_pet_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "糯米",
                "species": "dog",
                "breed": "比熊犬",
                "sex": "female",
                "birthday": "2024-04-01"
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

    let create_event_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/events"),
            json!({
                "event_kind": "health",
                "event_subkind": "weight",
                "title": "体重记录",
                "summary": "5.2kg，较上次稳定",
                "visibility": "private",
                "occurred_at": "2026-06-13T09:20:00Z",
                "event_payload": {
                    "weight_kg": 5.2
                }
            }),
            Some(&user_id),
        ))
        .await
        .expect("create pet event");
    assert_eq!(create_event_response.status(), StatusCode::CREATED);
    let create_event_body = response_json(create_event_response).await;
    let event_id = create_event_body["data"]["id"]
        .as_str()
        .expect("event id")
        .to_owned();

    let detail_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/pet-events/{event_id}"),
            Some(&user_id),
        ))
        .await
        .expect("load event detail");

    assert_eq!(detail_response.status(), StatusCode::OK);
    let body = response_json(detail_response).await;
    assert_eq!(body["success"], true);
    assert_eq!(body["code"], "pet.event_loaded");
    assert_eq!(body["message"], "宠物事件已加载");
    assert_eq!(body["data"]["id"], event_id);
    assert_eq!(body["data"]["pet_id"], pet_id);
    assert_eq!(body["data"]["title"], "体重记录");
    assert_eq!(body["data"]["summary"], "5.2kg，较上次稳定");
    assert_eq!(body["data"]["event_kind"], "health");
    assert_eq!(body["data"]["record_revision"], 1);
}

#[tokio::test]
async fn pet_event_delete_removes_event_from_detail_and_timeline() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138115").await;

    let create_pet_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "糯米",
                "species": "dog",
                "sex": "female"
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

    let create_event_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/events"),
            json!({
                "event_kind": "health",
                "event_subkind": "appetite_normal",
                "title": "食欲正常",
                "summary": "今天食欲正常",
                "visibility": "private",
                "occurred_at": "2026-06-13T09:20:00Z",
                "event_payload": {
                    "quick_fact_kind": "appetite_normal"
                }
            }),
            Some(&user_id),
        ))
        .await
        .expect("create quick fact event");
    assert_eq!(create_event_response.status(), StatusCode::CREATED);
    let create_event_body = response_json(create_event_response).await;
    let event_id = create_event_body["data"]["id"]
        .as_str()
        .expect("event id")
        .to_owned();

    let delete_response = app
        .router()
        .oneshot(empty_request(
            "DELETE",
            &format!("/api/v1/pet-events/{event_id}"),
            Some(&user_id),
        ))
        .await
        .expect("delete pet event");
    assert_eq!(delete_response.status(), StatusCode::OK);
    let delete_body = response_json(delete_response).await;
    assert_eq!(delete_body["success"], true);
    assert_eq!(delete_body["code"], "pet.event_deleted");
    assert_eq!(delete_body["data"]["id"], event_id);
    assert_eq!(delete_body["data"]["deleted"], true);

    let detail_after_delete = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/pet-events/{event_id}"),
            Some(&user_id),
        ))
        .await
        .expect("load deleted event detail");
    assert_eq!(detail_after_delete.status(), StatusCode::NOT_FOUND);
    let detail_body = response_json(detail_after_delete).await;
    assert_eq!(detail_body["code"], "pet.event_not_found");

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
    let timeline_body = response_json(timeline_response).await;
    let items = timeline_body["data"]["events"].as_array().unwrap();
    assert!(
        items.iter().all(|item| item["id"] != event_id),
        "deleted event must be removed from timeline"
    );
}

#[tokio::test]
async fn pet_event_detail_allows_active_co_caretaker_relation() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let owner_user_id = login_user_id(&app, "13800138241").await;
    let co_caretaker_user_id = login_user_id(&app, "13800138242").await;

    let create_pet_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "糯米",
                "species": "dog",
                "sex": "female"
            }),
            Some(&owner_user_id),
        ))
        .await
        .expect("create pet");
    assert_eq!(create_pet_response.status(), StatusCode::CREATED);
    let create_pet_body = response_json(create_pet_response).await;
    let pet_id = create_pet_body["data"]["id"]
        .as_str()
        .expect("pet id")
        .to_owned();

    app.seed_active_pet_co_caretaker(&pet_id, &co_caretaker_user_id)
        .await;

    let create_event_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/events"),
            json!({
                "event_kind": "health",
                "title": "体重记录",
                "summary": "5.2kg",
                "occurred_at": "2026-06-13T09:20:00Z",
                "event_payload": {
                    "weight_kg": 5.2
                }
            }),
            Some(&owner_user_id),
        ))
        .await
        .expect("create pet event");
    assert_eq!(create_event_response.status(), StatusCode::CREATED);
    let create_event_body = response_json(create_event_response).await;
    let event_id = create_event_body["data"]["id"]
        .as_str()
        .expect("event id")
        .to_owned();

    let detail_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/pet-events/{event_id}"),
            Some(&co_caretaker_user_id),
        ))
        .await
        .expect("co caretaker load event detail");

    assert_eq!(detail_response.status(), StatusCode::OK);
    let body = response_json(detail_response).await;
    assert_eq!(body["code"], "pet.event_loaded");
    assert_eq!(body["data"]["id"], event_id);
    assert_eq!(body["data"]["pet_id"], pet_id);
}
