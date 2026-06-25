use super::*;

#[tokio::test]
async fn pet_identity_context_returns_disputed_external_identifier_for_guardian() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let owner_user_id = login_user_id(&app, "13800138241").await;
    let co_caretaker_user_id = login_user_id(&app, "13800138242").await;
    let other_owner_user_id = login_user_id(&app, "13800138243").await;

    let first_pet_id =
        create_pet_with_microchip(&app, &owner_user_id, "栗子", "156000000000041").await;
    let second_pet_id =
        create_pet_with_microchip(&app, &other_owner_user_id, "花卷", "156000000000041").await;
    app.seed_active_pet_co_caretaker(&first_pet_id, &co_caretaker_user_id)
        .await;

    assert_eq!(
        app.microchip_identifier_status_count(&first_pet_id, "156000000000041", "disputed")
            .await,
        1
    );
    assert_eq!(
        app.microchip_identifier_status_count(&second_pet_id, "156000000000041", "disputed")
            .await,
        1
    );

    let context_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/pets/{first_pet_id}/identity-context"),
            Some(&co_caretaker_user_id),
        ))
        .await
        .expect("load identity context as co caretaker");
    assert_eq!(context_response.status(), StatusCode::OK);
    let context_body = response_json(context_response).await;
    assert_eq!(context_body["code"], "pet.identity_context_loaded");
    assert_eq!(context_body["data"]["identity"]["pet_id"], first_pet_id);
    assert_eq!(
        context_body["data"]["external_identifiers"][0]["identifier_type"],
        "microchip"
    );
    assert_eq!(
        context_body["data"]["external_identifiers"][0]["identifier_value"],
        "156000000000041"
    );
    assert_eq!(
        context_body["data"]["external_identifiers"][0]["verified_status"],
        "self_reported"
    );
    assert_eq!(
        context_body["data"]["external_identifiers"][0]["status"],
        "disputed"
    );

    let unrelated_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/pets/{first_pet_id}/identity-context"),
            Some(&other_owner_user_id),
        ))
        .await
        .expect("load identity context as unrelated user");
    assert_eq!(unrelated_response.status(), StatusCode::FORBIDDEN);
}

#[tokio::test]
async fn pet_profile_create_marks_shared_microchip_as_disputed() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let first_user_id = login_user_id(&app, "13800138244").await;
    let second_user_id = login_user_id(&app, "13800138245").await;

    let first_pet_id =
        create_pet_with_microchip(&app, &first_user_id, "芝麻", "156000000000044").await;
    assert_eq!(
        app.active_microchip_identifier_count(&first_pet_id, "156000000000044")
            .await,
        1
    );

    let second_pet_id =
        create_pet_with_microchip(&app, &second_user_id, "豆包", "156000000000044").await;

    assert_eq!(
        app.active_microchip_identifier_count(&first_pet_id, "156000000000044")
            .await,
        0
    );
    assert_eq!(
        app.microchip_identifier_status_count(&first_pet_id, "156000000000044", "disputed")
            .await,
        1
    );
    assert_eq!(
        app.microchip_identifier_status_count(&second_pet_id, "156000000000044", "disputed")
            .await,
        1
    );
}

#[tokio::test]
async fn pet_profile_detail_returns_external_identifier_summary_for_disputed_microchip() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let first_user_id = login_user_id(&app, "13800138246").await;
    let second_user_id = login_user_id(&app, "13800138247").await;

    let first_pet_id =
        create_pet_with_microchip(&app, &first_user_id, "团子", "156000000000046").await;
    let second_create_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "米糕",
                "species": "dog",
                "sex": "female",
                "microchip_number": "156000000000046"
            }),
            Some(&second_user_id),
        ))
        .await
        .expect("create second pet with shared microchip");
    assert_eq!(second_create_response.status(), StatusCode::CREATED);
    let second_create_body = response_json(second_create_response).await;
    assert_eq!(
        second_create_body["data"]["external_identifiers"][0]["identifier_type"],
        "microchip"
    );
    assert_eq!(
        second_create_body["data"]["external_identifiers"][0]["identifier_value"],
        "156000000000046"
    );
    assert_eq!(
        second_create_body["data"]["external_identifiers"][0]["verified_status"],
        "self_reported"
    );
    assert_eq!(
        second_create_body["data"]["external_identifiers"][0]["status"],
        "disputed"
    );

    let first_detail_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/pets/{first_pet_id}"),
            Some(&first_user_id),
        ))
        .await
        .expect("load first pet profile detail");
    assert_eq!(first_detail_response.status(), StatusCode::OK);
    let first_detail_body = response_json(first_detail_response).await;
    assert_eq!(
        first_detail_body["data"]["external_identifiers"][0]["identifier_value"],
        "156000000000046"
    );
    assert_eq!(
        first_detail_body["data"]["external_identifiers"][0]["status"],
        "disputed"
    );
}

async fn create_pet_with_microchip(
    app: &maohuoban_rust::test_support::AuthTestApp,
    user_id: &str,
    name: &str,
    microchip_number: &str,
) -> String {
    let response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": name,
                "species": "dog",
                "sex": "female",
                "microchip_number": microchip_number
            }),
            Some(user_id),
        ))
        .await
        .expect("create pet with microchip");
    assert_eq!(response.status(), StatusCode::CREATED);
    let body = response_json(response).await;
    body["data"]["id"].as_str().expect("pet id").to_owned()
}
