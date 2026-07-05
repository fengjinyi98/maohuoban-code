use super::*;

#[tokio::test]
async fn home_dashboard_requires_authenticated_user() {
    let app = maohuoban_rust::test_support::spawn_home_test_app().await;
    app.reset().await;

    let response = app
        .router()
        .oneshot(empty_request("GET", "/api/v1/home/dashboard"))
        .await
        .expect("load home dashboard without token");

    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
    let body = response_json(response).await;
    assert_eq!(body["success"], false);
    assert_eq!(body["code"], "auth.session_expired");
    assert_eq!(body["message"], "登录状态已过期，请重新登录");
}

#[tokio::test]
async fn home_dashboard_uses_current_user_pet_records_when_user_context_exists() {
    let app = maohuoban_rust::test_support::spawn_home_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138220").await;

    let empty_response = app
        .router()
        .oneshot(contextual_empty_request(
            "GET",
            "/api/v1/home/dashboard",
            Some(&user_id),
        ))
        .await
        .expect("load empty home dashboard");
    assert_eq!(empty_response.status(), StatusCode::OK);
    let empty_body = response_json(empty_response).await;
    assert_eq!(empty_body["data"]["identity"]["kind"], "new_user");
    assert_eq!(
        empty_body["data"]["empty_state"]["kind"],
        "create_first_pet"
    );

    let pet_id = create_home_test_pet(&app, &user_id).await;
    append_home_test_event(
        &app,
        &user_id,
        &pet_id,
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
    )
    .await;

    let dashboard_body = load_user_home_dashboard(&app, &user_id).await;
    assert_eq!(dashboard_body["data"]["identity"]["kind"], "pet_owner");
    assert_eq!(dashboard_body["data"]["selected_pet"]["name"], "糯米");
    assert_eq!(dashboard_body["data"]["selected_pet"]["id"], pet_id);
    assert_eq!(
        dashboard_body["data"]["quick_actions"]
            .as_array()
            .expect("quick actions array")
            .len(),
        0
    );
    assert_eq!(
        dashboard_body["data"]["recent_timeline"][0]["title"],
        "体重记录"
    );
    assert_eq!(
        dashboard_body["data"]["recent_timeline"][0]["occurred_at"],
        "2026-06-13T09:20:00Z"
    );
    assert!(dashboard_body["data"]["empty_state"].is_null());
}

#[tokio::test]
async fn home_dashboard_derives_companionship_days_from_arrival_date() {
    let app = maohuoban_rust::test_support::spawn_home_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138228").await;
    let birthday = chrono::Utc::now().date_naive() - chrono::Duration::days(30);
    let arrival_date = chrono::Utc::now().date_naive() - chrono::Duration::days(5);

    let create_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "奶油",
                "species": "cat",
                "breed": "布偶",
                "sex": "female",
                "birthday": birthday.to_string(),
                "arrival_date": arrival_date.to_string()
            }),
            Some(&user_id),
        ))
        .await
        .expect("create pet with arrival date");
    assert_eq!(create_response.status(), StatusCode::CREATED);

    let dashboard_body = load_user_home_dashboard(&app, &user_id).await;
    assert_eq!(
        dashboard_body["data"]["selected_pet"]["arrival_date"],
        arrival_date.to_string()
    );
    assert_eq!(
        dashboard_body["data"]["selected_pet"]["companionship_days"],
        5
    );
    assert_eq!(dashboard_body["data"]["selected_pet"]["world_days"], 30);
}

#[tokio::test]
async fn home_dashboard_projects_profile_dates_into_empty_timeline() {
    let app = maohuoban_rust::test_support::spawn_home_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138235").await;
    let birthday = "2024-04-01";
    let arrival_date = "2024-06-16";

    let create_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "糯米",
                "species": "cat",
                "breed": "布偶",
                "sex": "female",
                "birthday": birthday,
                "arrival_date": arrival_date
            }),
            Some(&user_id),
        ))
        .await
        .expect("create pet with profile dates");
    assert_eq!(create_response.status(), StatusCode::CREATED);
    let create_body = response_json(create_response).await;
    let pet_id = create_body["data"]["id"].as_str().expect("pet id");

    let dashboard_body = load_user_home_dashboard(&app, &user_id).await;
    assert!(dashboard_body["data"].get("storylines").is_none());
    let timeline = dashboard_body["data"]["recent_timeline"]
        .as_array()
        .expect("recent timeline array");

    assert_eq!(timeline.len(), 2);
    let homecoming = &timeline[0];
    assert_eq!(homecoming["id"], format!("{pet_id}-homecoming"));
    assert_eq!(homecoming["event_kind"], "daily");
    assert_eq!(homecoming["title"], "到家的第一天");
    assert_eq!(homecoming["subtitle"], "糯米来到你身边");
    assert_eq!(homecoming["occurred_text"], arrival_date);
    assert_eq!(homecoming["occurred_at"], "2024-06-16T00:00:00Z");

    let birth = &timeline[1];
    assert_eq!(birth["id"], format!("{pet_id}-birth"));
    assert_eq!(birth["event_kind"], "daily");
    assert_eq!(birth["title"], "第一次来到这个世界");
    assert_eq!(birth["subtitle"], "糯米在这一天出生");
    assert_eq!(birth["occurred_text"], birthday);
    assert_eq!(birth["occurred_at"], "2024-04-01T00:00:00Z");
}

