use super::*;

#[tokio::test]
async fn diet_context_returns_recent_feeding_snapshot() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800139021").await;

    let pet_id = create_pet(&app, &user_id).await;
    let food_item_id = create_food_inventory_item(&app, &user_id).await;

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
                    "attachment_asset_ids": []
                }
            }),
            Some(&user_id),
        ))
        .await
        .expect("create feeding event");
    assert_eq!(event_response.status(), StatusCode::CREATED);

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
    let feeding = &context_body["data"]["recent_feeding_events"][0];
    assert_eq!(feeding["food_item_id"], food_item_id);
    assert_eq!(feeding["food_name"], "渴望六种鱼");
    assert_eq!(feeding["food_snapshot"]["name"], "渴望六种鱼");
    assert_eq!(feeding["food_snapshot"]["brand"], "Orijen");
}

#[tokio::test]
async fn diet_context_rejects_cross_user_access() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let owner_user_id = login_user_id(&app, "13800139022").await;
    let other_user_id = login_user_id(&app, "13800139023").await;

    let pet_id = create_pet(&app, &owner_user_id).await;

    let context_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/pets/{pet_id}/diet-context"),
            Some(&other_user_id),
        ))
        .await
        .expect("load diet context as other user");
    assert_eq!(context_response.status(), StatusCode::NOT_FOUND);
}

#[tokio::test]
async fn feeding_event_rejects_cross_user_food_item_reference() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let owner_user_id = login_user_id(&app, "13800139027").await;
    let other_user_id = login_user_id(&app, "13800139028").await;

    let pet_id = create_pet(&app, &owner_user_id).await;
    let other_food_item_id = create_food_inventory_item(&app, &other_user_id).await;

    let event_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/events"),
            json!({
                "event_kind": "daily",
                "event_subkind": "feeding",
                "title": "已喂",
                "summary": "喂食：主粮：其他人的粮，份量：正常",
                "visibility": "private",
                "occurred_at": "2026-06-25T08:30:00Z",
                "event_payload": {
                    "food_item_id": other_food_item_id,
                    "food_role": "main_food",
                    "amount_text": "正常",
                    "food_snapshot": {
                        "name": "其他人的粮",
                        "brand": "Other",
                        "category": "main_food",
                        "spec": "1kg"
                    },
                    "is_default_food": false,
                    "note": null,
                    "attachment_asset_ids": []
                }
            }),
            Some(&owner_user_id),
        ))
        .await
        .expect("create feeding event with other user's food item");

    assert_eq!(event_response.status(), StatusCode::NOT_FOUND);
}

#[tokio::test]
async fn feeding_event_uses_inventory_snapshot_for_food_reference() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800139029").await;

    let pet_id = create_pet(&app, &user_id).await;
    let food_item_id = create_food_inventory_item(&app, &user_id).await;

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
                        "name": "被客户端篡改的名称",
                        "brand": "Fake",
                        "category": "other",
                        "spec": "0g",
                        "unit": "罐"
                    },
                    "is_default_food": true,
                    "note": null,
                    "attachment_asset_ids": []
                }
            }),
            Some(&user_id),
        ))
        .await
        .expect("create feeding event with food item");
    assert_eq!(event_response.status(), StatusCode::CREATED);

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
    let feeding = &context_body["data"]["recent_feeding_events"][0];
    assert_eq!(feeding["food_snapshot"]["name"], "渴望六种鱼");
    assert_eq!(feeding["food_snapshot"]["brand"], "Orijen");
    assert_eq!(feeding["food_snapshot"]["category"], "main_food");
    assert_eq!(feeding["food_snapshot"]["spec"], "5.4kg");
    assert_eq!(feeding["food_snapshot"]["unit"], "袋");
}

