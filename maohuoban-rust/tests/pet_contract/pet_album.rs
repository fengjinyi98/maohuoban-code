use super::*;

#[tokio::test]
async fn pet_album_crud_lists_with_cursor_pagination() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800139101").await;

    let first_album = create_album(&app, &user_id, "糯米睡颜", false).await;
    let second_album = create_album(&app, &user_id, "成长记录", true).await;

    let list_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            "/api/v1/pet-albums?limit=1",
            Some(&user_id),
        ))
        .await
        .expect("list pet albums");
    assert_eq!(list_response.status(), StatusCode::OK);
    let list_body = response_json(list_response).await;
    assert_eq!(list_body["code"], "pet_album.list_loaded");
    assert_eq!(list_body["data"]["items"].as_array().unwrap().len(), 1);
    assert_eq!(list_body["data"]["items"][0]["id"], second_album["id"]);
    let cursor = list_body["data"]["next_cursor"]
        .as_str()
        .expect("next cursor");

    let next_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/pet-albums?limit=1&cursor={cursor}"),
            Some(&user_id),
        ))
        .await
        .expect("list next pet albums page");
    assert_eq!(next_response.status(), StatusCode::OK);
    let next_body = response_json(next_response).await;
    assert_eq!(next_body["data"]["items"].as_array().unwrap().len(), 1);
    assert_eq!(next_body["data"]["items"][0]["id"], first_album["id"]);
    assert!(next_body["data"]["next_cursor"].is_null());
}

#[tokio::test]
async fn pet_album_assets_upload_and_page_by_album() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800139102").await;
    let album = create_album(&app, &user_id, "户外散步", false).await;
    let album_id = album["id"].as_str().expect("album id");

    let first_photo = tiny_png();
    let second_photo = tiny_png();
    let first_asset_id = upload_album_photo(&app, &user_id, "first-photo.png", &first_photo).await;
    let second_asset_id =
        upload_album_photo(&app, &user_id, "second-photo.png", &second_photo).await;
    add_album_asset(&app, &user_id, album_id, &first_asset_id, "草地上").await;
    let second_album_asset =
        add_album_asset(&app, &user_id, album_id, &second_asset_id, "回家路上").await;
    let first_storage = app.media_asset_storage_state(&first_asset_id).await;
    assert_eq!(first_storage.mime_type, "image/png");
    assert_eq!(
        first_storage.byte_size,
        i64::try_from(first_photo.len()).unwrap()
    );
    assert_eq!(first_storage.sha256_hex.len(), 64);
    assert_eq!(first_storage.width, Some(1));
    assert_eq!(first_storage.height, Some(1));
    let second_storage = app.media_asset_storage_state(&second_asset_id).await;
    assert_eq!(second_storage.mime_type, "image/png");
    assert_eq!(
        second_storage.byte_size,
        i64::try_from(second_photo.len()).unwrap()
    );
    assert_eq!(second_storage.sha256_hex.len(), 64);
    assert_eq!(second_storage.width, Some(1));
    assert_eq!(second_storage.height, Some(1));

    let detail_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/pet-albums/{album_id}"),
            Some(&user_id),
        ))
        .await
        .expect("load album detail");
    assert_eq!(detail_response.status(), StatusCode::OK);
    let detail_body = response_json(detail_response).await;
    assert_eq!(detail_body["data"]["album"]["photo_count"], 2);
    assert_eq!(
        detail_body["data"]["album"]["cover_asset_id"],
        first_asset_id
    );

    let assets_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/pet-albums/{album_id}/assets?limit=1"),
            Some(&user_id),
        ))
        .await
        .expect("list album assets");
    assert_eq!(assets_response.status(), StatusCode::OK);
    let assets_body = response_json(assets_response).await;
    assert_eq!(assets_body["code"], "pet_album.assets_loaded");
    assert_eq!(assets_body["data"]["items"].as_array().unwrap().len(), 1);
    assert_eq!(assets_body["data"]["items"][0]["asset_id"], second_asset_id);
    assert!(assets_body["data"]["next_cursor"].is_string());

    let album_asset_id = second_album_asset["id"].as_str().expect("album asset id");
    let remove_response = app
        .router()
        .oneshot(json_request(
            "DELETE",
            &format!("/api/v1/pet-album-assets/{album_asset_id}"),
            json!({}),
            Some(&user_id),
        ))
        .await
        .expect("remove album asset");
    assert_eq!(remove_response.status(), StatusCode::OK);
    let remove_body = response_json(remove_response).await;
    assert_eq!(remove_body["code"], "pet_album.asset_removed");
    assert_eq!(remove_body["data"]["album"]["photo_count"], 1);
}

