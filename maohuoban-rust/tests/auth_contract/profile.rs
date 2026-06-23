use axum::{
    body::Body,
    http::{Request, StatusCode},
};
use base64::{Engine as _, engine::general_purpose::STANDARD};
use serde_json::{Value, json};
use tower::ServiceExt;

use super::{json_request, response_json};

#[tokio::test]
async fn phone_code_login_returns_current_user_profile_summary_without_badges() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;

    let challenge_id = send_phone_code(&app, "13800138010", "ios-profile-login-summary").await;
    let response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/auth/phone/verify",
            json!({
                "challenge_id": challenge_id,
                "code": "123456",
                "device": device_payload("ios-profile-login-summary")
            }),
        ))
        .await
        .expect("verify phone code");
    assert_eq!(response.status(), StatusCode::OK);

    let body = response_json(response).await;
    let user = &body["data"]["user"];
    assert_eq!(user["phone"], "13800138010");
    assert_eq!(user["phone_masked"], "138****8010");
    assert_eq!(user["has_password"], false);
    assert!(user.get("badges").is_none());

    let profile = &user["profile"];
    assert!(profile["maohuoban_id"].as_str().is_some());
    assert!(
        profile["display_name"]
            .as_str()
            .expect("display_name")
            .starts_with("毛伙伴用户")
    );
    assert!(profile.get("join_sequence").is_none());
    assert_eq!(profile["avatar_presentation"]["sex"], "unknown");
    assert_eq!(profile["avatar_presentation"]["sex_visibility"], "hidden");
}

#[tokio::test]
async fn profile_me_returns_same_profile_created_by_login_token() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;

    let challenge_id = send_phone_code(&app, "13800138011", "ios-profile-me").await;
    let login_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/auth/phone/verify",
            json!({
                "challenge_id": challenge_id,
                "code": "123456",
                "device": device_payload("ios-profile-me")
            }),
        ))
        .await
        .expect("verify phone code");
    assert_eq!(login_response.status(), StatusCode::OK);

    let login_body = response_json(login_response).await;
    let access_token = login_body["data"]["access_token"]
        .as_str()
        .expect("access token");
    let login_profile = &login_body["data"]["user"]["profile"];

    let profile_response = app
        .router()
        .oneshot(authorized_get_request("/api/v1/profile/me", access_token))
        .await
        .expect("get profile me");
    assert_eq!(profile_response.status(), StatusCode::OK);

    let profile_body = response_json(profile_response).await;
    assert_eq!(profile_body["success"], true);
    assert_eq!(profile_body["code"], "profile.loaded");
    assert_eq!(profile_body["message"], "个人资料已加载");
    assert_eq!(
        profile_body["data"]["maohuoban_id"],
        login_profile["maohuoban_id"]
    );
    assert_eq!(
        profile_body["data"]["display_name"],
        login_profile["display_name"]
    );
    assert_eq!(
        profile_body["data"]["avatar_presentation"],
        login_profile["avatar_presentation"]
    );
    assert!(profile_body["data"].get("join_sequence").is_none());
    assert!(profile_body["data"].get("badges").is_none());
}

#[tokio::test]
async fn profile_me_patch_updates_editable_fields_from_single_profile_source() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;

    let challenge_id = send_phone_code(&app, "13800138012", "ios-profile-update").await;
    let login_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/auth/phone/verify",
            json!({
                "challenge_id": challenge_id,
                "code": "123456",
                "device": device_payload("ios-profile-update")
            }),
        ))
        .await
        .expect("verify phone code");
    assert_eq!(login_response.status(), StatusCode::OK);

    let login_body = response_json(login_response).await;
    let access_token = login_body["data"]["access_token"]
        .as_str()
        .expect("access token");

    let update_response = app
        .router()
        .oneshot(authorized_json_request(
            "PATCH",
            "/api/v1/profile/me",
            access_token,
            json!({
                "display_name": "橘子午后",
                "bio": "记录两只毛孩子的日常。",
                "gender": "female",
                "is_gender_visible": false,
                "birthday": "1999-12-31"
            }),
        ))
        .await
        .expect("patch profile me");
    assert_eq!(update_response.status(), StatusCode::OK);

    let update_body = response_json(update_response).await;
    assert_eq!(update_body["success"], true);
    assert_eq!(update_body["code"], "profile.updated");
    assert_eq!(update_body["message"], "个人资料已更新");
    assert_eq!(update_body["data"]["display_name"], "橘子午后");
    assert_eq!(update_body["data"]["bio"], "记录两只毛孩子的日常。");
    assert_eq!(update_body["data"]["gender"], "female");
    assert_eq!(update_body["data"]["is_gender_visible"], false);
    assert_eq!(update_body["data"]["birthday"], "1999-12-31");
    assert_eq!(update_body["data"]["birthday_display_text"], "1999-12-31");
    assert_eq!(update_body["data"]["avatar_presentation"]["sex"], "unknown");
    assert_eq!(
        update_body["data"]["avatar_presentation"]["sex_visibility"],
        "hidden"
    );

    let profile_response = app
        .router()
        .oneshot(authorized_get_request("/api/v1/profile/me", access_token))
        .await
        .expect("get profile me after update");
    assert_eq!(profile_response.status(), StatusCode::OK);

    let profile_body = response_json(profile_response).await;
    assert_eq!(profile_body["data"]["display_name"], "橘子午后");
    assert_eq!(profile_body["data"]["bio"], "记录两只毛孩子的日常。");
    assert_eq!(
        profile_body["data"]["avatar_presentation"],
        update_body["data"]["avatar_presentation"]
    );
}

