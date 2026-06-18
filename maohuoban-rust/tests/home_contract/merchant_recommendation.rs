use super::*;

#[tokio::test]
async fn home_dashboard_uses_current_user_merchant_tracking_workspace() {
    let app = maohuoban_rust::test_support::spawn_home_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138221").await;
    let merchant_id = app.seed_merchant_tracking_workspace(&user_id).await;

    let dashboard_response = app
        .router()
        .oneshot(contextual_empty_request(
            "GET",
            "/api/v1/home/dashboard",
            Some(&user_id),
        ))
        .await
        .expect("load merchant tracking dashboard");
    assert_eq!(dashboard_response.status(), StatusCode::OK);
    let dashboard_body = response_json(dashboard_response).await;
    assert_eq!(
        dashboard_body["data"]["identity"]["kind"],
        "certified_merchant"
    );
    assert!(dashboard_body["data"]["selected_pet"].is_null());
    assert_eq!(
        dashboard_body["data"]["merchant_dashboard"]["merchant_id"],
        merchant_id
    );
    assert_eq!(
        dashboard_body["data"]["merchant_dashboard"]["merchant_name"],
        "梧桐猫舍"
    );
    assert_eq!(
        dashboard_body["data"]["merchant_dashboard"]["status_counts"][0]["status"],
        "available"
    );
    assert_eq!(
        dashboard_body["data"]["merchant_dashboard"]["status_counts"][0]["count"],
        2
    );
    assert_eq!(
        dashboard_body["data"]["merchant_dashboard"]["litters"][0]["name"],
        "2026 春季 A 窝"
    );
    assert_eq!(
        dashboard_body["data"]["merchant_dashboard"]["litters"][0]["parent_text"],
        "父亲 Leo · 母亲 Luna"
    );
    assert_eq!(
        dashboard_body["data"]["merchant_dashboard"]["litters"][0]["available_count"],
        2
    );
    assert_eq!(
        dashboard_body["data"]["merchant_dashboard"]["pending_tasks"][0]["kind"],
        "complete_health_record"
    );
    assert_eq!(
        dashboard_body["data"]["merchant_dashboard"]["recent_events"][0]["title"],
        "A 窝出生记录"
    );
    assert!(dashboard_body["data"]["empty_state"].is_null());
}

#[tokio::test]
async fn home_dashboard_recommends_same_litter_partner_from_pet_relationships() {
    let app = maohuoban_rust::test_support::spawn_home_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138223").await;
    let partner_user_id = login_user_id(&app, "13800138224").await;
    let pet_id = create_named_home_test_pet(&app, &user_id, "糯米").await;
    let partner_pet_id = create_named_home_test_pet(&app, &partner_user_id, "奶盖").await;

    app.seed_same_litter_relationship(&pet_id, &partner_pet_id)
        .await;

    let dashboard_body = load_user_home_dashboard(&app, &user_id).await;

    assert_eq!(
        dashboard_body["data"]["partner_recommendation"]["pet_id"],
        partner_pet_id
    );
    assert_eq!(
        dashboard_body["data"]["partner_recommendation"]["pet_name"],
        "奶盖"
    );
    assert_eq!(
        dashboard_body["data"]["partner_recommendation"]["relationship_kind"],
        "same_litter"
    );
    assert_eq!(
        dashboard_body["data"]["partner_recommendation"]["distance_text"],
        "同窝关系"
    );
    assert!(dashboard_body["data"]["empty_state"].is_null());
}