#[tokio::test]
async fn pet_album_photo_upload_rejects_non_image_content() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800139105").await;

    let response = app
        .router()
        .oneshot(multipart_media_request(
            "/api/v1/pet-album-media",
            "album-photo.txt",
            "text/plain",
            b"not-image",
            "ios",
            &user_id,
        ))
        .await
        .expect("upload invalid album photo");

    assert_eq!(response.status(), StatusCode::BAD_REQUEST);
    let body = response_json(response).await;
    assert_eq!(body["code"], "pet.invalid_input");
    assert_eq!(body["message"], "相册照片必须是可解析图片");
}

#[tokio::test]
async fn pet_album_rejects_cross_user_access() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let owner_user_id = login_user_id(&app, "13800139103").await;
    let other_user_id = login_user_id(&app, "13800139104").await;
    let album = create_album(&app, &owner_user_id, "只给主人看", true).await;
    let album_id = album["id"].as_str().expect("album id");

    let response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/pet-albums/{album_id}"),
            Some(&other_user_id),
        ))
        .await
        .expect("other user load album");
    assert_eq!(response.status(), StatusCode::NOT_FOUND);
}

async fn create_album(
    app: &maohuoban_rust::test_support::AuthTestApp,
    user_id: &str,
    title: &str,
    is_private: bool,
) -> Value {
    let response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pet-albums",
            json!({
                "title": title,
                "is_private": is_private
            }),
            Some(user_id),
        ))
        .await
        .expect("create album");
    assert_eq!(response.status(), StatusCode::CREATED);
    let body = response_json(response).await;
    assert_eq!(body["code"], "pet_album.created");
    assert_eq!(body["data"]["title"], title);
    assert!(body["data"]["pet_id"].is_null());
    assert_eq!(body["data"]["photo_count"], 0);
    body["data"].clone()
}

async fn upload_album_photo(
    app: &maohuoban_rust::test_support::AuthTestApp,
    user_id: &str,
    file_name: &str,
    content: &[u8],
) -> String {
    let body = upload_pending_media(
        app,
        "/api/v1/pet-album-media",
        file_name,
        "image/png",
        content,
        user_id,
    )
    .await;
    assert_eq!(body["code"], "pet.media_uploaded");
    assert_eq!(body["data"]["asset"]["usage_kind"], "pet.album.photo");
    body["data"]["asset"]["id"]
        .as_str()
        .expect("album photo asset id")
        .to_owned()
}

async fn add_album_asset(
    app: &maohuoban_rust::test_support::AuthTestApp,
    user_id: &str,
    album_id: &str,
    asset_id: &str,
    caption: &str,
) -> Value {
    let response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pet-albums/{album_id}/assets"),
            json!({
                "asset_id": asset_id,
                "caption": caption
            }),
            Some(user_id),
        ))
        .await
        .expect("add album asset");
    assert_eq!(response.status(), StatusCode::CREATED);
    let body = response_json(response).await;
    assert_eq!(body["code"], "pet_album.asset_added");
    assert_eq!(body["data"]["asset_id"], asset_id);
    assert_eq!(body["data"]["caption"], caption);
    body["data"].clone()
}
