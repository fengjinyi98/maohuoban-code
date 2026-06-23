use axum::{
    body::Body,
    http::{Request, StatusCode},
};
use serde_json::{Value, json};
use tower::ServiceExt;

use super::{json_request, response_json};
use maohuoban_rust::test_support::AuthTestApp;

#[tokio::test]
async fn account_devices_list_detail_and_revoke_other_device() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    app.seed_user_with_password("13800138019", "Oldpass123")
        .await;

    let first_login = password_login("13800138019", "Oldpass123", "ios-device-current", &app).await;
    let second_login = password_login("13800138019", "Oldpass123", "ios-device-ipad", &app).await;

    let devices_body = load_devices(&app, &first_login.access_token).await;
    let (current_session_id, other_session_id) = assert_initial_devices(&devices_body);

    assert_other_device_detail(&app, &first_login.access_token, &other_session_id).await;
    assert_current_device_remove_forbidden(&app, &first_login.access_token, &current_session_id)
        .await;
    assert_other_device_removed(&app, &first_login.access_token, &other_session_id).await;
    assert_removed_device_refresh_invalid(&app, second_login.refresh_token).await;
    assert_only_current_device_remains(&app, &first_login.access_token).await;
}

async fn load_devices(app: &AuthTestApp, access_token: &str) -> Value {
    let devices_response = app
        .router()
        .oneshot(authorized_empty_request(
            "GET",
            "/api/v1/account/devices",
            access_token,
        ))
        .await
        .expect("load account devices");
    assert_eq!(devices_response.status(), StatusCode::OK);

    response_json(devices_response).await
}

fn assert_initial_devices(devices_body: &Value) -> (String, String) {
    assert_eq!(devices_body["success"], true);
    assert_eq!(devices_body["code"], "account.devices_loaded");
    assert_eq!(devices_body["message"], "登录设备已加载");
    let devices = devices_body["data"]["devices"]
        .as_array()
        .expect("devices array");
    assert_eq!(devices.len(), 2);

    let current_session_id = find_session_id_by_device(devices_body, "ios-device-current");
    let other_session_id = find_session_id_by_device(devices_body, "ios-device-ipad");
    assert_eq!(
        find_device(devices_body, "ios-device-current")["is_current_device"],
        true
    );
    assert_eq!(
        find_device(devices_body, "ios-device-ipad")["is_current_device"],
        false
    );
    assert_eq!(
        find_device(devices_body, "ios-device-current")["last_active_text"],
        "当前在线"
    );

    (current_session_id, other_session_id)
}

async fn assert_other_device_detail(app: &AuthTestApp, access_token: &str, other_session_id: &str) {
    let detail_response = app
        .router()
        .oneshot(authorized_empty_request(
            "GET",
            &format!("/api/v1/account/devices/{other_session_id}"),
            access_token,
        ))
        .await
        .expect("load other device detail");
    assert_eq!(detail_response.status(), StatusCode::OK);

    let detail_body = response_json(detail_response).await;
    assert_eq!(detail_body["success"], true);
    assert_eq!(detail_body["code"], "account.device_loaded");
    assert_eq!(detail_body["message"], "登录设备详情已加载");
    assert_eq!(detail_body["data"]["session_id"], other_session_id);
    assert_eq!(detail_body["data"]["device_id"], "ios-device-ipad");
    assert_eq!(detail_body["data"]["device_name"], "iPad Pro");
    assert_eq!(detail_body["data"]["platform"], "iPadOS");
    assert_eq!(detail_body["data"]["is_current_device"], false);
}

