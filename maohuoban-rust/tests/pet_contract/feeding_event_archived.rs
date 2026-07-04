use super::*;

#[tokio::test]
async fn feeding_event_rejects_archived_food_item_reference() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800139036").await;

    let pet_id = create_pet(&app, &user_id).await;
    let food_item_id = create_food_inventory_item(&app, &user_id).await;
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

    let event_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/events"),
            json!({
                "event_kind": "daily",
                "event_subkind": "feeding",
                "title": "已喂",
                "summary": "喂食：主粮：已归档主粮，份量：正常",
                "visibility": "private",
                "occurred_at": "2026-06-25T08:30:00Z",
                "event_payload": {
                    "food_item_id": food_item_id,
                    "food_role": "main_food",
                    "amount_text": "正常",
                    "is_default_food": false,
                    "note": null,
                    "attachment_asset_ids": []
                }
            }),
            Some(&user_id),
        ))
        .await
        .expect("create feeding event with archived food item");

    assert_eq!(event_response.status(), StatusCode::BAD_REQUEST);

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
    assert_eq!(
        context_body["data"]["recent_feeding_events"]
            .as_array()
            .expect("feeding events")
            .len(),
        0
    );
}

async fn create_pet(app: &maohuoban_rust::test_support::AuthTestApp, user_id: &str) -> String {
    let response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "饭团",
                "species": "cat",
                "sex": "male"
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
