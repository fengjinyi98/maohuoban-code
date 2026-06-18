use super::*;

#[tokio::test]
async fn trade_pet_import_creates_pet_and_trade_event() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138118").await;

    let response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets/imports/trade",
            json!({
                "name": "奶盖",
                "species": "cat",
                "breed": "布偶",
                "sex": "female",
                "birthday": "2024-03-20",
                "seller_name": "安心猫舍",
                "trade_reference": "offline-contract-001",
                "summary": "线下交易完成，已完成基础体检",
                "occurred_at": "2026-06-13T10:00:00Z"
            }),
            Some(&user_id),
        ))
        .await
        .expect("import trade pet");

    assert_eq!(response.status(), StatusCode::CREATED);
    let body = response_json(response).await;
    assert_eq!(body["success"], true);
    assert_eq!(body["code"], "pet.trade_imported");
    assert_eq!(body["message"], "交易宠物已导入");
    assert_eq!(body["data"]["pet"]["name"], "奶盖");
    assert_eq!(body["data"]["pet"]["owner_user_id"], user_id);
    assert_eq!(body["data"]["pet"]["source_kind"], "trade_imported");
    assert_eq!(body["data"]["pet"]["managed_status"], "family");
    let pet_id = body["data"]["pet"]["id"].as_str().expect("pet id");
    uuid::Uuid::parse_str(pet_id).expect("pet id should be uuid");

    assert_eq!(body["data"]["event"]["pet_id"], pet_id);
    assert_eq!(body["data"]["event"]["event_kind"], "trade");
    assert_eq!(body["data"]["event"]["event_subkind"], "trade_imported");
    assert_eq!(body["data"]["event"]["title"], "交易宠物导入");
    assert_eq!(
        body["data"]["event"]["summary"],
        "线下交易完成，已完成基础体检"
    );
    assert_eq!(body["data"]["event"]["visibility"], "private");
    assert_eq!(
        body["data"]["event"]["event_payload"]["seller_name"],
        "安心猫舍"
    );
    assert_eq!(
        body["data"]["event"]["event_payload"]["trade_reference"],
        "offline-contract-001"
    );
}

#[tokio::test]
async fn pet_endpoints_require_user_context() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;

    let response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "糯米",
                "species": "dog"
            }),
            None,
        ))
        .await
        .expect("create pet without user context");
    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
    let body = response_json(response).await;
    assert_eq!(body["success"], false);
    assert_eq!(body["code"], "auth.session_expired");
    assert_eq!(body["message"], "登录状态已过期，请重新登录");
}

#[tokio::test]
async fn pet_endpoints_reject_legacy_user_header_without_access_token() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;

    let response = app
        .router()
        .oneshot(
            Request::builder()
                .method("POST")
                .uri("/api/v1/pets")
                .header("content-type", "application/json")
                .header("x-maohuoban-user-id", uuid::Uuid::new_v4().to_string())
                .body(Body::from(
                    json!({
                        "name": "糯米",
                        "species": "dog"
                    })
                    .to_string(),
                ))
                .expect("build legacy user header request"),
        )
        .await
        .expect("create pet with legacy user header");
    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
    let body = response_json(response).await;
    assert_eq!(body["success"], false);
    assert_eq!(body["code"], "auth.session_expired");
    assert_eq!(body["message"], "登录状态已过期，请重新登录");
}
