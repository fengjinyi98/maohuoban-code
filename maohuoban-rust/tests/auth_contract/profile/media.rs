use axum::http::StatusCode;
use serde_json::json;
use tower::ServiceExt;

use super::super::{json_request, response_json};
use super::{
    assert_profile_media, authorized_get_request, authorized_multipart_image_request,
    device_payload, send_phone_code, tiny_png,
};

/// 头像/封面上传返回 `CREATED`，响应含 `asset_id`/`url`/`mime_type`/`width`/`height`；后续 `GET` 可读到
#[tokio::test]
async fn profile_me_uploads_avatar_and_cover_media() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;

    let challenge_id = send_phone_code(&app, "13800138015", "ios-profile-media").await;
    let login_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/auth/phone/verify",
            json!({
                "challenge_id": challenge_id,
                "code": "123456",
                "device": device_payload("ios-profile-media")
            }),
        ))
        .await
        .expect("verify phone code");
    assert_eq!(login_response.status(), StatusCode::OK);

    let login_body = response_json(login_response).await;
    let access_token = login_body["data"]["access_token"]
        .as_str()
        .expect("access token");
    let image_content = tiny_png();

    let avatar_response = app
        .router()
        .oneshot(authorized_multipart_image_request(
            "/api/v1/profile/me/avatar",
            access_token,
            "avatar.png",
            "image/png",
            &image_content,
        ))
        .await
        .expect("upload avatar");
    let avatar_status = avatar_response.status();
    let avatar_body = response_json(avatar_response).await;
    assert_eq!(
        avatar_status,
        StatusCode::CREATED,
        "avatar upload body: {avatar_body}"
    );
    assert_eq!(avatar_body["success"], true);
    assert_eq!(avatar_body["code"], "profile.avatar_uploaded");
    assert_eq!(avatar_body["message"], "头像已保存");
    assert_profile_media(&avatar_body["data"]["avatar"], "image/png", 1, 1);

    let cover_response = app
        .router()
        .oneshot(authorized_multipart_image_request(
            "/api/v1/profile/me/cover",
            access_token,
            "cover.png",
            "image/png",
            &image_content,
        ))
        .await
        .expect("upload cover");
    let cover_status = cover_response.status();
    let cover_body = response_json(cover_response).await;
    assert_eq!(
        cover_status,
        StatusCode::CREATED,
        "cover upload body: {cover_body}"
    );
    assert_eq!(cover_body["success"], true);
    assert_eq!(cover_body["code"], "profile.cover_uploaded");
    assert_eq!(cover_body["message"], "主页背景已保存");
    assert_profile_media(&cover_body["data"]["cover"], "image/png", 1, 1);

    let profile_response = app
        .router()
        .oneshot(authorized_get_request("/api/v1/profile/me", access_token))
        .await
        .expect("get profile after media uploads");
    assert_eq!(profile_response.status(), StatusCode::OK);
    let profile_body = response_json(profile_response).await;
    assert_eq!(
        profile_body["data"]["avatar"],
        avatar_body["data"]["avatar"]
    );
    assert_eq!(profile_body["data"]["cover"], cover_body["data"]["cover"]);
}