#[tokio::test]
async fn home_dashboard_projects_latest_weight_records_into_pet_stats() {
    let app = maohuoban_rust::test_support::spawn_home_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138236").await;

    let create_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "糯米",
                "species": "cat",
                "sex": "female",
                "weight_grams": 4200
            }),
            Some(&user_id),
        ))
        .await
        .expect("create pet with initial weight");
    assert_eq!(create_response.status(), StatusCode::CREATED);
    let create_body = response_json(create_response).await;
    let pet_id = create_body["data"]["id"].as_str().expect("pet id");

    let latest_weight_recorded_at = chrono::Utc::now() + chrono::Duration::hours(1);
    append_home_test_weight_record(
        &app,
        &user_id,
        pet_id,
        4350,
        &latest_weight_recorded_at.to_rfc3339(),
    )
    .await;

    let dashboard_body = load_user_home_dashboard_for_pet(&app, &user_id, pet_id).await;
    let selected_pet = &dashboard_body["data"]["selected_pet"];

    assert_eq!(selected_pet["weight_grams"], 4350);
    assert_eq!(selected_pet["stats"]["weight_val"], "4.35");
    assert_eq!(selected_pet["stats"]["weight_change"], "+ 0.15 kg");
    assert_eq!(
        selected_pet["stats"]["record_streak_text"],
        format!("最近记录 {}", latest_weight_recorded_at.format("%Y-%m-%d"))
    );
    assert_eq!(selected_pet["stats"]["record_days"], 2);
    assert_eq!(selected_pet["stats"]["deworming_date"], "待记录");
    assert!(selected_pet["stats"]["deworming_days_left"].is_null());
    assert!(selected_pet["stats"]["preventive_care"].is_null());
}

#[tokio::test]
async fn home_dashboard_clears_weight_projection_when_all_weight_records_are_deleted() {
    let app = maohuoban_rust::test_support::spawn_home_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138237").await;

    let create_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "糯米",
                "species": "cat",
                "sex": "female",
                "weight_grams": 4200
            }),
            Some(&user_id),
        ))
        .await
        .expect("create pet with initial weight");
    assert_eq!(create_response.status(), StatusCode::CREATED);
    let create_body = response_json(create_response).await;
    let pet_id = create_body["data"]["id"].as_str().expect("pet id");
    let record_ids = load_home_test_weight_record_ids(&app, &user_id, pet_id).await;
    assert_eq!(record_ids.len(), 1);

    delete_home_test_weight_record(&app, &user_id, &record_ids[0]).await;

    let dashboard_body = load_user_home_dashboard_for_pet(&app, &user_id, pet_id).await;
    let selected_pet = &dashboard_body["data"]["selected_pet"];
    assert!(selected_pet["weight_grams"].is_null());
    assert_eq!(selected_pet["stats"]["weight_val"], "");
    assert_eq!(selected_pet["stats"]["record_streak_text"], "尚未记录");
    assert_eq!(selected_pet["stats"]["pantry_item_count"], 0);
}

#[tokio::test]
async fn home_dashboard_uses_selected_pet_id_for_multi_pet_switching() {
    let app = maohuoban_rust::test_support::spawn_home_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138227").await;
    let first_pet_id = create_named_home_test_pet(&app, &user_id, "糯米").await;
    let second_pet_id = create_named_home_test_pet(&app, &user_id, "奶油").await;
    append_home_test_event(
        &app,
        &user_id,
        &second_pet_id,
        json!({
            "event_kind": "daily",
            "event_subkind": "appetite",
            "title": "奶油早餐记录",
            "summary": "第二只宠物的首页时间线",
            "visibility": "private",
            "occurred_at": "2026-06-13T08:30:00Z",
            "event_payload": {
                "value_text": "正常"
            }
        }),
    )
    .await;

    let dashboard_body = load_user_home_dashboard_for_pet(&app, &user_id, &second_pet_id).await;

    assert_eq!(dashboard_body["data"]["selected_pet"]["id"], second_pet_id);
    assert_eq!(dashboard_body["data"]["selected_pet"]["name"], "奶油");
    assert_eq!(
        dashboard_body["data"]["pet_switcher"][0]["id"],
        first_pet_id
    );
    assert_eq!(
        dashboard_body["data"]["pet_switcher"][0]["is_selected"],
        false
    );
    assert_eq!(
        dashboard_body["data"]["pet_switcher"][1]["id"],
        second_pet_id
    );
    assert_eq!(
        dashboard_body["data"]["pet_switcher"][1]["is_selected"],
        true
    );
    assert_eq!(
        dashboard_body["data"]["recent_timeline"][0]["title"],
        "奶油早餐记录"
    );
}

