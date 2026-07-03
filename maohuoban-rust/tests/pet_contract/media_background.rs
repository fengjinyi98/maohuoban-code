use super::*;

#[tokio::test]
async fn pet_background_uploads_support_image_and_video_media_bindings() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138135").await;

    let create_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "花卷",
                "species": "cat",
                "sex": "female"
            }),
            Some(&user_id),
        ))
        .await
        .expect("create pet");
    assert_eq!(create_response.status(), StatusCode::CREATED);
    let create_body = response_json(create_response).await;
    let pet_id = create_body["data"]["id"].as_str().expect("pet id");

    let image_upload_body = upload_pending_media(
        &app,
        "/api/v1/pet-media/background-image",
        "background.png",
        "image/png",
        &tiny_png(),
        &user_id,
    )
    .await;
    let image_asset_id = image_upload_body["data"]["asset"]["id"]
        .as_str()
        .expect("image asset id");
    let image_body = bind_uploaded_media(&app, pet_id, image_asset_id, &user_id).await;
    assert_eq!(image_body["code"], "pet.media_bound");
    assert_eq!(
        image_body["data"]["binding"]["usage_kind"],
        "pet.background.image"
    );

    let video_upload_body = upload_pending_media(
        &app,
        "/api/v1/pet-media/background-video",
        "background.mp4",
        "video/mp4",
        b"video-bytes",
        &user_id,
    )
    .await;
    let video_asset_id = video_upload_body["data"]["asset"]["id"]
        .as_str()
        .expect("video asset id");
    let video_body = bind_uploaded_media(&app, pet_id, video_asset_id, &user_id).await;
    assert_eq!(video_body["code"], "pet.media_bound");
    assert_eq!(
        video_body["data"]["binding"]["usage_kind"],
        "pet.background.video"
    );
    assert!(
        video_body["data"]["asset"]["object_key"]
            .as_str()
            .unwrap()
            .starts_with(&format!("media/users/{user_id}/"))
    );
    assert!(
        video_body["data"]["asset"]["object_key"]
            .as_str()
            .unwrap()
            .contains(&format!("/{video_asset_id}/original.mp4"))
    );
}

#[tokio::test]
async fn pet_background_uploads_support_live_photo_media_bindings() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138138").await;

    let create_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "团团",
                "species": "cat",
                "sex": "female"
            }),
            Some(&user_id),
        ))
        .await
        .expect("create pet");
    assert_eq!(create_response.status(), StatusCode::CREATED);
    let create_body = response_json(create_response).await;
    let pet_id = create_body["data"]["id"].as_str().expect("pet id");

    let still_content = STANDARD
        .decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC")
        .expect("still png bytes");
    let upload_body =
        upload_pending_live_photo(&app, &still_content, b"paired-video-bytes", &user_id).await;

    assert_eq!(
        upload_body["data"]["asset"]["usage_kind"],
        "pet.background.live_photo"
    );
    assert_eq!(upload_body["data"]["asset"]["width"], 1);
    assert_eq!(upload_body["data"]["asset"]["height"], 1);
    let components = upload_body["data"]["components"]
        .as_array()
        .expect("live photo components");
    assert_eq!(components.len(), 2);
    assert!(components.iter().any(|item| {
        item["component_kind"] == "still"
            && item["mime_type"] == "image/png"
            && item["width"] == 1
            && item["height"] == 1
    }));
    assert!(components.iter().any(|item| {
        item["component_kind"] == "paired_video"
            && item["mime_type"] == "video/quicktime"
            && item["object_key"]
                .as_str()
                .expect("paired video object key")
                .contains("/paired-video.mov")
    }));

    let live_asset_id = upload_body["data"]["asset"]["id"]
        .as_str()
        .expect("live photo asset id");
    let bind_body = bind_uploaded_media(&app, pet_id, live_asset_id, &user_id).await;
    assert_eq!(bind_body["code"], "pet.media_bound");
    assert_eq!(
        bind_body["data"]["binding"]["usage_kind"],
        "pet.background.live_photo"
    );

    let load_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/pets/{pet_id}"),
            Some(&user_id),
        ))
        .await
        .expect("load pet");
    assert_eq!(load_response.status(), StatusCode::OK);
    let load_body = response_json(load_response).await;
    assert_eq!(load_body["data"]["background_media_kind"], "live_photo");
}

