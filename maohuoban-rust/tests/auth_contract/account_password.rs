use axum::{
    body::Body,
    http::{Request, StatusCode},
};
use serde_json::{Value, json};
use tower::ServiceExt;

use super::{json_request, response_json};

#[tokio::test]
async fn account_security_reports_password_state_from_current_user() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;

    let access_token = login_with_phone_code("13800138015", "ios-account-security", &app).await;

    let security_response = app
        .router()
        .oneshot(authorized_empty_request(
            "GET",
            "/api/v1/account/security",
            &access_token,
        ))
        .await
        .expect("load account security");
    assert_eq!(security_response.status(), StatusCode::OK);

    let security_body = response_json(security_response).await;
    assert_eq!(security_body["success"], true);
    assert_eq!(security_body["code"], "account.security_loaded");
    assert_eq!(security_body["message"], "账号安全信息已加载");
    assert_eq!(security_body["data"]["phone_masked"], "138****8015");
    assert_eq!(security_body["data"]["has_password"], false);
    assert_eq!(security_body["data"]["password_status_text"], "未设置");
}

#[tokio::test]
async fn first_password_set_does_not_require_code_and_updates_security_state() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;

    let access_token = login_with_phone_code("13800138016", "ios-password-first-set", &app).await;

    let set_response = app
        .router()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/account/password",
            &access_token,
            json!({
                "new_password": "Newpass123",
                "confirm_password": "Newpass123"
            }),
        ))
        .await
        .expect("set first password");
    assert_eq!(set_response.status(), StatusCode::OK);

    let set_body = response_json(set_response).await;
    assert_eq!(set_body["success"], true);
    assert_eq!(set_body["code"], "account.password_set");
    assert_eq!(set_body["message"], "登录密码已设置");
    assert_eq!(set_body["data"]["has_password"], true);
    assert_eq!(set_body["data"]["password_status_text"], "已设置");

    let repeated_response = app
        .router()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/account/password",
            &access_token,
            json!({
                "new_password": "Otherpass123",
                "confirm_password": "Otherpass123"
            }),
        ))
        .await
        .expect("repeat set first password");
    assert_eq!(repeated_response.status(), StatusCode::CONFLICT);

    let repeated_body = response_json(repeated_response).await;
    assert_eq!(repeated_body["success"], false);
    assert_eq!(repeated_body["code"], "account.password_already_set");
    assert_eq!(repeated_body["message"], "登录密码已设置");
}

#[tokio::test]
async fn password_change_requires_current_password_and_phone_code() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;

    let access_token = login_with_phone_code("13800138017", "ios-password-change", &app).await;
    let set_response = app
        .router()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/account/password",
            &access_token,
            json!({
                "new_password": "Oldpass123",
                "confirm_password": "Oldpass123"
            }),
        ))
        .await
        .expect("set old password");
    assert_eq!(set_response.status(), StatusCode::OK);

    let code_response = app
        .router()
        .oneshot(authorized_empty_request(
            "POST",
            "/api/v1/account/password/change-code",
            &access_token,
        ))
        .await
        .expect("send password change code");
    assert_eq!(code_response.status(), StatusCode::OK);

    let code_body = response_json(code_response).await;
    assert_eq!(code_body["success"], true);
    assert_eq!(code_body["code"], "account.password_change_code_sent");
    assert_eq!(code_body["message"], "验证码已发送");
    let challenge_id = code_body["data"]["challenge_id"]
        .as_str()
        .expect("challenge id");

    let wrong_current_response = app
        .router()
        .oneshot(authorized_json_request(
            "PATCH",
            "/api/v1/account/password",
            &access_token,
            json!({
                "current_password": "Wrongpass123",
                "challenge_id": challenge_id,
                "code": "123456",
                "new_password": "Newpass123",
                "confirm_password": "Newpass123"
            }),
        ))
        .await
        .expect("change password with wrong current password");
    assert_eq!(wrong_current_response.status(), StatusCode::UNAUTHORIZED);

    let wrong_current_body = response_json(wrong_current_response).await;
    assert_eq!(wrong_current_body["success"], false);
    assert_eq!(
        wrong_current_body["code"],
        "account.current_password_invalid"
    );
    assert_eq!(wrong_current_body["message"], "当前登录密码错误");

    let change_response = app
        .router()
        .oneshot(authorized_json_request(
            "PATCH",
            "/api/v1/account/password",
            &access_token,
            json!({
                "current_password": "Oldpass123",
                "challenge_id": challenge_id,
                "code": "123456",
                "new_password": "Newpass123",
                "confirm_password": "Newpass123"
            }),
        ))
        .await
        .expect("change password");
    assert_eq!(change_response.status(), StatusCode::OK);

    let change_body = response_json(change_response).await;
    assert_eq!(change_body["success"], true);
    assert_eq!(change_body["code"], "account.password_changed");
    assert_eq!(change_body["message"], "登录密码已修改");
    assert_eq!(change_body["data"]["has_password"], true);
}

#[tokio::test]
async fn password_change_returns_clear_message_when_password_not_set() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;

    let access_token = login_with_phone_code("13800138018", "ios-password-not-set", &app).await;

    let response = app
        .router()
        .oneshot(authorized_json_request(
            "PATCH",
            "/api/v1/account/password",
            &access_token,
            json!({
                "current_password": "Oldpass123",
                "challenge_id": "missing",
                "code": "123456",
                "new_password": "Newpass123",
                "confirm_password": "Newpass123"
            }),
        ))
        .await
        .expect("change password before first set");
    assert_eq!(response.status(), StatusCode::BAD_REQUEST);

    let body = response_json(response).await;
    assert_eq!(body["success"], false);
    assert_eq!(body["code"], "account.password_not_set");
    assert_eq!(body["message"], "请先设置登录密码");
}

async fn login_with_phone_code(
    phone: &str,
    device_id: &str,
    app: &maohuoban_rust::test_support::AuthTestApp,
) -> String {
    let challenge_response = app
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
    assert_eq!(challenge_response.status(), StatusCode::OK);
    let challenge_body = response_json(challenge_response).await;
    let challenge_id = challenge_body["data"]["challenge_id"]
        .as_str()
        .expect("challenge id");

    let login_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/auth/phone/verify",
            json!({
                "challenge_id": challenge_id,
                "code": "123456",
                "device": device_payload(device_id)
            }),
        ))
        .await
        .expect("login with phone code");
    assert_eq!(login_response.status(), StatusCode::OK);

    let login_body = response_json(login_response).await;
    login_body["data"]["access_token"]
        .as_str()
        .expect("access token")
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

fn authorized_empty_request(method: &str, uri: &str, access_token: &str) -> Request<Body> {
    Request::builder()
        .method(method)
        .uri(uri)
        .header("authorization", format!("Bearer {access_token}"))
        .body(Body::empty())
        .expect("build authorized empty request")
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
