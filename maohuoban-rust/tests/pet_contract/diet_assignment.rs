use super::*;

#[tokio::test]
async fn set_current_staple_writes_diet_change_event() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800139011").await;

    let pet_id = create_pet(&app, &user_id).await;
    let food_item_id = create_food_inventory_item(&app, &user_id, "渴望六种鱼").await;

    let set_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/diet/staple"),
            json!({
                "food_item_id": food_item_id,
                "reason": "用户设置"
            }),
            Some(&user_id),
        ))
        .await
        .expect("set current staple");
    assert_eq!(set_response.status(), StatusCode::CREATED);
    let set_body = response_json(set_response).await;
    let assignment_id = set_body["data"]["id"].as_str().expect("assignment id");

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
    let first_event = &timeline_body["data"]["events"][0];
    assert_eq!(first_event["event_kind"], "daily");
    assert_eq!(first_event["event_subkind"], "diet_change");
    assert_eq!(
        first_event["event_payload"]["to_food_item_id"],
        food_item_id
    );
    assert_eq!(first_event["event_payload"]["assignment_id"], assignment_id);
}

#[tokio::test]
async fn diet_context_returns_recent_diet_change_facts() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800139028").await;

    let pet_id = create_pet(&app, &user_id).await;
    let food_item_id = create_food_inventory_item(&app, &user_id, "渴望六种鱼").await;

    let set_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/diet/staple"),
            json!({
                "food_item_id": food_item_id,
                "reason": "用户设置"
            }),
            Some(&user_id),
        ))
        .await
        .expect("set current staple");
    assert_eq!(set_response.status(), StatusCode::CREATED);
    let set_body = response_json(set_response).await;
    let assignment_id = set_body["data"]["id"].as_str().expect("assignment id");

    let context_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/pets/{pet_id}/diet-context"),
            Some(&user_id),
        ))
        .await
        .expect("load diet context");
    assert_eq!(context_response.status(), StatusCode::OK);
    let context_body = response_json(context_response).await;
    let diet_change = &context_body["data"]["recent_diet_changes"][0];
    assert_eq!(diet_change["event_subkind"], "diet_change");
    assert_eq!(diet_change["to_food_item_id"], food_item_id);
    assert_eq!(diet_change["assignment_id"], assignment_id);
    assert_eq!(diet_change["transition_state"], "started");
}

#[tokio::test]
async fn set_current_staple_rejects_cross_user_pet_mutation() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let owner_user_id = login_user_id(&app, "13800139012").await;
    let other_user_id = login_user_id(&app, "13800139013").await;

    let pet_id = create_pet(&app, &owner_user_id).await;
    let other_food_item_id = create_food_inventory_item(&app, &other_user_id, "其他人的主粮").await;

    let set_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/diet/staple"),
            json!({
                "food_item_id": other_food_item_id,
                "reason": "越权设置"
            }),
            Some(&other_user_id),
        ))
        .await
        .expect("cross user set current staple");
    assert_eq!(set_response.status(), StatusCode::NOT_FOUND);

    let owner_list_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/pets/{pet_id}/diet/assignments"),
            Some(&owner_user_id),
        ))
        .await
        .expect("owner list diet assignments");
    assert_eq!(owner_list_response.status(), StatusCode::OK);
    let owner_list_body = response_json(owner_list_response).await;
    assert_eq!(
        owner_list_body["data"]
            .as_array()
            .expect("assignments")
            .len(),
        0
    );
}

#[tokio::test]
async fn set_current_staple_rejects_archived_food_inventory_item() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800139035").await;

    let pet_id = create_pet(&app, &user_id).await;
    let food_item_id = create_food_inventory_item(&app, &user_id, "已归档主粮").await;
    let archive_response = app
        .router()
        .oneshot(empty_request(
            "DELETE",
            &format!("/api/v1/food-inventory/items/{food_item_id}"),
            Some(&user_id),
        ))
        .await
        .expect("archive food inventory item");
    assert_eq!(archive_response.status(), StatusCode::OK);

    let set_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/diet/staple"),
            json!({
                "food_item_id": food_item_id,
                "reason": "不能设置归档资产"
            }),
            Some(&user_id),
        ))
        .await
        .expect("set current staple with archived food item");
    assert_eq!(set_response.status(), StatusCode::BAD_REQUEST);

    let owner_list_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/pets/{pet_id}/diet/assignments"),
            Some(&user_id),
        ))
        .await
        .expect("owner list diet assignments");
    assert_eq!(owner_list_response.status(), StatusCode::OK);
    let owner_list_body = response_json(owner_list_response).await;
    assert_eq!(
        owner_list_body["data"]
            .as_array()
            .expect("assignments")
            .len(),
        0
    );
}

