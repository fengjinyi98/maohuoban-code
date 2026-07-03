use super::*;

#[tokio::test]
async fn active_co_caretaker_can_bind_uploaded_pet_media() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let owner_user_id = login_user_id(&app, "13800138234").await;
    let co_caretaker_user_id = login_user_id(&app, "13800138235").await;

    let create_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "可可",
                "species": "dog",
                "sex": "female"
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
    let upload_body = upload_pending_media(
        &app,
        "/api/v1/pet-media/avatar",
        "caretaker-avatar.png",
        "image/png",
        &tiny_png(),
        &co_caretaker_user_id,
    )
    .await;
    let asset_id = upload_body["data"]["asset"]["id"]
        .as_str()
        .expect("asset id");

    let bind_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/media-bindings"),
            json!({ "asset_id": asset_id }),
            Some(&co_caretaker_user_id),
        ))
        .await
        .expect("co caretaker bind uploaded media");

    assert_eq!(bind_response.status(), StatusCode::CREATED);
    let bind_body = response_json(bind_response).await;
    assert_eq!(bind_body["code"], "pet.media_bound");
    assert_eq!(bind_body["data"]["binding"]["pet_id"], pet_id);
    assert_eq!(
        bind_body["data"]["asset"]["uploaded_by_user_id"],
        co_caretaker_user_id
    );
    assert_eq!(bind_body["data"]["asset"]["owner_pet_id"], pet_id);
}

#[tokio::test]
async fn pet_avatar_upload_creates_traceable_media_binding() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138133").await;

    let create_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "摩卡",
                "species": "dog",
                "sex": "female"
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
        "avatar.png",
        "image/png",
        &tiny_png(),
        &user_id,
    )
    .await;
    let asset_id = upload_body["data"]["asset"]["id"]
        .as_str()
        .expect("asset id");
    let bind_body = bind_uploaded_media(&app, pet_id, asset_id, &user_id).await;
    assert_eq!(bind_body["code"], "pet.media_bound");
    assert_eq!(bind_body["data"]["binding"]["pet_id"], pet_id);
    assert_eq!(bind_body["data"]["binding"]["usage_kind"], "pet.avatar");
    assert_eq!(bind_body["data"]["asset"]["uploaded_by_user_id"], user_id);
    assert_eq!(bind_body["data"]["asset"]["owner_pet_id"], pet_id);
    assert_eq!(bind_body["data"]["asset"]["status"], "bound");
    assert!(
        bind_body["data"]["asset"]["sha256_hex"]
            .as_str()
            .unwrap()
            .len()
            >= 64
    );
    let bucket = upload_body["data"]["asset"]["bucket"]
        .as_str()
        .expect("asset bucket");
    let object_key = upload_body["data"]["asset"]["object_key"]
        .as_str()
        .expect("asset object key");
    assert!(
        object_key.starts_with(&format!("media/users/{user_id}/")),
        "object key should use traceable user prefix, got {object_key}"
    );
    assert!(
        object_key.contains(&format!("/{asset_id}/original.")),
        "object key should include asset id and fixed original file name, got {object_key}"
    );
    assert_eq!(app.media_object_content(bucket, object_key), tiny_png());
}

#[tokio::test]
async fn pending_pet_media_upload_returns_unbound_asset_with_url_and_dimensions() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138138").await;

    let upload_response = app
        .router()
        .oneshot(multipart_media_request(
            "/api/v1/pet-media/avatar",
            "red.png",
            "image/png",
            &STANDARD
                .decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC")
                .expect("red png bytes"),
            "ios",
            &user_id,
        ))
        .await
        .expect("upload pending avatar");
    assert_eq!(upload_response.status(), StatusCode::CREATED);
    let body = response_json(upload_response).await;
    assert_eq!(body["code"], "pet.media_uploaded");
    assert_eq!(body["data"]["asset"]["uploaded_by_user_id"], user_id);
    assert_eq!(body["data"]["asset"]["owner_pet_id"], Value::Null);
    assert_eq!(body["data"]["asset"]["usage_kind"], "pet.avatar");
    assert_eq!(body["data"]["asset"]["status"], "uploaded");
    assert_eq!(body["data"]["asset"]["width"], 1);
    assert_eq!(body["data"]["asset"]["height"], 1);
    let asset_id = body["data"]["asset"]["id"].as_str().expect("asset id");
    assert_eq!(
        body["data"]["asset"]["url"],
        format!("/api/v1/media/assets/{asset_id}/content")
    );
    assert_eq!(body["data"]["binding"], Value::Null);
}

#[tokio::test]
async fn create_pet_profile_binds_uploaded_media_assets() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138139").await;

    let avatar_response = app
        .router()
        .oneshot(multipart_media_request(
            "/api/v1/pet-media/avatar",
            "avatar.png",
            "image/png",
            &tiny_png(),
            "ios",
            &user_id,
        ))
        .await
        .expect("upload pending avatar");
    assert_eq!(avatar_response.status(), StatusCode::CREATED);
    let avatar_body = response_json(avatar_response).await;
    let avatar_asset_id = avatar_body["data"]["asset"]["id"]
        .as_str()
        .expect("avatar asset id");

    let background_response = app
        .router()
        .oneshot(multipart_media_request(
            "/api/v1/pet-media/background-image",
            "background.png",
            "image/png",
            &tiny_png(),
            "ios",
            &user_id,
        ))
        .await
        .expect("upload pending background");
    assert_eq!(background_response.status(), StatusCode::CREATED);
    let background_body = response_json(background_response).await;
    let background_asset_id = background_body["data"]["asset"]["id"]
        .as_str()
        .expect("background asset id");

    let create_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "团子",
                "species": "cat",
                "sex": "female",
                "avatar_asset_id": avatar_asset_id,
                "background_asset_id": background_asset_id
            }),
            Some(&user_id),
        ))
        .await
        .expect("create pet with uploaded media");
    assert_eq!(create_response.status(), StatusCode::CREATED);
    let create_body = response_json(create_response).await;
    let pet_id = create_body["data"]["id"].as_str().expect("pet id");
    assert_eq!(create_body["data"]["avatar_asset_id"], avatar_asset_id);
    assert_eq!(
        create_body["data"]["background_asset_id"],
        background_asset_id
    );
    assert_eq!(create_body["data"]["background_media_kind"], "image");

    let avatar_state = app.media_cleanup_state(avatar_asset_id).await;
    assert_eq!(avatar_state.asset_status, "bound");
    assert_eq!(avatar_state.binding_status, "active");
    let background_state = app.media_cleanup_state(background_asset_id).await;
    assert_eq!(background_state.asset_status, "bound");
    assert_eq!(background_state.binding_status, "active");

    let loaded_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/pets/{pet_id}"),
            Some(&user_id),
        ))
        .await
        .expect("load created pet");
    assert_eq!(loaded_response.status(), StatusCode::OK);
    let loaded_body = response_json(loaded_response).await;
    assert_eq!(loaded_body["data"]["avatar_asset_id"], avatar_asset_id);
    assert_eq!(
        loaded_body["data"]["background_asset_id"],
        background_asset_id
    );
}
