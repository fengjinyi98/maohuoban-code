use axum::http::StatusCode;
use serde_json::json;
use tower::ServiceExt;

use super::super::{json_request, response_json};
use super::{
    assert_profile_edit_policy, authorized_get_request, authorized_json_request, device_payload,
    send_phone_code,
};

/// `PATCH` `display_name`/`bio`/`gender`/`is_gender_visible`/`birthday` 后的持久化验证
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

/// 编辑策略的返回与衰减
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

/// 次数耗尽后的 429 拒绝
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