#[tokio::test]
async fn profile_me_returns_edit_policy_for_display_name_and_bio() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;

    let challenge_id = send_phone_code(&app, "13800138013", "ios-profile-policy").await;
    let login_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/auth/phone/verify",
            json!({
                "challenge_id": challenge_id,
                "code": "123456",
                "device": device_payload("ios-profile-policy")
            }),
        ))
        .await
        .expect("verify phone code");
    assert_eq!(login_response.status(), StatusCode::OK);
    let login_body = response_json(login_response).await;
    let access_token = login_body["data"]["access_token"]
        .as_str()
        .expect("access token");

    let profile_response = app
        .router()
        .oneshot(authorized_get_request("/api/v1/profile/me", access_token))
        .await
        .expect("get profile me");
    assert_eq!(profile_response.status(), StatusCode::OK);
    let profile_body = response_json(profile_response).await;
    assert_profile_edit_policy(&profile_body["data"]["display_name_edit_policy"], 5, 0, 5);
    assert_profile_edit_policy(&profile_body["data"]["bio_edit_policy"], 3, 0, 3);

    let update_response = app
        .router()
        .oneshot(authorized_json_request(
            "PATCH",
            "/api/v1/profile/me",
            access_token,
            json!({
                "display_name": "橘子午后",
                "bio": "记录两只毛孩子的日常。"
            }),
        ))
        .await
        .expect("patch profile me");
    assert_eq!(update_response.status(), StatusCode::OK);
    let update_body = response_json(update_response).await;
    assert_profile_edit_policy(&update_body["data"]["display_name_edit_policy"], 5, 1, 4);
    assert_profile_edit_policy(&update_body["data"]["bio_edit_policy"], 3, 1, 2);
}

#[tokio::test]
async fn profile_me_patch_rejects_display_name_and_bio_when_edit_policy_exhausted() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;

    let challenge_id = send_phone_code(&app, "13800138014", "ios-profile-policy-limit").await;
    let login_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/auth/phone/verify",
            json!({
                "challenge_id": challenge_id,
                "code": "123456",
                "device": device_payload("ios-profile-policy-limit")
            }),
        ))
        .await
        .expect("verify phone code");
    assert_eq!(login_response.status(), StatusCode::OK);
    let login_body = response_json(login_response).await;
    let access_token = login_body["data"]["access_token"]
        .as_str()
        .expect("access token");

    for name in ["小一", "小二", "小三", "小四", "小五"] {
        let response = app
            .router()
            .oneshot(authorized_json_request(
                "PATCH",
                "/api/v1/profile/me",
                access_token,
                json!({ "display_name": name }),
            ))
            .await
            .expect("update display name");
        assert_eq!(response.status(), StatusCode::OK);
    }

    let rejected_name_response = app
        .router()
        .oneshot(authorized_json_request(
            "PATCH",
            "/api/v1/profile/me",
            access_token,
            json!({ "display_name": "小六" }),
        ))
        .await
        .expect("reject display name");
    assert_eq!(
        rejected_name_response.status(),
        StatusCode::TOO_MANY_REQUESTS
    );
    let rejected_name_body = response_json(rejected_name_response).await;
    assert_eq!(rejected_name_body["success"], false);
    assert_eq!(
        rejected_name_body["code"],
        "profile.display_name_edit_limit_exceeded"
    );
    assert_eq!(
        rejected_name_body["message"],
        "昵称修改次数已用完，请稍后再试"
    );

    for bio in ["简介一", "简介二", "简介三"] {
        let response = app
            .router()
            .oneshot(authorized_json_request(
                "PATCH",
                "/api/v1/profile/me",
                access_token,
                json!({ "bio": bio }),
            ))
            .await
            .expect("update bio");
        assert_eq!(response.status(), StatusCode::OK);
    }

    let rejected_bio_response = app
        .router()
        .oneshot(authorized_json_request(
            "PATCH",
            "/api/v1/profile/me",
            access_token,
            json!({ "bio": "简介四" }),
        ))
        .await
        .expect("reject bio");
    assert_eq!(
        rejected_bio_response.status(),
        StatusCode::TOO_MANY_REQUESTS
    );
    let rejected_bio_body = response_json(rejected_bio_response).await;
    assert_eq!(rejected_bio_body["success"], false);
    assert_eq!(rejected_bio_body["code"], "profile.bio_edit_limit_exceeded");
    assert_eq!(
        rejected_bio_body["message"],
        "简介修改次数已用完，请稍后再试"
    );
}

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