#[tokio::test]
async fn home_dashboard_returns_recent_food_inventory_preview() {
    let app = maohuoban_rust::test_support::spawn_home_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138233").await;
    create_home_test_pet(&app, &user_id).await;

    let old_main_food_item_id =
        create_home_food_inventory_item(&app, &user_id, "渴望六种鱼", "main_food").await;
    let wet_food_item_id =
        create_home_food_inventory_item(&app, &user_id, "巅峰牛肉罐头", "wet_food").await;
    let cover_asset_id = upload_home_food_inventory_cover(&app, &user_id).await;
    let latest_main_food_item_id = create_home_food_inventory_item_with_cover(
        &app,
        &user_id,
        "舒然 SUPER 美毛配方",
        "main_food",
        &cover_asset_id,
    )
    .await;

    let dashboard_body = load_user_home_dashboard(&app, &user_id).await;
    let pet_stats = &dashboard_body["data"]["selected_pet"]["stats"];
    assert_eq!(pet_stats["pantry_item_count"], 3);
    assert_eq!(
        pet_stats["pantry_last_added_date"],
        chrono::Utc::now().format("%Y-%m-%d").to_string()
    );

    let pantry_items = dashboard_body["data"]["pantry_items"]
        .as_array()
        .expect("pantry preview items");

    assert_eq!(pantry_items.len(), 2);
    assert!(
        pantry_items
            .iter()
            .all(|item| item["id"] != old_main_food_item_id)
    );

    let main_food_item = pantry_items
        .iter()
        .find(|item| item["id"] == latest_main_food_item_id)
        .expect("latest main food pantry item");
    assert_eq!(main_food_item["title"], "舒然 SUPER 美毛配方");
    assert_eq!(main_food_item["subtitle"], "主食干粮");
    assert_eq!(main_food_item["category"], "main_food");
    assert_eq!(
        main_food_item["cover_url"],
        format!("/api/v1/media/assets/{cover_asset_id}/content")
    );

    let wet_food_item = pantry_items
        .iter()
        .find(|item| item["id"] == wet_food_item_id)
        .expect("wet food pantry item");
    assert_eq!(wet_food_item["title"], "巅峰牛肉罐头");
    assert_eq!(wet_food_item["subtitle"], "湿粮/罐头");
    assert_eq!(wet_food_item["category"], "wet_food");
    assert!(wet_food_item.get("cover_image_asset_name").is_none());
    assert!(wet_food_item["cover_url"].is_null());
}

#[tokio::test]
async fn home_dashboard_marks_current_staple_in_food_inventory_preview() {
    let app = maohuoban_rust::test_support::spawn_home_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138234").await;
    let pet_id = create_home_test_pet(&app, &user_id).await;

    let staple_item_id =
        create_home_food_inventory_item(&app, &user_id, "渴望六种鱼", "main_food").await;
    let wet_food_item_id =
        create_home_food_inventory_item(&app, &user_id, "巅峰牛肉罐头", "wet_food").await;
    set_home_pet_current_staple(&app, &user_id, &pet_id, &staple_item_id).await;

    let dashboard_body = load_user_home_dashboard_for_pet(&app, &user_id, &pet_id).await;
    let pantry_items = dashboard_body["data"]["pantry_items"]
        .as_array()
        .expect("pantry preview items");
    let staple_item = pantry_items
        .iter()
        .find(|item| item["id"] == staple_item_id)
        .expect("current staple pantry item");
    let wet_food_item = pantry_items
        .iter()
        .find(|item| item["id"] == wet_food_item_id)
        .expect("plain pantry item");

    assert_eq!(staple_item["diet_role_label"], "当前主粮");
    assert!(wet_food_item["diet_role_label"].is_null());
}

