use super::*;

#[tokio::test]
async fn home_dashboard_returns_uploaded_pet_media_urls() {
    let app = maohuoban_rust::test_support::spawn_home_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138231").await;
    let pet_id = create_named_home_test_pet(&app, &user_id, "花卷").await;

    let avatar_bytes = STANDARD
        .decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC")
        .expect("avatar png bytes");
    let avatar_body = upload_pending_media(
        &app,
        "/api/v1/pet-media/avatar",
        "avatar.png",
        "image/png",
        &avatar_bytes,
        &user_id,
    )
    .await;
    let avatar_asset_id = avatar_body["data"]["asset"]["id"]
        .as_str()
        .expect("avatar asset id");
    bind_uploaded_media(&app, &pet_id, avatar_asset_id, &user_id).await;

    let background_bytes = STANDARD
        .decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC")
        .expect("background png bytes");
    let background_body = upload_pending_media(
        &app,
        "/api/v1/pet-media/background-image",
        "background.png",
        "image/png",
        &background_bytes,
        &user_id,
    )
    .await;
    let background_asset_id = background_body["data"]["asset"]["id"]
        .as_str()
        .expect("background asset id");
    bind_uploaded_media(&app, &pet_id, background_asset_id, &user_id).await;

    let dashboard_body = load_user_home_dashboard(&app, &user_id).await;
    let avatar_url = format!("/api/v1/media/assets/{avatar_asset_id}/content");
    let background_url = format!("/api/v1/media/assets/{background_asset_id}/content");

    assert_eq!(
        dashboard_body["data"]["selected_pet"]["avatar_url"],
        avatar_url
    );
    assert_eq!(dashboard_body["data"]["selected_pet"]["avatar_width"], 1);
    assert_eq!(dashboard_body["data"]["selected_pet"]["avatar_height"], 1);
    assert_eq!(
        dashboard_body["data"]["selected_pet"]["hero_image_url"],
        background_url
    );
    assert_eq!(
        dashboard_body["data"]["selected_pet"]["hero_image_width"],
        1
    );
    assert_eq!(
        dashboard_body["data"]["selected_pet"]["hero_image_height"],
        1
    );
    assert_eq!(
        dashboard_body["data"]["selected_pet"]["hero_theme_color_hex"],
        "#FF0000"
    );
    assert_eq!(
        dashboard_body["data"]["selected_pet"]["hero_content_color_scheme"],
        "dark"
    );
    assert_eq!(
        dashboard_body["data"]["pet_switcher"][0]["avatar_url"],
        avatar_url
    );
    assert_eq!(dashboard_body["data"]["pet_switcher"][0]["avatar_width"], 1);
    assert_eq!(
        dashboard_body["data"]["pet_switcher"][0]["avatar_height"],
        1
    );

    let media_response = app
        .router()
        .oneshot(empty_request("GET", &avatar_url))
        .await
        .expect("get media content");
    assert_eq!(media_response.status(), StatusCode::OK);
    assert_eq!(
        media_response
            .headers()
            .get("cache-control")
            .and_then(|value| value.to_str().ok()),
        Some("public, max-age=31536000, immutable")
    );
    let bytes = to_bytes(media_response.into_body(), 1024 * 1024)
        .await
        .expect("read media content");
    assert_eq!(&bytes[..], &avatar_bytes[..]);

    assert_media_range_content(&app, &avatar_url, &avatar_bytes).await;
}

#[tokio::test]
async fn home_dashboard_returns_uploaded_live_photo_background_components() {
    let app = maohuoban_rust::test_support::spawn_home_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138232").await;
    let pet_id = create_named_home_test_pet(&app, &user_id, "团团").await;

    let still_bytes = STANDARD
        .decode("iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAIAAAB7QOjdAAAADUlEQVR4nGP4zwAE/wEHAAH/4iOeWQAAAABJRU5ErkJggg==")
        .expect("live still png bytes");
    let video_bytes = b"paired-video-bytes";
    let upload_body = upload_pending_live_photo_with_crop(
        &app,
        &still_bytes,
        video_bytes,
        &user_id,
        Some([
            ("crop_x", "0.5"),
            ("crop_y", "0"),
            ("crop_width", "0.5"),
            ("crop_height", "1"),
        ]),
    )
    .await;
    let live_asset_id = upload_body["data"]["asset"]["id"]
        .as_str()
        .expect("live photo asset id");
    bind_uploaded_media(&app, &pet_id, live_asset_id, &user_id).await;

    let dashboard_body = load_user_home_dashboard(&app, &user_id).await;
    assert!(dashboard_body["data"]["selected_pet"]["hero_image_url"].is_null());
    assert!(dashboard_body["data"]["selected_pet"]["hero_video_url"].is_null());
    assert_eq!(
        dashboard_body["data"]["selected_pet"]["hero_theme_color_hex"],
        "#0000FF"
    );
    let live_photo = &dashboard_body["data"]["selected_pet"]["hero_live_photo"];
    assert!(live_photo["still_url"].as_str().is_some());
    assert_eq!(live_photo["still_width"], 2);
    assert_eq!(live_photo["still_height"], 1);
    assert_eq!(live_photo["crop"]["x"], 0.5);
    assert_eq!(live_photo["crop"]["y"], 0.0);
    assert_eq!(live_photo["crop"]["width"], 0.5);
    assert_eq!(live_photo["crop"]["height"], 1.0);
    let paired_video_url = live_photo["paired_video_url"]
        .as_str()
        .expect("paired video url");
    assert!(paired_video_url.contains("/components/"));

    let paired_video_response = app
        .router()
        .oneshot(empty_request("GET", paired_video_url))
        .await
        .expect("get paired video content");
    assert_eq!(paired_video_response.status(), StatusCode::OK);
    let paired_video_body = to_bytes(paired_video_response.into_body(), 1024 * 1024)
        .await
        .expect("read paired video content");
    assert_eq!(&paired_video_body[..], &video_bytes[..]);

    assert_media_range_content(&app, paired_video_url, video_bytes).await;
}