async fn send_phone_code(
    app: &maohuoban_rust::test_support::AuthTestApp,
    phone: &str,
    device_id: &str,
) -> String {
    let response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/auth/phone/code",
            json!({
                "phone": phone,
                "agreement_accepted": true,
                "device": device_payload(device_id)
            }),
        ))
        .await
        .expect("send phone code");
    assert_eq!(response.status(), StatusCode::OK);

    let body = response_json(response).await;
    body["data"]["challenge_id"]
        .as_str()
        .expect("challenge_id")
        .to_owned()
}

fn device_payload(device_id: &str) -> Value {
    json!({
        "device_id": device_id,
        "device_name": "iPhone 17 Pro",
        "platform": "iOS",
        "app_version": "1.0"
    })
}

fn authorized_get_request(uri: &str, access_token: &str) -> Request<Body> {
    Request::builder()
        .method("GET")
        .uri(uri)
        .header("authorization", format!("Bearer {access_token}"))
        .body(Body::empty())
        .expect("build authorized get request")
}

fn authorized_json_request(
    method: &str,
    uri: &str,
    access_token: &str,
    body: Value,
) -> Request<Body> {
    Request::builder()
        .method(method)
        .uri(uri)
        .header("authorization", format!("Bearer {access_token}"))
        .header("content-type", "application/json")
        .body(Body::from(body.to_string()))
        .expect("build authorized json request")
}

fn authorized_multipart_image_request(
    uri: &str,
    access_token: &str,
    file_name: &str,
    mime_type: &str,
    content: &[u8],
) -> Request<Body> {
    let boundary = format!("maohuoban-profile-test-{}", uuid::Uuid::new_v4());
    let mut body = Vec::new();
    body.extend_from_slice(format!("--{boundary}\r\n").as_bytes());
    body.extend_from_slice(
        format!(
            "Content-Disposition: form-data; name=\"file\"; filename=\"{file_name}\"\r\n\
             Content-Type: {mime_type}\r\n\r\n"
        )
        .as_bytes(),
    );
    body.extend_from_slice(content);
    body.extend_from_slice(b"\r\n");
    body.extend_from_slice(format!("--{boundary}\r\n").as_bytes());
    body.extend_from_slice(
        b"Content-Disposition: form-data; name=\"source_client\"\r\n\r\nios\r\n",
    );
    body.extend_from_slice(format!("--{boundary}--\r\n").as_bytes());

    Request::builder()
        .method("POST")
        .uri(uri)
        .header("authorization", format!("Bearer {access_token}"))
        .header(
            "content-type",
            format!("multipart/form-data; boundary={boundary}"),
        )
        .body(Body::from(body))
        .expect("build authorized multipart image request")
}

fn assert_profile_edit_policy(
    policy: &Value,
    max_count: i64,
    used_count: i64,
    remaining_count: i64,
) {
    assert_eq!(policy["max_count"], max_count);
    assert_eq!(policy["used_count"], used_count);
    assert_eq!(policy["remaining_count"], remaining_count);
    assert_eq!(policy["window_days"], 30);
    assert!(policy["display_text"].as_str().is_some());
}

fn assert_profile_media(media: &Value, mime_type: &str, width: i64, height: i64) {
    assert!(media["asset_id"].as_str().is_some());
    assert!(
        media["url"]
            .as_str()
            .expect("profile media url")
            .starts_with("/api/v1/media/assets/")
    );
    assert_eq!(media["mime_type"], mime_type);
    assert_eq!(media["width"], width);
    assert_eq!(media["height"], height);
    assert!(media["updated_at"].as_str().is_some());
}

fn tiny_png() -> Vec<u8> {
    STANDARD
        .decode(
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC",
        )
        .expect("decode tiny png")
}
