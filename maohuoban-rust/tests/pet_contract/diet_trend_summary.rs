use super::*;

#[tokio::test]
async fn diet_trend_summary_returns_structured_food_segments_and_backend_explanation() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800139041").await;
    let pet_id = create_diet_trend_sample_data(&app, &user_id).await;

    let body = load_diet_trend_summary(&app, &user_id, &pet_id).await;

    assert_diet_trend_summary_meta(&body);
    assert_diet_trend_summary_segments(&body);
}

#[tokio::test]
async fn diet_trend_summary_returns_baseline_and_excludes_abnormal_days() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800139044").await;
    let pet_id = create_pet(&app, &user_id).await;
    let main_food_id = create_food_inventory_item(&app, &user_id, "主粮", "main_food").await;

    for day in 1..=14 {
        create_feeding_event(
            &app,
            &user_id,
            &pet_id,
            &main_food_id,
            "main_food",
            "正常",
            &format!("2026-07-{day:02}T08:00:00Z"),
        )
        .await;
    }
    create_abnormal_event(&app, &user_id, &pet_id, "2026-07-15T07:00:00Z").await;
    create_feeding_event(
        &app,
        &user_id,
        &pet_id,
        &main_food_id,
        "main_food",
        "少一点",
        "2026-07-15T08:00:00Z",
    )
    .await;

    let body = load_diet_trend_summary(&app, &user_id, &pet_id).await;
    let main_food = body["data"]["segments"]
        .as_array()
        .expect("segments")
        .iter()
        .find(|segment| segment["category"] == "main_food")
        .expect("main food segment");

    assert_eq!(main_food["baseline_score"], 1.0);
    assert_eq!(main_food["baseline_sample_days"], 14);
    assert_eq!(main_food["current_ratio"], 0.75);
    assert_eq!(body["data"]["health_context"]["excluded_sample_count"], 1);
    assert!(
        body["data"]["health_context"]["excluded_reasons"]
            .as_array()
            .expect("excluded reasons")
            .iter()
            .any(|reason| reason == "abnormal")
    );
}

#[tokio::test]
async fn diet_trend_summary_rejects_cross_user_pet_access() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let owner_user_id = login_user_id(&app, "13800139042").await;
    let other_user_id = login_user_id(&app, "13800139043").await;

    let pet_id = create_pet(&app, &owner_user_id).await;

    let response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/pets/{pet_id}/diet-trend-summary"),
            Some(&other_user_id),
        ))
        .await
        .expect("load diet trend summary as other user");
    assert_eq!(response.status(), StatusCode::NOT_FOUND);
}

fn assert_diet_trend_summary_meta(body: &serde_json::Value) {
    assert_eq!(body["code"], "pet.diet_trend_summary_loaded");
    assert_eq!(body["data"]["window_days"], 30);
    assert_eq!(body["data"]["status"], "collecting_baseline");
    assert_eq!(body["data"]["confidence"]["level"], "medium");
    assert!(
        body["data"]["confidence"]["score"]
            .as_f64()
            .expect("confidence score")
            > 0.5
    );
    assert!(
        body["data"]["confidence"]["basis"]
            .as_array()
            .expect("basis")
            .len()
            >= 3
    );
    assert_eq!(body["data"]["explanation"]["title"], "饮食趋势是怎么生成的");
    assert!(
        body["data"]["explanation"]["body"]
            .as_str()
            .expect("explanation body")
            .contains("喂食记录")
    );
}

fn assert_diet_trend_summary_segments(body: &serde_json::Value) {
    let segments = body["data"]["segments"].as_array().expect("segments");
    assert_eq!(segments.len(), 4);
    assert_segment(segments, "main_food", 2.0, 44);
    assert_segment(segments, "wet_food", 1.0, 22);
    assert_segment(segments, "treats", 0.75, 17);
    assert_segment(segments, "nutrition", 0.75, 17);
    assert!(
        segments
            .iter()
            .all(|segment| segment["category"] != "cat_litter")
    );
    assert!(
        segments
            .iter()
            .all(|segment| segment["category"] != "medicine")
    );
}

async fn load_diet_trend_summary(
    app: &maohuoban_rust::test_support::AuthTestApp,
    user_id: &str,
    pet_id: &str,
) -> serde_json::Value {
    let response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/pets/{pet_id}/diet-trend-summary"),
            Some(user_id),
        ))
        .await
        .expect("load diet trend summary");
    assert_eq!(response.status(), StatusCode::OK);
    response_json(response).await
}

