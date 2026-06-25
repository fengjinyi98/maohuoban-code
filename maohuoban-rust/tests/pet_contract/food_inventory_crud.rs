use super::*;

#[tokio::test]
#[allow(clippy::too_many_lines)]
async fn food_inventory_crud_persists_user_scoped_assets() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800139001").await;

    let create_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/food-inventory/items",
            json!({
                "name": "渴望六种鱼",
                "brand": "Orijen",
                "category": "main_food",
                "inventory_status": "sealed",
                "quantity": 1,
                "unit": "袋",
                "spec": "5.4kg",
                "expiry_date": "2027-01-15"
            }),
            Some(&user_id),
        ))
        .await
        .expect("create food inventory item");
    assert_eq!(create_response.status(), StatusCode::CREATED);
    let create_body = response_json(create_response).await;
    assert_eq!(create_body["success"], true);
    assert_eq!(create_body["code"], "food_inventory.item_created");
    assert_eq!(create_body["data"]["name"], "渴望六种鱼");
    assert_eq!(create_body["data"]["brand"], "Orijen");
    assert_eq!(create_body["data"]["category"], "main_food");
    assert_eq!(create_body["data"]["inventory_status"], "sealed");
    assert_eq!(create_body["data"]["scope_type"], "user");
    assert_eq!(create_body["data"]["scope_id"], user_id);
    let item_id = create_body["data"]["id"]
        .as_str()
        .expect("item id")
        .to_owned();

    let list_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            "/api/v1/food-inventory/items?category=main_food",
            Some(&user_id),
        ))
        .await
        .expect("list food inventory items");
    assert_eq!(list_response.status(), StatusCode::OK);
    let list_body = response_json(list_response).await;
    assert_eq!(list_body["code"], "food_inventory.list_loaded");
    assert_eq!(
        list_body["data"]["items"].as_array().expect("items").len(),
        1
    );
    assert_eq!(list_body["data"]["items"][0]["id"], item_id);

    let update_response = app
        .router()
        .oneshot(json_request(
            "PATCH",
            &format!("/api/v1/food-inventory/items/{item_id}"),
            json!({
                "inventory_status": "in_use",
                "quantity": 1
            }),
            Some(&user_id),
        ))
        .await
        .expect("update food inventory item");
    assert_eq!(update_response.status(), StatusCode::OK);
    let update_body = response_json(update_response).await;
    assert_eq!(update_body["code"], "food_inventory.item_updated");
    assert_eq!(update_body["data"]["inventory_status"], "in_use");

    let restock_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/food-inventory/items/{item_id}/restock"),
            json!({
                "quantity_delta": 1,
                "inventory_status": "sealed"
            }),
            Some(&user_id),
        ))
        .await
        .expect("restock food inventory item");
    assert_eq!(restock_response.status(), StatusCode::OK);
    let restock_body = response_json(restock_response).await;
    assert_eq!(restock_body["code"], "food_inventory.item_restocked");
    assert_eq!(restock_body["data"]["quantity"], 2);
    assert_eq!(restock_body["data"]["inventory_status"], "sealed");

    let archive_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/food-inventory/items/{item_id}/archive"),
            json!({}),
            Some(&user_id),
        ))
        .await
        .expect("archive food inventory item");
    assert_eq!(archive_response.status(), StatusCode::OK);
    let archive_body = response_json(archive_response).await;
    assert_eq!(archive_body["code"], "food_inventory.item_archived");
    assert_eq!(archive_body["data"]["inventory_status"], "archived");
    assert!(archive_body["data"]["archived_at"].is_string());

    let archived_list_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            "/api/v1/food-inventory/items?status=archived",
            Some(&user_id),
        ))
        .await
        .expect("list archived food inventory items");
    assert_eq!(archived_list_response.status(), StatusCode::OK);
    let archived_list_body = response_json(archived_list_response).await;
    assert_eq!(
        archived_list_body["data"]["items"]
            .as_array()
            .expect("archived items")
            .len(),
        1
    );
    assert_eq!(archived_list_body["data"]["items"][0]["id"], item_id);

    let restore_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/food-inventory/items/{item_id}/restore"),
            json!({
                "inventory_status": "sealed"
            }),
            Some(&user_id),
        ))
        .await
        .expect("restore food inventory item");
    assert_eq!(restore_response.status(), StatusCode::OK);
    let restore_body = response_json(restore_response).await;
    assert_eq!(restore_body["code"], "food_inventory.item_restored");
    assert_eq!(restore_body["data"]["inventory_status"], "sealed");
    assert!(restore_body["data"]["archived_at"].is_null());
}

