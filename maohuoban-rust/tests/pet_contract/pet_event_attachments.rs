use super::*;

#[tokio::test]
async fn feeding_event_attachment_upload_enters_pet_timeline() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800139201").await;
    let pet_id = create_pet(&app, &user_id).await;
    let food_item_id = create_food_inventory_item(&app, &user_id).await;
    let asset_id = upload_event_attachment(&app, &user_id).await;

    let event_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/events"),
            json!({
                "event_kind": "daily",
                "event_subkind": "feeding",
                "title": "已喂",
                "summary": "喂食：主粮：渴望六种鱼，份量：正常",
                "visibility": "private",
                "occurred_at": "2026-06-25T08:30:00Z",
                "event_payload": {
                    "food_item_id": food_item_id,
                    "food_role": "main_food",
                    "amount_text": "正常",
                    "food_snapshot": {
                        "name": "渴望六种鱼",
                        "brand": "Orijen",
                        "category": "main_food",
                        "spec": "5.4kg"
                    },
                    "is_default_food": true,
                    "note": null,
                    "attachment_asset_ids": [asset_id]
                }
            }),
            Some(&user_id),
        ))
        .await
        .expect("create feeding event with attachment");
    assert_eq!(event_response.status(), StatusCode::CREATED);
    let event_body = response_json(event_response).await;
    assert_eq!(
        event_body["data"]["event_payload"]["attachment_asset_ids"][0],
        asset_id
    );

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
        timeline_body["data"]["events"][0]["event_payload"]["attachment_asset_ids"][0],
        asset_id
    );
}

#[tokio::test]
async fn abnormal_event_attachment_upload_enters_pet_timeline() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800139202").await;
    let pet_id = create_pet(&app, &user_id).await;
    let asset_id = upload_event_attachment(&app, &user_id).await;

    let event_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/events"),
            json!({
                "event_kind": "health",
                "event_subkind": "abnormal_symptom",
                "title": "异常记录",
                "summary": "异常：食欲、精神，程度：明显",
                "visibility": "private",
                "occurred_at": "2026-06-25T09:30:00Z",
                "event_payload": {
                    "symptom_kinds": ["appetite", "energy"],
                    "severity": "obvious",
                    "symptom_details": ["吃很少", "没精神"],
                    "note": "晚餐剩了一半",
                    "attachment_asset_ids": [asset_id]
                }
            }),
            Some(&user_id),
        ))
        .await
        .expect("create abnormal event with attachment");
    assert_eq!(event_response.status(), StatusCode::CREATED);

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
        timeline_body["data"]["events"][0]["event_payload"]["attachment_asset_ids"][0],
        asset_id
    );
}

#[tokio::test]
async fn event_rejects_cross_user_attachment_asset() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let owner_user_id = login_user_id(&app, "13800139203").await;
    let other_user_id = login_user_id(&app, "13800139204").await;
    let pet_id = create_pet(&app, &owner_user_id).await;
    let other_asset_id = upload_event_attachment(&app, &other_user_id).await;

    let event_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/events"),
            json!({
                "event_kind": "health",
                "event_subkind": "abnormal_symptom",
                "title": "异常记录",
                "summary": "异常：食欲，程度：明显",
                "visibility": "private",
                "occurred_at": "2026-06-25T09:30:00Z",
                "event_payload": {
                    "symptom_kinds": ["appetite"],
                    "severity": "obvious",
                    "attachment_asset_ids": [other_asset_id]
                }
            }),
            Some(&owner_user_id),
        ))
        .await
        .expect("create event with other user's attachment");

    assert_eq!(event_response.status(), StatusCode::NOT_FOUND);
}

async fn upload_event_attachment(
    app: &maohuoban_rust::test_support::AuthTestApp,
    user_id: &str,
) -> String {
    let upload_body = upload_pending_media(
        app,
        "/api/v1/pet-event-media",
        "event-photo.png",
        "image/png",
        &tiny_png(),
        user_id,
    )
    .await;
    assert_eq!(upload_body["code"], "pet.event_attachment_uploaded");
    assert_eq!(
        upload_body["data"]["asset"]["usage_kind"],
        "pet.event.attachment"
    );
    let asset_id = upload_body["data"]["asset"]["id"]
        .as_str()
        .expect("event attachment asset id")
        .to_owned();
    assert_eq!(
        upload_body["data"]["asset"]["url"],
        format!("/api/v1/media/assets/{asset_id}/content")
    );
    asset_id
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