#[tokio::test]
async fn feeding_event_snapshot_includes_inventory_cover_and_marks_sealed_item_in_use() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800139037").await;

    let pet_id = create_pet(&app, &user_id).await;
    let cover_asset_id = upload_food_inventory_cover(&app, &user_id).await;
    let food_item_id =
        create_food_inventory_item_with_status_and_cover(&app, &user_id, "sealed", &cover_asset_id)
            .await;

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
                        "name": "客户端名称",
                        "brand": "Client",
                        "category": "other",
                        "spec": "1g",
                        "cover_asset_id": null,
                        "cover_url": null
                    },
                    "is_default_food": false,
                    "note": null,
                    "attachment_asset_ids": []
                }
            }),
            Some(&user_id),
        ))
        .await
        .expect("create feeding event with sealed covered item");
    assert_eq!(event_response.status(), StatusCode::CREATED);

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
    let feeding = &context_body["data"]["recent_feeding_events"][0];
    assert_eq!(feeding["food_snapshot"]["cover_asset_id"], cover_asset_id);
    assert_eq!(
        feeding["food_snapshot"]["cover_url"],
        format!("/api/v1/media/assets/{cover_asset_id}/content")
    );

    let item_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/food-inventory/items/{food_item_id}"),
            Some(&user_id),
        ))
        .await
        .expect("get food item after feeding");
    assert_eq!(item_response.status(), StatusCode::OK);
    let item_body = response_json(item_response).await;
    assert_eq!(item_body["data"]["inventory_status"], "in_use");
}

#[tokio::test]
async fn diet_confirmation_candidates_return_unbound_inventory_changes_as_pending() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800139030").await;

    let pet_id = create_pet(&app, &user_id).await;
    let food_item_id = create_food_inventory_item(&app, &user_id).await;

    let candidates_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/pets/{pet_id}/diet-confirmation-candidates"),
            Some(&user_id),
        ))
        .await
        .expect("load diet confirmation candidates");
    assert_eq!(candidates_response.status(), StatusCode::OK);
    let candidates_body = response_json(candidates_response).await;
    let candidate = &candidates_body["data"]["candidates"][0];

    assert_eq!(candidate["food_item_id"], food_item_id);
    assert_eq!(candidate["food_name"], "渴望六种鱼");
    assert_eq!(candidate["category"], "main_food");
    assert_eq!(candidate["candidate_kind"], "possible_diet_change");
    assert_eq!(candidate["fact_strength"], "pending_confirmation");
    assert_eq!(candidate["source_change_kind"], "created");
    assert_eq!(
        candidate["source_question"],
        "最近新增的「渴望六种鱼」，饭团有吃过或正在换这款吗？"
    );
}

#[tokio::test]
async fn diet_confirmation_writes_agent_fact_and_derives_diet_change() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800139031").await;

    let pet_id = create_pet(&app, &user_id).await;
    let food_item_id = create_food_inventory_item(&app, &user_id).await;
    let source_question = "最近新增的「渴望六种鱼」，饭团有吃过或正在换这款吗？";

    let confirm_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/diet-confirmations"),
            json!({
                "food_item_id": food_item_id,
                "confirmed_fact_kind": "current_staple",
                "source_question": source_question,
                "derive_diet_change": true
            }),
            Some(&user_id),
        ))
        .await
        .expect("confirm diet candidate");
    assert_eq!(confirm_response.status(), StatusCode::CREATED);
    let confirm_body = response_json(confirm_response).await;
    assert!(confirm_body["data"]["confirmed_event_id"].is_string());
    assert!(confirm_body["data"]["assignment_id"].is_string());

    let context_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/pets/{pet_id}/diet-context"),
            Some(&user_id),
        ))
        .await
        .expect("load diet context after confirmation");
    assert_eq!(context_response.status(), StatusCode::OK);
    let context_body = response_json(context_response).await;
    assert_eq!(
        context_body["data"]["current_staple"]["food_item_id"],
        food_item_id
    );

    let timeline_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/pets/{pet_id}/timeline"),
            Some(&user_id),
        ))
        .await
        .expect("load timeline after confirmation");
    assert_eq!(timeline_response.status(), StatusCode::OK);
    let timeline_body = response_json(timeline_response).await;
    let events = timeline_body["data"]["events"]
        .as_array()
        .expect("timeline events");
    let confirmed_fact = events
        .iter()
        .find(|event| event["event_subkind"] == "agent_confirmed_fact")
        .expect("agent confirmed fact event");
    assert_eq!(
        confirmed_fact["event_payload"]["confirmed_fact_kind"],
        "current_staple"
    );
    assert_eq!(
        confirmed_fact["event_payload"]["linked_food_item_id"],
        food_item_id
    );
    assert_eq!(confirmed_fact["event_payload"]["linked_pet_id"], pet_id);
    assert_eq!(
        confirmed_fact["event_payload"]["confidence"],
        "user_confirmed"
    );
    assert_eq!(
        confirmed_fact["event_payload"]["source_question"],
        source_question
    );
    assert!(
        events
            .iter()
            .any(|event| event["event_subkind"] == "diet_change"
                && event["event_payload"]["to_food_item_id"] == food_item_id)
    );
}