#[tokio::test]
async fn food_inventory_item_rejects_cross_user_mutation() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let owner_user_id = login_user_id(&app, "13800139002").await;
    let other_user_id = login_user_id(&app, "13800139003").await;

    let create_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/food-inventory/items",
            json!({
                "name": "爱肯拿鸡肉",
                "brand": "Acana",
                "category": "main_food",
                "inventory_status": "sealed",
                "quantity": 1
            }),
            Some(&owner_user_id),
        ))
        .await
        .expect("create food inventory item");
    assert_eq!(create_response.status(), StatusCode::CREATED);
    let create_body = response_json(create_response).await;
    let item_id = create_body["data"]["id"].as_str().expect("item id");

    let update_response = app
        .router()
        .oneshot(json_request(
            "PATCH",
            &format!("/api/v1/food-inventory/items/{item_id}"),
            json!({
                "name": "被其他用户改名"
            }),
            Some(&other_user_id),
        ))
        .await
        .expect("cross user update food inventory item");
    assert_eq!(update_response.status(), StatusCode::NOT_FOUND);

    let owner_get_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/food-inventory/items/{item_id}"),
            Some(&owner_user_id),
        ))
        .await
        .expect("owner get food inventory item");
    assert_eq!(owner_get_response.status(), StatusCode::OK);
    let owner_get_body = response_json(owner_get_response).await;
    assert_eq!(owner_get_body["data"]["name"], "爱肯拿鸡肉");
}

#[tokio::test]
async fn food_inventory_archived_status_only_comes_from_archive_endpoint() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800139033").await;

    let create_archived_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/food-inventory/items",
            json!({
                "name": "错误归档状态",
                "category": "main_food",
                "inventory_status": "archived",
                "quantity": 1
            }),
            Some(&user_id),
        ))
        .await
        .expect("create archived food inventory item");
    assert_eq!(create_archived_response.status(), StatusCode::BAD_REQUEST);

    let create_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/food-inventory/items",
            json!({
                "name": "渴望六种鱼",
                "brand": "Orijen",
                "category": "main_food",
                "inventory_status": "sealed",
                "quantity": 1
            }),
            Some(&user_id),
        ))
        .await
        .expect("create food inventory item");
    assert_eq!(create_response.status(), StatusCode::CREATED);
    let create_body = response_json(create_response).await;
    let item_id = create_body["data"]["id"].as_str().expect("item id");

    let update_archived_response = app
        .router()
        .oneshot(json_request(
            "PATCH",
            &format!("/api/v1/food-inventory/items/{item_id}"),
            json!({
                "inventory_status": "archived"
            }),
            Some(&user_id),
        ))
        .await
        .expect("update food inventory item to archived");
    assert_eq!(update_archived_response.status(), StatusCode::BAD_REQUEST);

    let archive_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/food-inventory/items/{item_id}/archive"),
            json!({}),
            Some(&user_id),
        ))
        .await
        .expect("archive food inventory item");
    assert_eq!(archive_response.status(), StatusCode::OK);

    let restore_archived_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/food-inventory/items/{item_id}/restore"),
            json!({
                "inventory_status": "archived"
            }),
            Some(&user_id),
        ))
        .await
        .expect("restore food inventory item to archived");
    assert_eq!(restore_archived_response.status(), StatusCode::BAD_REQUEST);
}

