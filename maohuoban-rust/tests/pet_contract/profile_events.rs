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