#[tokio::test]
async fn diet_confirmation_derives_feeding_correction_fact() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800139032").await;

    let pet_id = create_pet(&app, &user_id).await;
    let food_item_id = create_food_inventory_item(&app, &user_id).await;
    let source_question = "刚才记录已喂时，饭团实际吃的是「渴望六种鱼」吗？";

    let confirm_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/diet-confirmations"),
            json!({
                "food_item_id": food_item_id,
                "confirmed_fact_kind": "feeding_correction",
                "source_question": source_question,
                "derive_diet_change": false,
                "derive_feeding_correction": true
            }),
            Some(&user_id),
        ))
        .await
        .expect("confirm feeding correction");
    assert_eq!(confirm_response.status(), StatusCode::CREATED);
    let confirm_body = response_json(confirm_response).await;
    let confirmed_event_id = confirm_body["data"]["confirmed_event_id"]
        .as_str()
        .expect("confirmed event id");
    let correction_event_id = confirm_body["data"]["correction_event_id"]
        .as_str()
        .expect("correction event id");
    assert!(confirm_body["data"]["assignment_id"].is_null());

    let timeline_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/pets/{pet_id}/timeline"),
            Some(&user_id),
        ))
        .await
        .expect("load timeline after feeding correction");
    assert_eq!(timeline_response.status(), StatusCode::OK);
    let timeline_body = response_json(timeline_response).await;
    let events = timeline_body["data"]["events"]
        .as_array()
        .expect("timeline events");

    let confirmed_fact = events
        .iter()
        .find(|event| event["event_subkind"] == "agent_confirmed_fact")
        .expect("agent confirmed fact event");
    assert_eq!(confirmed_fact["id"], confirmed_event_id);
    assert_eq!(
        confirmed_fact["event_payload"]["confirmed_fact_kind"],
        "feeding_correction"
    );
    assert_eq!(
        confirmed_fact["event_payload"]["linked_food_item_id"],
        food_item_id
    );

    let correction = events
        .iter()
        .find(|event| event["event_subkind"] == "feeding_correction")
        .expect("feeding correction event");
    assert_eq!(correction["id"], correction_event_id);
    assert_eq!(correction["event_payload"]["food_item_id"], food_item_id);
    assert_eq!(correction["event_payload"]["linked_pet_id"], pet_id);
    assert_eq!(
        correction["event_payload"]["confirmed_event_id"],
        confirmed_event_id
    );
    assert_eq!(
        correction["event_payload"]["source_question"],
        source_question
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
                "inventory_status": "in_use",
                "quantity": 1,
                "unit": "袋",
                "spec": "5.4kg"
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

async fn create_food_inventory_item_with_status_and_cover(
    app: &maohuoban_rust::test_support::AuthTestApp,
    user_id: &str,
    inventory_status: &str,
    cover_asset_id: &str,
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
                "inventory_status": inventory_status,
                "quantity": 1,
                "unit": "袋",
                "spec": "5.4kg",
                "cover_asset_id": cover_asset_id
            }),
            Some(user_id),
        ))
        .await
        .expect("create food inventory item with status and cover");
    assert_eq!(response.status(), StatusCode::CREATED);
    let body = response_json(response).await;
    body["data"]["id"]
        .as_str()
        .expect("food item id")
        .to_owned()
}

async fn upload_food_inventory_cover(
    app: &maohuoban_rust::test_support::AuthTestApp,
    user_id: &str,
) -> String {
    let upload_body = upload_pending_media(
        app,
        "/api/v1/food-inventory/media",
        "pantry-cover.png",
        "image/png",
        &tiny_png(),
        user_id,
    )
    .await;
    assert_eq!(upload_body["code"], "food_inventory.media_uploaded");
    upload_body["data"]["asset"]["id"]
        .as_str()
        .expect("cover asset id")
        .to_owned()
}