#[tokio::test]
async fn food_inventory_restock_with_invalid_status_does_not_change_quantity() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800139034").await;

    let create_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/food-inventory/items",
            json!({
                "name": "渴望六种鱼",
                "category": "main_food",
                "inventory_status": "sealed",
                "quantity": 1
            }),
            Some(&user_id),
        ))
        .await
        .expect("create food inventory item");
    assert_eq!(create_response.status(), StatusCode::CREATED);
    let create_body = response_json(create_response).await;
    let item_id = create_body["data"]["id"].as_str().expect("item id");

    let restock_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/food-inventory/items/{item_id}/restock"),
            json!({
                "quantity_delta": 1,
                "inventory_status": "archived"
            }),
            Some(&user_id),
        ))
        .await
        .expect("restock food inventory item with invalid status");
    assert_eq!(restock_response.status(), StatusCode::BAD_REQUEST);

    let get_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/food-inventory/items/{item_id}"),
            Some(&user_id),
        ))
        .await
        .expect("get food inventory item after failed restock");
    assert_eq!(get_response.status(), StatusCode::OK);
    let get_body = response_json(get_response).await;
    assert_eq!(get_body["data"]["quantity"], 1);
    assert_eq!(get_body["data"]["inventory_status"], "sealed");
}

#[tokio::test]
async fn food_inventory_change_hints_track_mutation_kinds() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800139024").await;

    let create_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/food-inventory/items",
            json!({
                "name": "渴望六种鱼",
                "brand": "Orijen",
                "category": "main_food",
                "inventory_status": "sealed",
                "quantity": 1
            }),
            Some(&user_id),
        ))
        .await
        .expect("create food inventory item");
    assert_eq!(create_response.status(), StatusCode::CREATED);
    let create_body = response_json(create_response).await;
    let item_id = create_body["data"]["id"].as_str().expect("item id");

    let update_response = app
        .router()
        .oneshot(json_request(
            "PATCH",
            &format!("/api/v1/food-inventory/items/{item_id}"),
            json!({ "name": "渴望六种鱼新版" }),
            Some(&user_id),
        ))
        .await
        .expect("update food inventory item");
    assert_eq!(update_response.status(), StatusCode::OK);

    let archive_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/food-inventory/items/{item_id}/archive"),
            json!({}),
            Some(&user_id),
        ))
        .await
        .expect("archive food inventory item");
    assert_eq!(archive_response.status(), StatusCode::OK);

    let restore_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/food-inventory/items/{item_id}/restore"),
            json!({ "inventory_status": "sealed" }),
            Some(&user_id),
        ))
        .await
        .expect("restore food inventory item");
    assert_eq!(restore_response.status(), StatusCode::OK);

    let restock_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/food-inventory/items/{item_id}/restock"),
            json!({ "quantity_delta": 1 }),
            Some(&user_id),
        ))
        .await
        .expect("restock food inventory item");
    assert_eq!(restock_response.status(), StatusCode::OK);

    let hints_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            "/api/v1/food-inventory/change-hints",
            Some(&user_id),
        ))
        .await
        .expect("load food inventory change hints");
    assert_eq!(hints_response.status(), StatusCode::OK);
    let hints_body = response_json(hints_response).await;
    let change_kinds: Vec<&str> = hints_body["data"]["hints"]
        .as_array()
        .expect("hints")
        .iter()
        .filter_map(|hint| hint["change_kind"].as_str())
        .collect();

    for expected_kind in ["created", "updated", "archived", "restored", "restocked"] {
        assert!(
            change_kinds.contains(&expected_kind),
            "missing change kind {expected_kind}; got {change_kinds:?}"
        );
    }
    assert!(
        hints_body["data"]["hints"]
            .as_array()
            .expect("hints")
            .iter()
            .all(|hint| hint["fact_strength"] == "weak")
    );
}