fn assert_segment(
    segments: &[serde_json::Value],
    category: &str,
    expected_score: f64,
    expected_percentage: i64,
) {
    let segment = segments
        .iter()
        .find(|segment| segment["category"] == category)
        .unwrap_or_else(|| panic!("missing segment {category}"));
    assert!((segment["score"].as_f64().expect("score") - expected_score).abs() < f64::EPSILON);
    assert_eq!(
        segment["percentage"].as_i64().expect("percentage"),
        expected_percentage
    );
}

async fn create_diet_trend_sample_data(
    app: &maohuoban_rust::test_support::AuthTestApp,
    user_id: &str,
) -> String {
    let pet_id = create_pet(app, user_id).await;
    let main_food_id = create_food_inventory_item(app, user_id, "主粮", "main_food").await;
    let wet_food_id = create_food_inventory_item(app, user_id, "罐头", "wet_food").await;
    let treats_id = create_food_inventory_item(app, user_id, "零食", "treats").await;
    let nutrition_id = create_food_inventory_item(app, user_id, "营养品", "nutrition").await;
    let cat_litter_id = create_food_inventory_item(app, user_id, "猫砂", "cat_litter").await;
    let medicine_id = create_food_inventory_item(app, user_id, "药品", "medicine").await;

    for (food_item_id, food_role, amount_text, occurred_at) in [
        (&main_food_id, "main_food", "正常", "2026-07-01T08:00:00Z"),
        (&main_food_id, "main_food", "正常", "2026-07-01T20:00:00Z"),
        (&wet_food_id, "wet_food", "正常", "2026-07-02T12:00:00Z"),
        (&treats_id, "treats", "少量", "2026-07-03T16:00:00Z"),
        (&nutrition_id, "nutrition", "少量", "2026-07-04T09:00:00Z"),
        (&cat_litter_id, "cat_litter", "正常", "2026-07-04T10:00:00Z"),
        (&medicine_id, "medicine", "正常", "2026-07-04T11:00:00Z"),
    ] {
        create_feeding_event(
            app,
            user_id,
            &pet_id,
            food_item_id,
            food_role,
            amount_text,
            occurred_at,
        )
        .await;
    }
    pet_id
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
                "brand": "测试品牌",
                "category": category,
                "inventory_status": "in_use",
                "quantity": 1,
                "unit": "件",
                "spec": "1kg"
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

async fn create_feeding_event(
    app: &maohuoban_rust::test_support::AuthTestApp,
    user_id: &str,
    pet_id: &str,
    food_item_id: &str,
    food_role: &str,
    amount_text: &str,
    occurred_at: &str,
) {
    let response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/events"),
            json!({
                "event_kind": "daily",
                "event_subkind": "feeding",
                "title": "已喂",
                "summary": format!("喂食：{food_role}，份量：{amount_text}"),
                "visibility": "private",
                "occurred_at": occurred_at,
                "event_payload": {
                    "food_item_id": food_item_id,
                    "food_role": food_role,
                    "amount_text": amount_text,
                    "food_snapshot": {
                        "name": food_role,
                        "brand": "测试品牌",
                        "category": food_role,
                        "spec": "1kg"
                    },
                    "is_default_food": false,
                    "note": null,
                    "attachment_asset_ids": []
                }
            }),
            Some(user_id),
        ))
        .await
        .expect("create feeding event");
    assert_eq!(response.status(), StatusCode::CREATED);
}

async fn create_abnormal_event(
    app: &maohuoban_rust::test_support::AuthTestApp,
    user_id: &str,
    pet_id: &str,
    occurred_at: &str,
) {
    let response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/events"),
            json!({
                "event_kind": "health",
                "event_subkind": "abnormal_symptom",
                "title": "异常记录",
                "summary": "软便",
                "visibility": "private",
                "occurred_at": occurred_at,
                "event_payload": {
                    "symptom_kinds": ["stool"],
                    "symptom_details": "软便",
                    "severity": "mild",
                    "note": null,
                    "attachment_asset_ids": []
                }
            }),
            Some(user_id),
        ))
        .await
        .expect("create abnormal event");
    assert_eq!(response.status(), StatusCode::CREATED);
}
