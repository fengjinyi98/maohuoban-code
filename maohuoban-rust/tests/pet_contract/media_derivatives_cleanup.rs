use super::*;

#[tokio::test]
async fn pet_background_image_upload_generates_derivatives_and_theme_color() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138136").await;

    let body = upload_pending_media(
        &app,
        "/api/v1/pet-media/background-image",
        "red.png",
        "image/png",
        &STANDARD
            .decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC")
            .expect("red png bytes"),
        &user_id,
    )
    .await;
    assert_eq!(body["data"]["asset"]["width"], 1);
    assert_eq!(body["data"]["asset"]["height"], 1);
    let derivatives = body["data"]["derivatives"].as_array().expect("derivatives");

    assert!(
        derivatives
            .iter()
            .any(|item| item["derivative_kind"] == "thumbnail")
    );
    let theme = derivatives
        .iter()
        .find(|item| item["derivative_kind"] == "theme_color_frame")
        .expect("theme color derivative");
    assert_eq!(theme["metadata"]["theme_color_hex"], "#FF0000");
    assert!(
        theme["object_key"]
            .as_str()
            .expect("theme object key")
            .contains("theme_color_frame")
    );
}

#[tokio::test]
async fn pet_background_video_upload_generates_cover_frame_and_theme_color() {
    let Some(video_content) = red_video_bytes() else {
        return;
    };
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138137").await;

    let body = upload_pending_media(
        &app,
        "/api/v1/pet-media/background-video",
        "red.mp4",
        "video/mp4",
        &video_content,
        &user_id,
    )
    .await;
    assert_eq!(body["data"]["asset"]["width"], 16);
    assert_eq!(body["data"]["asset"]["height"], 16);
    let derivatives = body["data"]["derivatives"].as_array().expect("derivatives");

    assert!(
        derivatives
            .iter()
            .any(|item| item["derivative_kind"] == "video_cover_frame")
    );
    let theme = derivatives
        .iter()
        .find(|item| item["derivative_kind"] == "theme_color_frame")
        .expect("theme color derivative");
    assert_eq!(theme["metadata"]["theme_color_hex"], "#FE0000");
}

#[tokio::test]
async fn replacing_avatar_queues_previous_media_for_cleanup() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138136").await;

    let create_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "芝麻",
                "species": "dog",
                "sex": "male"
            }),
            Some(&user_id),
        ))
        .await
        .expect("create pet");
    assert_eq!(create_response.status(), StatusCode::CREATED);
    let create_body = response_json(create_response).await;
    let pet_id = create_body["data"]["id"].as_str().expect("pet id");

    let first_body = upload_pending_media(
        &app,
        "/api/v1/pet-media/avatar",
        "avatar-1.txt",
        "text/plain",
        b"avatar-one",
        &user_id,
    )
    .await;
    let old_asset_id = first_body["data"]["asset"]["id"]
        .as_str()
        .expect("asset id");
    bind_uploaded_media(&app, pet_id, old_asset_id, &user_id).await;

    let second_body = upload_pending_media(
        &app,
        "/api/v1/pet-media/avatar",
        "avatar-2.txt",
        "text/plain",
        b"avatar-two",
        &user_id,
    )
    .await;
    let second_asset_id = second_body["data"]["asset"]["id"]
        .as_str()
        .expect("asset id");
    bind_uploaded_media(&app, pet_id, second_asset_id, &user_id).await;

    assert_media_cleanup_state(&app, old_asset_id, "cleanup_pending", "replaced", "queued").await;
}
