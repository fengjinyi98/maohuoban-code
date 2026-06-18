use super::*;

#[tokio::test]
async fn merchant_pet_list_returns_status_filtered_managed_pets() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138111").await;
    let merchant_id = app.seed_merchant_tracking_workspace(&user_id).await;

    let response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/merchants/{merchant_id}/pets?status=available"),
            Some(&user_id),
        ))
        .await
        .expect("load merchant pets");

    assert_eq!(response.status(), StatusCode::OK);
    let body = response_json(response).await;
    assert_eq!(body["success"], true);
    assert_eq!(body["code"], "merchant.pets_loaded");
    assert_eq!(body["message"], "商家宠物列表已加载");
    assert_eq!(body["data"]["merchant_id"], merchant_id);
    assert_eq!(body["data"]["status"], "available");
    assert_eq!(body["data"]["pets"][0]["name"], "小橘");
    assert_eq!(body["data"]["pets"][0]["managed_status"], "available");
    assert_eq!(body["data"]["pets"][1]["name"], "小灰");
    assert_eq!(body["data"]["pets"].as_array().expect("pets").len(), 2);
}

#[tokio::test]
async fn merchant_pet_create_persists_managed_pet_for_verified_merchant() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138112").await;
    let merchant_id = app.seed_merchant_tracking_workspace(&user_id).await;

    let create_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/merchants/{merchant_id}/pets"),
            json!({
                "name": "奶糖",
                "species": "cat",
                "breed": "布偶猫",
                "sex": "female",
                "birthday": "2026-04-01",
                "managed_status": "needs_record"
            }),
            Some(&user_id),
        ))
        .await
        .expect("create merchant pet");

    assert_eq!(create_response.status(), StatusCode::CREATED);
    let create_body = response_json(create_response).await;
    assert_eq!(create_body["success"], true);
    assert_eq!(create_body["code"], "merchant.pet_created");
    assert_eq!(create_body["message"], "商家宠物已新增");
    assert_eq!(create_body["data"]["name"], "奶糖");
    assert_eq!(create_body["data"]["merchant_id"], merchant_id);
    assert_eq!(create_body["data"]["owner_user_id"], Value::Null);
    assert_eq!(create_body["data"]["managed_status"], "needs_record");
    assert_eq!(create_body["data"]["source_kind"], "merchant_managed");
    let pet_id = create_body["data"]["id"].as_str().expect("pet id");
    uuid::Uuid::parse_str(pet_id).expect("merchant pet id should be uuid");

    let list_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/merchants/{merchant_id}/pets?status=needs_record"),
            Some(&user_id),
        ))
        .await
        .expect("load needs record merchant pets");
    assert_eq!(list_response.status(), StatusCode::OK);
    let list_body = response_json(list_response).await;
    let pets = list_body["data"]["pets"].as_array().expect("pets");
    assert!(pets.iter().any(|pet| pet["id"] == pet_id));
}

#[tokio::test]
async fn merchant_publish_available_status_updates_pet_and_records_event() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138115").await;
    let merchant_id = app.seed_merchant_tracking_workspace(&user_id).await;
    let pet_id = "69f4570a-aea8-4197-a98c-33ed56c6ff78";

    let publish_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/merchants/{merchant_id}/pets/{pet_id}/available-status"),
            json!({
                "summary": "已完成基础健康记录，可预约到店看猫。",
                "occurred_at": "2026-06-14T10:00:00Z"
            }),
            Some(&user_id),
        ))
        .await
        .expect("publish available status");

    assert_eq!(publish_response.status(), StatusCode::OK);
    let publish_body = response_json(publish_response).await;
    assert_eq!(publish_body["success"], true);
    assert_eq!(publish_body["code"], "merchant.available_status_published");
    assert_eq!(publish_body["message"], "可售状态已发布");
    assert_eq!(publish_body["data"]["pet"]["id"], pet_id);
    assert_eq!(publish_body["data"]["pet"]["managed_status"], "available");
    assert_eq!(publish_body["data"]["event"]["pet_id"], pet_id);
    assert_eq!(publish_body["data"]["event"]["event_kind"], "merchant");
    assert_eq!(
        publish_body["data"]["event"]["event_subkind"],
        "available_status"
    );
    assert_eq!(publish_body["data"]["event"]["visibility"], "buyer_visible");
    assert_eq!(
        publish_body["data"]["event"]["summary"],
        "已完成基础健康记录，可预约到店看猫。"
    );

    let available_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/merchants/{merchant_id}/pets?status=available"),
            Some(&user_id),
        ))
        .await
        .expect("load available merchant pets");
    assert_eq!(available_response.status(), StatusCode::OK);
    let available_body = response_json(available_response).await;
    let pets = available_body["data"]["pets"].as_array().expect("pets");
    assert!(pets.iter().any(|pet| pet["id"] == pet_id));
}

#[tokio::test]
async fn merchant_litter_detail_returns_traceable_family_context() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138113").await;
    let merchant_id = app.seed_merchant_tracking_workspace(&user_id).await;

    let dashboard_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            "/api/v1/home/dashboard",
            Some(&user_id),
        ))
        .await
        .expect("load home dashboard");
    assert_eq!(dashboard_response.status(), StatusCode::OK);
    let dashboard_body = response_json(dashboard_response).await;
    let litter_id = dashboard_body["data"]["merchant_dashboard"]["litters"][0]["id"]
        .as_str()
        .expect("litter id");

    let detail_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/merchants/{merchant_id}/litters/{litter_id}"),
            Some(&user_id),
        ))
        .await
        .expect("load merchant litter detail");

    assert_eq!(detail_response.status(), StatusCode::OK);
    let body = response_json(detail_response).await;
    assert_eq!(body["success"], true);
    assert_eq!(body["code"], "merchant.litter_loaded");
    assert_eq!(body["message"], "窝次详情已加载");
    assert_eq!(body["data"]["id"], litter_id);
    assert_eq!(body["data"]["merchant_id"], merchant_id);
    assert_eq!(body["data"]["name"], "2026 春季 A 窝");
    assert_eq!(body["data"]["born_count"], 3);
    assert_eq!(body["data"]["alive_count"], 3);
    assert_eq!(body["data"]["available_count"], 2);
    assert_eq!(body["data"]["sire_pet"]["name"], "Leo");
    assert_eq!(body["data"]["dam_pet"]["name"], "Luna");
    assert_eq!(
        body["data"]["children"].as_array().expect("children").len(),
        3
    );
    assert_eq!(body["data"]["recent_events"][0]["title"], "A 窝出生记录");
    assert!(
        body["data"]["relationships"]
            .as_array()
            .expect("relationships")
            .iter()
            .any(|relationship| relationship["relationship_kind"] == "same_litter")
    );
}

#[tokio::test]
async fn merchant_pet_list_requires_user_context() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;

    let response = app
        .router()
        .oneshot(empty_request(
            "GET",
            "/api/v1/merchants/3a85d5e7-1d03-41a1-9f8f-7c34a1e5a71f/pets?status=available",
            None,
        ))
        .await
        .expect("load merchant pets without user context");

    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
    let body = response_json(response).await;
    assert_eq!(body["success"], false);
    assert_eq!(body["code"], "auth.session_expired");
    assert_eq!(body["message"], "登录状态已过期，请重新登录");
}