async fn assert_current_device_remove_forbidden(
    app: &AuthTestApp,
    access_token: &str,
    current_session_id: &str,
) {
    let remove_current_response = app
        .router()
        .oneshot(authorized_empty_request(
            "DELETE",
            &format!("/api/v1/account/devices/{current_session_id}"),
            access_token,
        ))
        .await
        .expect("remove current device");
    assert_eq!(remove_current_response.status(), StatusCode::BAD_REQUEST);

    let remove_current_body = response_json(remove_current_response).await;
    assert_eq!(remove_current_body["success"], false);
    assert_eq!(
        remove_current_body["code"],
        "account.current_device_remove_forbidden"
    );
    assert_eq!(remove_current_body["message"], "当前设备请通过退出登录移除");
}

async fn assert_other_device_removed(
    app: &AuthTestApp,
    access_token: &str,
    other_session_id: &str,
) {
    let remove_other_response = app
        .router()
        .oneshot(authorized_empty_request(
            "DELETE",
            &format!("/api/v1/account/devices/{other_session_id}"),
            access_token,
        ))
        .await
        .expect("remove other device");
    assert_eq!(remove_other_response.status(), StatusCode::OK);

    let remove_other_body = response_json(remove_other_response).await;
    assert_eq!(remove_other_body["success"], true);
    assert_eq!(remove_other_body["code"], "account.device_revoked");
    assert_eq!(remove_other_body["message"], "登录设备已移除");
}

async fn assert_removed_device_refresh_invalid(app: &AuthTestApp, refresh_token: String) {
    let refresh_removed_device_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/auth/refresh",
            json!({
                "refresh_token": refresh_token,
                "device_id": "ios-device-ipad"
            }),
        ))
        .await
        .expect("refresh removed device");
    assert_eq!(
        refresh_removed_device_response.status(),
        StatusCode::UNAUTHORIZED
    );
}

async fn assert_only_current_device_remains(app: &AuthTestApp, access_token: &str) {
    let devices_after_remove_body = load_devices(app, access_token).await;
    let devices_after_remove = devices_after_remove_body["data"]["devices"]
        .as_array()
        .expect("devices array after remove");
    assert_eq!(devices_after_remove.len(), 1);
    assert_eq!(
        find_device(&devices_after_remove_body, "ios-device-current")["is_current_device"],
        true
    );
}

async fn password_login(
    phone: &str,
    password: &str,
    device_id: &str,
    app: &AuthTestApp,
) -> DeviceLogin {
    let login_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/auth/password/login",
            json!({
                "phone": phone,
                "password": password,
                "device": device_payload(device_id)
            }),
        ))
        .await
        .expect("login with password");
    assert_eq!(login_response.status(), StatusCode::OK);

    let login_body = response_json(login_response).await;
    DeviceLogin {
        access_token: login_body["data"]["access_token"]
            .as_str()
            .expect("access token")
            .to_owned(),
        refresh_token: login_body["data"]["refresh_token"]
            .as_str()
            .expect("refresh token")
            .to_owned(),
    }
}

fn device_payload(device_id: &str) -> Value {
    let (device_name, platform) = if device_id.contains("ipad") {
        ("iPad Pro", "iPadOS")
    } else {
        ("iPhone 17 Pro", "iOS")
    };
    json!({
        "device_id": device_id,
        "device_name": device_name,
        "platform": platform,
        "app_version": "1.0"
    })
}

fn find_device<'a>(json: &'a Value, device_id: &str) -> &'a Value {
    json["data"]["devices"]
        .as_array()
        .expect("devices array")
        .iter()
        .find(|device| device["device_id"] == device_id)
        .expect("device exists")
}

fn find_session_id_by_device(json: &Value, device_id: &str) -> String {
    find_device(json, device_id)["session_id"]
        .as_str()
        .expect("session id")
        .to_owned()
}

fn authorized_empty_request(method: &str, uri: &str, access_token: &str) -> Request<Body> {
    Request::builder()
        .method(method)
        .uri(uri)
        .header("authorization", format!("Bearer {access_token}"))
        .body(Body::empty())
        .expect("build authorized request")
}

struct DeviceLogin {
    access_token: String,
    refresh_token: String,
}
