use super::*;

#[tokio::test]
async fn home_dashboard_returns_create_pet_empty_state() {
    let app = maohuoban_rust::test_support::spawn_home_test_app().await;
    app.seed_new_user_home().await;
    let user_id = login_user_id(&app, "13800138210").await;

    let response = app
        .router()
        .oneshot(contextual_empty_request(
            "GET",
            "/api/v1/home/dashboard",
            Some(&user_id),
        ))
        .await
        .expect("load empty home dashboard");
    assert_eq!(response.status(), StatusCode::OK);

    let body = response_json(response).await;
    assert_eq!(body["success"], true);
    assert_eq!(body["data"]["identity"]["kind"], "new_user");
    assert!(body["data"]["selected_pet"].is_null());
    assert_eq!(body["data"]["empty_state"]["kind"], "create_first_pet");
    assert_eq!(
        body["data"]["empty_state"]["primary_action"]["kind"],
        "create_pet"
    );
    assert!(body["data"]["recommended_content"].as_array().is_some());
}

#[tokio::test]
async fn home_dashboard_returns_merchant_workspace_snapshot() {
    let app = maohuoban_rust::test_support::spawn_home_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138211").await;
    let merchant_id = app.seed_merchant_tracking_workspace(&user_id).await;

    let response = app
        .router()
        .oneshot(contextual_empty_request(
            "GET",
            "/api/v1/home/dashboard",
            Some(&user_id),
        ))
        .await
        .expect("load merchant home dashboard");
    assert_eq!(response.status(), StatusCode::OK);

    let body = response_json(response).await;
    assert_eq!(body["success"], true);
    assert_eq!(body["data"]["identity"]["kind"], "certified_merchant");
    assert!(body["data"]["selected_pet"].is_null());
    assert_eq!(
        body["data"]["merchant_dashboard"]["merchant_id"],
        merchant_id
    );
    assert_eq!(
        body["data"]["merchant_dashboard"]["status_counts"][0]["status"],
        "available"
    );
    assert_eq!(
        body["data"]["merchant_dashboard"]["litters"][0]["name"],
        "2026 春季 A 窝"
    );
    assert_eq!(
        body["data"]["merchant_dashboard"]["pending_tasks"][0]["kind"],
        "complete_health_record"
    );
    assert!(body["data"]["empty_state"].is_null());
}