#[tokio::test]
async fn pet_background_live_photo_upload_accepts_crop_metadata() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138139").await;

    let still_content = STANDARD
        .decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC")
        .expect("still png bytes");
    let response = app
        .router()
        .oneshot(multipart_live_photo_request_with_crop(
            &still_content,
            b"paired-video-bytes",
            &user_id,
            Some([
                ("crop_x", "0.125"),
                ("crop_y", "0.25"),
                ("crop_width", "0.5"),
                ("crop_height", "0.375"),
            ]),
        ))
        .await
        .expect("upload pending live photo with crop");

    assert_eq!(response.status(), StatusCode::CREATED);
    let body = response_json(response).await;
    assert_eq!(
        body["data"]["asset"]["usage_kind"],
        "pet.background.live_photo"
    );
}

#[tokio::test]
async fn pet_background_live_photo_crop_metadata_drives_theme_color() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138140").await;

    let still_content = STANDARD
        .decode("iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAIAAAB7QOjdAAAADUlEQVR4nGP4zwAE/wEHAAH/4iOeWQAAAABJRU5ErkJggg==")
        .expect("red blue png bytes");
    let response = app
        .router()
        .oneshot(multipart_live_photo_request_with_crop(
            &still_content,
            b"paired-video-bytes",
            &user_id,
            Some([
                ("crop_x", "0.5"),
                ("crop_y", "0"),
                ("crop_width", "0.5"),
                ("crop_height", "1"),
            ]),
        ))
        .await
        .expect("upload pending live photo with crop");

    assert_eq!(response.status(), StatusCode::CREATED);
    let body = response_json(response).await;
    assert_eq!(body["data"]["asset"]["width"], 2);
    assert_eq!(body["data"]["asset"]["height"], 1);
    let derivatives = body["data"]["derivatives"].as_array().expect("derivatives");
    let theme = derivatives
        .iter()
        .find(|item| item["derivative_kind"] == "theme_color_frame")
        .expect("theme color derivative");
    assert_eq!(theme["metadata"]["theme_color_hex"], "#0000FF");
    assert_eq!(theme["metadata"]["crop"]["x"], 0.5);
    assert_eq!(theme["metadata"]["crop"]["y"], 0.0);
    assert_eq!(theme["metadata"]["crop"]["width"], 0.5);
    assert_eq!(theme["metadata"]["crop"]["height"], 1.0);
}

#[tokio::test]
async fn pet_background_live_photo_heic_still_falls_back_to_video_frame_theme_color() {
    let Some(video_content) = red_video_bytes() else {
        return;
    };
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138141").await;

    let response = app
        .router()
        .oneshot(multipart_live_photo_request_custom(
            "live-still.heic",
            "image/heic",
            b"heic-bytes-not-decodable-by-image-crate",
            "live-motion.mov",
            "video/quicktime",
            &video_content,
            &user_id,
            Some([
                ("crop_x", "0"),
                ("crop_y", "0"),
                ("crop_width", "1"),
                ("crop_height", "1"),
            ]),
        ))
        .await
        .expect("upload pending live photo with heic still");

    assert_eq!(response.status(), StatusCode::CREATED);
    let body = response_json(response).await;
    let derivatives = body["data"]["derivatives"].as_array().expect("derivatives");
    let theme = derivatives
        .iter()
        .find(|item| item["derivative_kind"] == "theme_color_frame")
        .expect("theme color derivative from paired video frame");
    assert_eq!(theme["metadata"]["theme_color_hex"], "#FE0000");
    assert_eq!(theme["metadata"]["crop"]["width"], 1.0);
    assert_eq!(body["data"]["asset"]["width"], 16);
    assert_eq!(body["data"]["asset"]["height"], 16);
}