#[tokio::test]
async fn home_dashboard_returns_pet_diet_trend_summary_from_backend_analysis() {
    let app = maohuoban_rust::test_support::spawn_home_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138239").await;
    let pet_id = create_home_test_pet(&app, &user_id).await;
    let main_food_id =
        create_home_food_inventory_item(&app, &user_id, "渴望六种鱼", "main_food").await;
    let wet_food_id =
        create_home_food_inventory_item(&app, &user_id, "巅峰牛肉罐头", "wet_food").await;
    let cat_litter_id =
        create_home_food_inventory_item(&app, &user_id, "膨润土猫砂", "cat_litter").await;

    append_home_test_feeding_event(
        &app,
        &user_id,
        &pet_id,
        &main_food_id,
        "main_food",
        "正常",
        "2026-07-01T08:00:00Z",
    )
    .await;
    append_home_test_feeding_event(
        &app,
        &user_id,
        &pet_id,
        &wet_food_id,
        "wet_food",
        "少量",
        "2026-07-02T12:00:00Z",
    )
    .await;
    append_home_test_feeding_event(
        &app,
        &user_id,
        &pet_id,
        &cat_litter_id,
        "cat_litter",
        "正常",
        "2026-07-03T12:00:00Z",
    )
    .await;

    let dashboard_body = load_user_home_dashboard_for_pet(&app, &user_id, &pet_id).await;
    let summary = &dashboard_body["data"]["diet_trend_summary"];

    assert_eq!(summary["window_days"], 30);
    assert_eq!(summary["explanation"]["title"], "饮食趋势是怎么生成的");
    let segments = summary["segments"].as_array().expect("diet trend segments");
    assert_eq!(segments.len(), 5);
    assert!(segments.iter().any(|segment| {
        segment["category"] == "main_food"
            && segment["percentage"]
                .as_i64()
                .expect("main food percentage")
                > 0
    }));
    let main_food = segments
        .iter()
        .find(|segment| segment["category"] == "main_food")
        .expect("main food segment");
    assert!(main_food["baseline_sample_days"].is_i64());
    assert!(summary["health_context"]["included_sample_count"].is_i64());
    assert_eq!(summary["calibration"]["confidence"], "low");
    assert!(summary["calibration"]["grams_per_score"].is_null());
    let other = segments
        .iter()
        .find(|segment| segment["category"] == "other")
        .expect("other segment");
    assert_eq!(other["percentage"], 0);
    assert!(other["baseline_score"].is_null());
    assert_eq!(other["baseline_sample_days"], 0);
    assert!(segments.iter().any(|segment| {
        segment["category"] == "wet_food"
            && segment["percentage"].as_i64().expect("wet food percentage") > 0
    }));
    assert!(
        segments
            .iter()
            .all(|segment| segment["category"] != "cat_litter")
    );
}

async fn create_home_food_inventory_item(
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
                "quantity": 1,
                "production_date": "2025-07-15",
                "shelf_life_months": 18
            }),
            Some(user_id),
        ))
        .await
        .expect("create home food inventory item");
    assert_eq!(response.status(), StatusCode::CREATED);
    let body = response_json(response).await;
    body["data"]["id"].as_str().expect("item id").to_owned()
}

async fn create_home_food_inventory_item_with_cover(
    app: &maohuoban_rust::test_support::AuthTestApp,
    user_id: &str,
    name: &str,
    category: &str,
    cover_asset_id: &str,
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
                "quantity": 1,
                "production_date": "2025-07-15",
                "shelf_life_months": 18,
                "cover_asset_id": cover_asset_id
            }),
            Some(user_id),
        ))
        .await
        .expect("create home food inventory item with cover");
    assert_eq!(response.status(), StatusCode::CREATED);
    let body = response_json(response).await;
    body["data"]["id"].as_str().expect("item id").to_owned()
}

async fn upload_home_food_inventory_cover(
    app: &maohuoban_rust::test_support::AuthTestApp,
    user_id: &str,
) -> String {
    let image_bytes = STANDARD
        .decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC")
        .expect("food inventory cover png bytes");
    let upload_body = upload_pending_media(
        app,
        "/api/v1/food-inventory/media",
        "food-cover.png",
        "image/png",
        &image_bytes,
        user_id,
    )
    .await;
    upload_body["data"]["asset"]["id"]
        .as_str()
        .expect("food inventory cover asset id")
        .to_owned()
}

async fn set_home_pet_current_staple(
    app: &maohuoban_rust::test_support::AuthTestApp,
    user_id: &str,
    pet_id: &str,
    food_item_id: &str,
) {
    let response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/diet/staple"),
            json!({
                "food_item_id": food_item_id,
                "reason": "首页预览标注测试"
            }),
            Some(user_id),
        ))
        .await
        .expect("set current staple for home pantry preview");
    assert_eq!(response.status(), StatusCode::CREATED);
}

async fn append_home_test_feeding_event(
    app: &maohuoban_rust::test_support::AuthTestApp,
    user_id: &str,
    pet_id: &str,
    food_item_id: &str,
    food_role: &str,
    amount_text: &str,
    occurred_at: &str,
) {
    append_home_test_event(
        app,
        user_id,
        pet_id,
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
    )
    .await;
}