#[tokio::test]
async fn set_diet_assignment_keeps_multiple_active_items_for_same_role() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800139027").await;

    let pet_id = create_pet(&app, &user_id).await;
    let salmon_treat_id =
        create_food_inventory_item_with_category(&app, &user_id, "冻干三文鱼", "treats").await;
    let chicken_treat_id =
        create_food_inventory_item_with_category(&app, &user_id, "鸡肉小方", "treats").await;

    for food_item_id in [&salmon_treat_id, &chicken_treat_id] {
        let response = app
            .router()
            .oneshot(json_request(
                "POST",
                &format!("/api/v1/pets/{pet_id}/diet/assignments"),
                json!({
                    "food_item_id": food_item_id,
                    "role": "usual_treat",
                    "reason": "常用零食"
                }),
                Some(&user_id),
            ))
            .await
            .expect("set usual treat assignment");
        assert_eq!(response.status(), StatusCode::CREATED);
    }

    let list_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/pets/{pet_id}/diet/assignments"),
            Some(&user_id),
        ))
        .await
        .expect("list diet assignments");
    assert_eq!(list_response.status(), StatusCode::OK);
    let list_body = response_json(list_response).await;
    let usual_treat_ids: Vec<&str> = list_body["data"]
        .as_array()
        .expect("assignments")
        .iter()
        .filter(|assignment| assignment["role"] == "usual_treat")
        .map(|assignment| assignment["food_item_id"].as_str().expect("food item id"))
        .collect();

    assert_eq!(usual_treat_ids.len(), 2);
    assert!(usual_treat_ids.contains(&salmon_treat_id.as_str()));
    assert!(usual_treat_ids.contains(&chicken_treat_id.as_str()));
}

#[tokio::test]
async fn diet_assignments_reject_current_staple_role() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800139036").await;

    let pet_id = create_pet(&app, &user_id).await;
    let food_item_id = create_food_inventory_item(&app, &user_id, "渴望六种鱼").await;

    let response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/diet/assignments"),
            json!({
                "food_item_id": food_item_id,
                "role": "current_staple",
                "reason": "必须走当前主粮专用接口"
            }),
            Some(&user_id),
        ))
        .await
        .expect("set current staple through generic assignment endpoint");
    assert_eq!(response.status(), StatusCode::BAD_REQUEST);

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
    assert_eq!(
        timeline_body["data"]["events"]
            .as_array()
            .expect("timeline events")
            .len(),
        0
    );
}

#[tokio::test]
async fn diet_assignments_reject_cross_user_list_and_end() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let owner_user_id = login_user_id(&app, "13800139025").await;
    let other_user_id = login_user_id(&app, "13800139026").await;

    let pet_id = create_pet(&app, &owner_user_id).await;
    let food_item_id = create_food_inventory_item(&app, &owner_user_id, "渴望六种鱼").await;
    let set_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/diet/staple"),
            json!({
                "food_item_id": food_item_id,
                "reason": "用户设置"
            }),
            Some(&owner_user_id),
        ))
        .await
        .expect("set current staple");
    assert_eq!(set_response.status(), StatusCode::CREATED);
    let set_body = response_json(set_response).await;
    let assignment_id = set_body["data"]["id"]
        .as_str()
        .expect("assignment id")
        .to_owned();

    let other_list_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/pets/{pet_id}/diet/assignments"),
            Some(&other_user_id),
        ))
        .await
        .expect("cross user list diet assignments");
    assert_eq!(other_list_response.status(), StatusCode::NOT_FOUND);

    let other_end_response = app
        .router()
        .oneshot(empty_request(
            "DELETE",
            &format!("/api/v1/pets/{pet_id}/diet/assignments/{assignment_id}"),
            Some(&other_user_id),
        ))
        .await
        .expect("cross user end diet assignment");
    assert_eq!(other_end_response.status(), StatusCode::NOT_FOUND);

    let owner_list_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/pets/{pet_id}/diet/assignments"),
            Some(&owner_user_id),
        ))
        .await
        .expect("owner list diet assignments");
    assert_eq!(owner_list_response.status(), StatusCode::OK);
    let owner_list_body = response_json(owner_list_response).await;
    assert_eq!(
        owner_list_body["data"]
            .as_array()
            .expect("assignments")
            .len(),
        1
    );
}

async fn create_pet(app: &maohuoban_rust::test_support::AuthTestApp, user_id: &str) -> String {
    let response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "小年糕",
                "species": "cat",
                "sex": "female"
            }),
            Some(user_id),
        ))
        .await
        .expect("create pet");
    assert_eq!(response.status(), StatusCode::CREATED);
    let body = response_json(response).await;
    body["data"]["id"].as_str().expect("pet id").to_owned()
}

async fn create_food_inventory_item(
    app: &maohuoban_rust::test_support::AuthTestApp,
    user_id: &str,
    name: &str,
) -> String {
    create_food_inventory_item_with_category(app, user_id, name, "main_food").await
}

async fn create_food_inventory_item_with_category(
    app: &maohuoban_rust::test_support::AuthTestApp,
    user_id: &str,
    name: &str,
    category: &str,
) -> String {
    let response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/food-inventory/items",
            json!({
                "name": name,
                "brand": "Orijen",
                "category": category,
                "inventory_status": "sealed",
                "quantity": 1
            }),
            Some(user_id),
        ))
        .await
        .expect("create food inventory item");
    assert_eq!(response.status(), StatusCode::CREATED);
    let body = response_json(response).await;
    body["data"]["id"]
        .as_str()
        .expect("food item id")
        .to_owned()
}
