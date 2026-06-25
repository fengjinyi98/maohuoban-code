use super::*;

#[tokio::test]
async fn pet_profile_delete_is_soft_and_recoverable() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138134").await;

    let create_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "豆包",
                "species": "cat",
                "sex": "unknown"
            }),
            Some(&user_id),
        ))
        .await
        .expect("create pet");
    assert_eq!(create_response.status(), StatusCode::CREATED);
    let create_body = response_json(create_response).await;
    let pet_id = create_body["data"]["id"].as_str().expect("pet id");

    let upload_body = upload_pending_media(
        &app,
        "/api/v1/pet-media/avatar",
        "restore-avatar.txt",
        "text/plain",
        b"avatar-before-delete",
        &user_id,
    )
    .await;
    let asset_id = upload_body["data"]["asset"]["id"]
        .as_str()
        .expect("asset id");
    bind_uploaded_media(&app, pet_id, asset_id, &user_id).await;

    let delete_response = app
        .router()
        .oneshot(json_request(
            "DELETE",
            &format!("/api/v1/pets/{pet_id}"),
            json!({
                "reason": "用户主动删除"
            }),
            Some(&user_id),
        ))
        .await
        .expect("delete pet");
    assert_eq!(delete_response.status(), StatusCode::OK);
    let delete_body = response_json(delete_response).await;
    assert_eq!(delete_body["code"], "pet.deleted");
    assert_eq!(delete_body["data"]["id"], pet_id);
    assert!(delete_body["data"]["deleted_at"].as_str().is_some());
    assert_eq!(delete_body["data"]["delete_requested_by_user_id"], user_id);
    assert!(delete_body["data"]["recoverable_until"].as_str().is_some());

    assert_media_cleanup_state(&app, asset_id, "cleanup_pending", "deleted", "queued").await;

    let timeline_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/pets/{pet_id}/timeline"),
            Some(&user_id),
        ))
        .await
        .expect("load deleted pet timeline");
    assert_eq!(timeline_response.status(), StatusCode::NOT_FOUND);

    let restore_response = app
        .router()
        .oneshot(empty_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/restore"),
            Some(&user_id),
        ))
        .await
        .expect("restore pet");
    assert_eq!(restore_response.status(), StatusCode::OK);
    let restore_body = response_json(restore_response).await;
    assert_eq!(restore_body["code"], "pet.restored");
    assert_eq!(restore_body["data"]["id"], pet_id);
    assert!(restore_body["data"]["deleted_at"].is_null());
    assert!(restore_body["data"]["delete_requested_by_user_id"].is_null());
    assert!(restore_body["data"]["recoverable_until"].is_null());

    assert_media_cleanup_state(&app, asset_id, "bound", "active", "none").await;

    let list_response = app
        .router()
        .oneshot(empty_request("GET", "/api/v1/pets", Some(&user_id)))
        .await
        .expect("list restored pets");
    assert_eq!(list_response.status(), StatusCode::OK);
    let list_body = response_json(list_response).await;
    assert_eq!(list_body["data"]["pets"][0]["id"], pet_id);
}

#[tokio::test]
async fn pet_profile_delete_and_restore_are_owner_only() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let owner_user_id = login_user_id(&app, "13800138243").await;
    let co_caretaker_user_id = login_user_id(&app, "13800138244").await;

    let create_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "豆包",
                "species": "cat",
                "sex": "unknown"
            }),
            Some(&owner_user_id),
        ))
        .await
        .expect("create pet");
    assert_eq!(create_response.status(), StatusCode::CREATED);
    let create_body = response_json(create_response).await;
    let pet_id = create_body["data"]["id"].as_str().expect("pet id");

    app.seed_active_pet_co_caretaker(pet_id, &co_caretaker_user_id)
        .await;

    let co_caretaker_delete_response = app
        .router()
        .oneshot(json_request(
            "DELETE",
            &format!("/api/v1/pets/{pet_id}"),
            json!({
                "reason": "共管尝试删除"
            }),
            Some(&co_caretaker_user_id),
        ))
        .await
        .expect("co caretaker delete pet");
    assert_eq!(co_caretaker_delete_response.status(), StatusCode::NOT_FOUND);

    let owner_delete_response = app
        .router()
        .oneshot(json_request(
            "DELETE",
            &format!("/api/v1/pets/{pet_id}"),
            json!({
                "reason": "owner 删除"
            }),
            Some(&owner_user_id),
        ))
        .await
        .expect("owner delete pet");
    assert_eq!(owner_delete_response.status(), StatusCode::OK);

    let co_caretaker_restore_response = app
        .router()
        .oneshot(empty_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/restore"),
            Some(&co_caretaker_user_id),
        ))
        .await
        .expect("co caretaker restore pet");
    assert_eq!(
        co_caretaker_restore_response.status(),
        StatusCode::NOT_FOUND
    );

    let owner_restore_response = app
        .router()
        .oneshot(empty_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/restore"),
            Some(&owner_user_id),
        ))
        .await
        .expect("owner restore pet");
    assert_eq!(owner_restore_response.status(), StatusCode::OK);
}
