use super::*;

#[tokio::test]
async fn pet_profile_crud_persists_extended_profile_fields() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138131").await;

    let create_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "奶盖",
                "species": "cat",
                "breed": "布偶",
                "sex": "female",
                "birthday": "2024-03-20",
                "microchip_number": "156000000000001",
                "arrival_date": "2024-05-01",
                "weight_grams": 4200,
                "neuter_status": "neutered",
                "personality_tags": ["亲人", "爱玩"],
                "note": "对鸡肉过敏"
            }),
            Some(&user_id),
        ))
        .await
        .expect("create extended pet");
    assert_eq!(create_response.status(), StatusCode::CREATED);
    let create_body = response_json(create_response).await;
    assert_eq!(
        create_body["data"]["profile_number"]
            .as_str()
            .unwrap()
            .len(),
        16
    );
    assert_eq!(create_body["data"]["microchip_number"], "156000000000001");
    assert_eq!(create_body["data"]["arrival_date"], "2024-05-01");
    assert_eq!(create_body["data"]["weight_grams"], 4200);
    assert_eq!(create_body["data"]["neuter_status"], "neutered");
    assert_eq!(create_body["data"]["personality_tags"][0], "亲人");
    assert_eq!(create_body["data"]["note"], "对鸡肉过敏");
    assert_name_edit_policy(&create_body["data"], 0, 5);
    let pet_id = create_body["data"]["id"].as_str().expect("pet id");

    let update_response = app
        .router()
        .oneshot(json_request(
            "PATCH",
            &format!("/api/v1/pets/{pet_id}"),
            json!({
                "name": "奶盖宝",
                "breed": "布偶猫",
                "weight_grams": 4350,
                "personality_tags": ["亲人", "安静"],
                "note": "鸡肉过敏，优先喂鸭肉"
            }),
            Some(&user_id),
        ))
        .await
        .expect("update pet");
    assert_eq!(update_response.status(), StatusCode::OK);
    let update_body = response_json(update_response).await;
    assert_eq!(update_body["code"], "pet.updated");
    assert_eq!(update_body["data"]["id"], pet_id);
    assert_eq!(update_body["data"]["name"], "奶盖宝");
    assert_eq!(update_body["data"]["breed"], "布偶猫");
    assert_eq!(update_body["data"]["weight_grams"], 4350);
    assert_eq!(update_body["data"]["microchip_number"], "156000000000001");
    assert_name_edit_policy(&update_body["data"], 1, 4);

    let detail_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/pets/{pet_id}"),
            Some(&user_id),
        ))
        .await
        .expect("load pet detail");
    assert_eq!(detail_response.status(), StatusCode::OK);
    let detail_body = response_json(detail_response).await;
    assert_eq!(detail_body["code"], "pet.loaded");
    assert_eq!(detail_body["data"]["id"], pet_id);
    assert_eq!(
        detail_body["data"]["profile_number"],
        create_body["data"]["profile_number"]
    );

    let list_response = app
        .router()
        .oneshot(empty_request("GET", "/api/v1/pets", Some(&user_id)))
        .await
        .expect("list pets");
    assert_eq!(list_response.status(), StatusCode::OK);
    let list_body = response_json(list_response).await;
    assert_eq!(list_body["code"], "pet.list_loaded");
    assert!(
        list_body["data"]["pets"]
            .as_array()
            .expect("pets")
            .iter()
            .any(|pet| pet["id"] == pet_id)
    );
}

#[tokio::test]
async fn pet_profile_rejects_microchip_replacement_after_it_is_locked() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138132").await;

    let create_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "汤圆",
                "species": "dog",
                "sex": "male",
                "microchip_number": "156000000000002"
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
                "microchip_number": "156000000000099"
            }),
            Some(&user_id),
        ))
        .await
        .expect("replace chip");

    assert_eq!(update_response.status(), StatusCode::BAD_REQUEST);
    let body = response_json(update_response).await;
    assert_eq!(body["success"], false);
    assert_eq!(body["code"], "pet.invalid_input");
}

#[tokio::test]
async fn pet_profile_update_returns_unchanged_without_touching_updated_at_for_noop_patch() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138133").await;

    let create_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "奶盖",
                "species": "cat",
                "breed": "布偶",
                "sex": "female",
                "birthday": "2024-03-20",
                "microchip_number": "156000000000003",
                "arrival_date": "2024-05-01",
                "weight_grams": 4200,
                "neuter_status": "neutered",
                "personality_tags": ["亲人", "爱玩"],
                "note": "对鸡肉过敏"
            }),
            Some(&user_id),
        ))
        .await
        .expect("create pet");
    assert_eq!(create_response.status(), StatusCode::CREATED);
    let create_body = response_json(create_response).await;
    let pet_id = create_body["data"]["id"].as_str().expect("pet id");
    let created_updated_at = create_body["data"]["updated_at"]
        .as_str()
        .expect("created updated_at");

    let update_response = app
        .router()
        .oneshot(json_request(
            "PATCH",
            &format!("/api/v1/pets/{pet_id}"),
            json!({
                "name": "奶盖",
                "species": "cat",
                "breed": "布偶",
                "sex": "female",
                "birthday": "2024-03-20",
                "microchip_number": "156000000000003",
                "arrival_date": "2024-05-01",
                "weight_grams": 4200,
                "neuter_status": "neutered",
                "personality_tags": ["亲人", "爱玩"],
                "note": "对鸡肉过敏"
            }),
            Some(&user_id),
        ))
        .await
        .expect("noop update pet");
    assert_eq!(update_response.status(), StatusCode::OK);
    let update_body = response_json(update_response).await;
    assert_eq!(update_body["code"], "pet.unchanged");
    assert_eq!(update_body["message"], "宠物档案未变化");
    assert_eq!(update_body["data"]["updated_at"], created_updated_at);
}

#[tokio::test]
async fn pet_profile_limits_name_changes_within_thirty_days() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138136").await;

    let create_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "团子",
                "species": "dog",
                "sex": "female"
            }),
            Some(&user_id),
        ))
        .await
        .expect("create pet");
    assert_eq!(create_response.status(), StatusCode::CREATED);
    let create_body = response_json(create_response).await;
    assert_eq!(
        create_body["data"]["name_edit_policy"]["display_text"],
        "30 天内最多修改 5 次名字。"
    );
    let pet_id = create_body["data"]["id"].as_str().expect("pet id");

    for (index, name) in ["小一", "小二", "小三", "小四", "小五"].iter().enumerate() {
        let update_response = app
            .router()
            .oneshot(json_request(
                "PATCH",
                &format!("/api/v1/pets/{pet_id}"),
                json!({ "name": name }),
                Some(&user_id),
            ))
            .await
            .expect("update pet name");
        assert_eq!(update_response.status(), StatusCode::OK);
        let update_body = response_json(update_response).await;
        assert_eq!(update_body["data"]["name"], *name);
        assert_eq!(
            update_body["data"]["name_edit_policy"]["remaining_count"],
            4 - i64::try_from(index).expect("index fits")
        );
    }

    let rejected_response = app
        .router()
        .oneshot(json_request(
            "PATCH",
            &format!("/api/v1/pets/{pet_id}"),
            json!({ "name": "小六" }),
            Some(&user_id),
        ))
        .await
        .expect("reject pet name");
    assert_eq!(rejected_response.status(), StatusCode::TOO_MANY_REQUESTS);
    let rejected_body = response_json(rejected_response).await;
    assert_eq!(rejected_body["success"], false);
    assert_eq!(rejected_body["code"], "pet.name_edit_limit_exceeded");
}
