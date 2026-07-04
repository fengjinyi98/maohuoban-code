use super::*;

#[tokio::test]
async fn food_inventory_item_detail_returns_linked_pets_timeline_and_consumption_summary() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800139038").await;

    let avatar_asset_id = create_pet_avatar_asset(&app, &user_id).await;
    let pet_id = create_pet(&app, &user_id, &avatar_asset_id).await;
    let food_item_id = create_food_inventory_item(&app, &user_id).await;

    create_feeding_events(&app, &user_id, &pet_id, &food_item_id).await;

    let detail_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/food-inventory/items/{food_item_id}/detail"),
            Some(&user_id),
        ))
        .await
        .expect("load food inventory item detail");
    assert_eq!(detail_response.status(), StatusCode::OK);
    let detail_body = response_json(detail_response).await;

    assert_eq!(detail_body["code"], "food_inventory.item_detail_loaded");
    assert_eq!(detail_body["data"]["item"]["id"], food_item_id);

    assert_linked_pet(&detail_body, &pet_id, &avatar_asset_id);
    assert_feeding_timeline(&detail_body, &pet_id, &avatar_asset_id);
    assert_consumption_summary(&detail_body);
}

async fn create_feeding_events(
    app: &maohuoban_rust::test_support::AuthTestApp,
    user_id: &str,
    pet_id: &str,
    food_item_id: &str,
) {
    for (amount_text, occurred_at) in [
        ("少一点", "2026-06-25T08:00:00Z"),
        ("正常", "2026-06-26T08:00:00Z"),
        ("多一点", "2026-06-27T08:00:00Z"),
    ] {
        let response = app
            .router()
            .oneshot(json_request(
                "POST",
                &format!("/api/v1/pets/{pet_id}/events"),
                feeding_event_body(food_item_id, amount_text, occurred_at),
                Some(user_id),
            ))
            .await
            .expect("create feeding event");
        assert_eq!(response.status(), StatusCode::CREATED);
    }
}

fn feeding_event_body(
    food_item_id: &str,
    amount_text: &str,
    occurred_at: &str,
) -> serde_json::Value {
    json!({
        "event_kind": "daily",
        "event_subkind": "feeding",
        "title": "已喂",
        "summary": format!("喂食：主粮：渴望六种鱼，份量：{amount_text}"),
        "visibility": "private",
        "occurred_at": occurred_at,
        "event_payload": {
            "food_item_id": food_item_id,
            "food_role": "main_food",
            "amount_text": amount_text,
            "food_snapshot": {
                "name": "渴望六种鱼",
                "brand": "Orijen",
                "category": "main_food",
                "spec": "5.4kg"
            },
            "is_default_food": true,
            "note": null,
            "attachment_asset_ids": []
        }
    })
}

fn assert_linked_pet(detail_body: &serde_json::Value, pet_id: &str, avatar_asset_id: &str) {
    let linked_pets = detail_body["data"]["linked_pets"]
        .as_array()
        .expect("linked pets");
    assert_eq!(linked_pets.len(), 1);
    assert_eq!(linked_pets[0]["pet_id"], pet_id);
    assert_eq!(linked_pets[0]["species"], "cat");
    assert_eq!(linked_pets[0]["sex"], "male");
    assert_eq!(linked_pets[0]["avatar_asset_id"], avatar_asset_id);
    assert_eq!(
        linked_pets[0]["avatar_url"],
        format!("/api/v1/media/assets/{avatar_asset_id}/content")
    );
    assert_eq!(linked_pets[0]["source"], "feeding_event");
}

fn assert_feeding_timeline(detail_body: &serde_json::Value, pet_id: &str, avatar_asset_id: &str) {
    let timeline = detail_body["data"]["feeding_timeline"]
        .as_array()
        .expect("feeding timeline");
    assert_eq!(timeline.len(), 3);
    assert_eq!(timeline[0]["amount_text"], "多一点");
    assert_eq!(timeline[1]["amount_text"], "正常");
    assert_eq!(timeline[2]["amount_text"], "少一点");
    assert_eq!(timeline[0]["pet_id"], pet_id);
    assert_eq!(timeline[0]["pet_species"], "cat");
    assert_eq!(timeline[0]["pet_sex"], "male");
    assert_eq!(timeline[0]["pet_avatar_asset_id"], avatar_asset_id);
    assert_eq!(
        timeline[0]["pet_avatar_url"],
        format!("/api/v1/media/assets/{avatar_asset_id}/content")
    );
    assert_eq!(timeline[0]["food_snapshot"]["name"], "渴望六种鱼");
}

fn assert_consumption_summary(detail_body: &serde_json::Value) {
    let summary = &detail_body["data"]["consumption_summary"];
    assert_eq!(summary["feeding_count"], 3);
    assert_eq!(summary["first_fed_at"], "2026-06-25T08:00:00Z");
    assert_eq!(summary["last_fed_at"], "2026-06-27T08:00:00Z");
    assert_eq!(summary["active_days"], 3);

    let distribution = summary["amount_distribution"]
        .as_array()
        .expect("amount distribution");
    assert_eq!(distribution.len(), 3);
    assert_eq!(distribution[0]["amount_text"], "少一点");
    assert_eq!(distribution[0]["count"], 1);
    assert_eq!(distribution[1]["amount_text"], "正常");
    assert_eq!(distribution[1]["count"], 1);
    assert_eq!(distribution[2]["amount_text"], "多一点");
    assert_eq!(distribution[2]["count"], 1);
}

async fn create_pet_avatar_asset(
    app: &maohuoban_rust::test_support::AuthTestApp,
    user_id: &str,
) -> String {
    let body = upload_pending_media(
        app,
        "/api/v1/pet-media/avatar",
        "avatar.png",
        "image/png",
        &tiny_png(),
        user_id,
    )
    .await;
    body["data"]["asset"]["id"]
        .as_str()
        .expect("avatar asset id")
        .to_owned()
}

async fn create_pet(
    app: &maohuoban_rust::test_support::AuthTestApp,
    user_id: &str,
    avatar_asset_id: &str,
) -> String {
    let response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "饭团",
                "species": "cat",
                "sex": "male",
                "avatar_asset_id": avatar_asset_id
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
) -> String {
    let response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/food-inventory/items",
            json!({
                "name": "渴望六种鱼",
                "brand": "Orijen",
                "category": "main_food",
                "quantity": 1,
                "unit": "袋",
                "spec": "5.4kg",
                "production_date": "2025-07-15",
                "shelf_life_months": 18
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
