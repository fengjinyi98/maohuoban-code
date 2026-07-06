#![allow(clippy::doc_markdown, clippy::needless_pass_by_value)]

use std::{
    collections::HashMap,
    sync::{LazyLock, Mutex},
};

use axum::{
    body::{Body, to_bytes},
    http::{Request, StatusCode},
};
use serde_json::{Value, json};
use tower::ServiceExt;

static ACCESS_TOKENS: LazyLock<Mutex<HashMap<String, String>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

/// json_request 构造 JSON HTTP 请求
/// 核心职责：
/// - 固定测试请求的 Content-Type
/// - 支持附加服务端签发的 Bearer token
fn json_request(method: &str, uri: &str, body: Value, user_id: Option<&str>) -> Request<Body> {
    let mut builder = Request::builder()
        .method(method)
        .uri(uri)
        .header("content-type", "application/json");
    if let Some(user_id) = user_id
        && let Some(token) = ACCESS_TOKENS.lock().expect("access token map").get(user_id)
    {
        builder = builder.header("authorization", format!("Bearer {token}"));
    }
    builder
        .body(Body::from(body.to_string()))
        .expect("build json request")
}

/// empty_request 构造无 body HTTP 请求
/// 核心职责：
/// - 固定 GET 请求形态
/// - 支持附加服务端签发的 Bearer token
fn empty_request(method: &str, uri: &str, user_id: Option<&str>) -> Request<Body> {
    let mut builder = Request::builder().method(method).uri(uri);
    if let Some(user_id) = user_id
        && let Some(token) = ACCESS_TOKENS.lock().expect("access token map").get(user_id)
    {
        builder = builder.header("authorization", format!("Bearer {token}"));
    }
    builder.body(Body::empty()).expect("build empty request")
}

/// response_json 读取 JSON 响应
/// 核心职责：
/// - 校验响应 body 可解析
/// - 为契约测试提供统一断言入口
async fn response_json(response: axum::response::Response) -> Value {
    let bytes = to_bytes(response.into_body(), 1024 * 1024)
        .await
        .expect("read response body");
    serde_json::from_slice(&bytes).expect("parse response json")
}

/// login_user_id 使用真实验证码登录获取用户 id
/// 核心职责：
/// - 复用认证契约的开发验证码
/// - 为同城接口提供当前用户上下文
async fn login_user_id(app: &maohuoban_rust::test_support::AuthTestApp, phone: &str) -> String {
    let send_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/auth/phone/code",
            json!({
                "phone": phone,
                "agreement_accepted": true,
                "device": {
                    "device_id": "ios-simulator-samecity-contract",
                    "device_name": "iPhone 17 Pro",
                    "platform": "iOS",
                    "app_version": "1.0"
                }
            }),
            None,
        ))
        .await
        .expect("send phone code");
    assert_eq!(send_response.status(), StatusCode::OK);
    let send_body = response_json(send_response).await;
    let challenge_id = send_body["data"]["challenge_id"]
        .as_str()
        .expect("challenge id");

    let verify_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/auth/phone/verify",
            json!({
                "challenge_id": challenge_id,
                "code": "123456",
                "device": {
                    "device_id": "ios-simulator-samecity-contract",
                    "device_name": "iPhone 17 Pro",
                    "platform": "iOS",
                    "app_version": "1.0"
                }
            }),
            None,
        ))
        .await
        .expect("verify phone code");
    assert_eq!(verify_response.status(), StatusCode::OK);
    let verify_body = response_json(verify_response).await;
    let user_id = verify_body["data"]["user"]["id"]
        .as_str()
        .expect("user id")
        .to_owned();
    let access_token = verify_body["data"]["access_token"]
        .as_str()
        .expect("access token")
        .to_owned();
    ACCESS_TOKENS
        .lock()
        .expect("access token map")
        .insert(user_id.clone(), access_token);
    user_id
}

/// seed_his_partner_hospital 写入测试隔离合作医院
/// 核心职责：
/// - 为同城契约测试准备可预约 HIS 医院
/// - 避免依赖迁移或主开发库里的业务数据
async fn seed_his_partner_hospital(
    app: &maohuoban_rust::test_support::AuthTestApp,
    name: &str,
) -> (uuid::Uuid, uuid::Uuid) {
    let his_tenant_id = uuid::Uuid::new_v4();
    let hospital_id = uuid::Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO his_hospital_tenants (
            id,
            name,
            tenant_tier,
            status
        )
        VALUES ($1, $2, 'standard_saas', 'active')
        "#,
    )
    .bind(his_tenant_id)
    .bind(name)
    .execute(app.pool())
    .await
    .expect("insert his tenant");

    sqlx::query(
        r#"
        INSERT INTO samecity_hospitals (
            id,
            name,
            city,
            district,
            address,
            phone,
            service_tags,
            verification_status,
            partnership_status,
            his_enabled,
            his_tenant_id,
            appointment_enabled,
            medical_record_return_enabled
        )
        VALUES (
            $1,
            $2,
            '毛伙伴市',
            '验证区',
            '毛伙伴市验证区闭环路 188 号',
            '028-88880001',
            ARRAY['异常接诊', '病历回流']::text[],
            'verified',
            'active',
            true,
            $3,
            true,
            true
        )
        "#,
    )
    .bind(hospital_id)
    .bind(name)
    .bind(his_tenant_id)
    .execute(app.pool())
    .await
    .expect("insert his hospital");

    (hospital_id, his_tenant_id)
}

#[tokio::test]
async fn samecity_hospital_list_returns_verified_city_hospitals() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138119").await;
    let (expected_hospital_id, _) = seed_his_partner_hospital(&app, "毛伙伴闭环验证医院").await;

    let response = app
        .router()
        .oneshot(empty_request(
            "GET",
            "/api/v1/same-city/hospitals?city=毛伙伴市",
            Some(&user_id),
        ))
        .await
        .expect("list hospitals");

    assert_eq!(response.status(), StatusCode::OK);
    let body = response_json(response).await;
    assert_eq!(body["success"], true);
    assert_eq!(body["code"], "samecity.hospitals_loaded");
    assert_eq!(body["data"]["city"], "毛伙伴市");
    assert_eq!(
        body["data"]["hospitals"][0]["id"],
        expected_hospital_id.to_string()
    );
    assert_eq!(body["data"]["hospitals"][0]["city"], "毛伙伴市");
    assert_eq!(
        body["data"]["hospitals"][0]["verification_status"],
        "verified"
    );
    assert_eq!(body["data"]["hospitals"][0]["partnership_status"], "active");
    assert_eq!(body["data"]["hospitals"][0]["his_enabled"], true);
    assert_eq!(body["data"]["hospitals"][0]["appointment_enabled"], true);
    assert_eq!(
        body["data"]["hospitals"][0]["medical_record_return_enabled"],
        true
    );
    let hospital_id = body["data"]["hospitals"][0]["id"]
        .as_str()
        .expect("hospital id");
    uuid::Uuid::parse_str(hospital_id).expect("hospital id should be uuid");
}

#[tokio::test]
async fn samecity_hospital_list_returns_only_his_partner_hospitals() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138121").await;

    let non_his_hospital_id = uuid::Uuid::new_v4();
    let (his_hospital_id, his_tenant_id) =
        seed_his_partner_hospital(&app, "毛伙伴闭环验证医院").await;

    sqlx::query(
        r#"
        INSERT INTO samecity_hospitals (
            id,
            name,
            city,
            district,
            address,
            service_tags,
            verification_status,
            partnership_status,
            his_enabled,
            his_tenant_id,
            appointment_enabled,
            medical_record_return_enabled
        )
        VALUES
            (
                $1,
                '只认证未接入 HIS 的医院',
                '毛伙伴市',
                '验证区',
                '毛伙伴市验证区测试街 1 号',
                ARRAY['体检']::text[],
                'verified',
                'candidate',
                false,
                NULL,
                true,
                false
            )
        "#,
    )
    .bind(non_his_hospital_id)
    .execute(app.pool())
    .await
    .expect("insert hospitals");

    let response = app
        .router()
        .oneshot(empty_request(
            "GET",
            "/api/v1/same-city/hospitals?city=毛伙伴市",
            Some(&user_id),
        ))
        .await
        .expect("list hospitals");

    assert_eq!(response.status(), StatusCode::OK);
    let body = response_json(response).await;
    let hospitals = body["data"]["hospitals"]
        .as_array()
        .expect("hospitals array");
    assert!(
        hospitals
            .iter()
            .all(|hospital| hospital["id"] != non_his_hospital_id.to_string()),
        "non-HIS verified hospital must not enter App booking list: {hospitals:?}"
    );
    assert!(
        hospitals
            .iter()
            .any(|hospital| hospital["id"] == his_hospital_id.to_string()),
        "HIS partner hospital should enter App booking list: {hospitals:?}"
    );
    let his_hospital = hospitals
        .iter()
        .find(|hospital| hospital["id"] == his_hospital_id.to_string())
        .expect("his hospital in response");
    assert_eq!(his_hospital["partnership_status"], "active");
    assert_eq!(his_hospital["his_enabled"], true);
    assert_eq!(his_hospital["appointment_enabled"], true);
    assert_eq!(his_hospital["medical_record_return_enabled"], true);
    assert_eq!(his_hospital["his_tenant_id"], his_tenant_id.to_string());
}

#[tokio::test]
async fn samecity_hospital_list_requires_authenticated_user() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;

    let response = app
        .router()
        .oneshot(empty_request(
            "GET",
            "/api/v1/same-city/hospitals?city=毛伙伴市",
            None,
        ))
        .await
        .expect("list hospitals without token");

    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
    let body = response_json(response).await;
    assert_eq!(body["success"], false);
    assert_eq!(body["code"], "auth.session_expired");
    assert_eq!(body["message"], "登录状态已过期，请重新登录");
}

#[tokio::test]
async fn samecity_hospital_booking_creates_pending_appointment_for_current_pet() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138120").await;
    seed_his_partner_hospital(&app, "毛伙伴闭环验证医院").await;

    let create_pet_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "糯米",
                "species": "dog",
                "breed": "比熊犬",
                "sex": "female",
                "birthday": "2024-04-01"
            }),
            Some(&user_id),
        ))
        .await
        .expect("create pet");
    assert_eq!(create_pet_response.status(), StatusCode::CREATED);
    let pet_body = response_json(create_pet_response).await;
    let pet_id = pet_body["data"]["id"].as_str().expect("pet id");

    let hospitals_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            "/api/v1/same-city/hospitals?city=毛伙伴市",
            Some(&user_id),
        ))
        .await
        .expect("list hospitals");
    assert_eq!(hospitals_response.status(), StatusCode::OK);
    let hospitals_body = response_json(hospitals_response).await;
    let hospital_id = hospitals_body["data"]["hospitals"][0]["id"]
        .as_str()
        .expect("hospital id");

    let response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/same-city/hospital-appointments",
            json!({
                "hospital_id": hospital_id,
                "pet_id": pet_id,
                "scheduled_at": "2026-06-15T09:30:00Z",
                "reason": "基础体检",
                "note": "希望安排上午到店"
            }),
            Some(&user_id),
        ))
        .await
        .expect("book hospital");

    assert_eq!(response.status(), StatusCode::CREATED);
    let body = response_json(response).await;
    assert_eq!(body["success"], true);
    assert_eq!(body["code"], "samecity.hospital_appointment_created");
    assert_eq!(body["message"], "医院预约已提交");
    assert_eq!(body["data"]["owner_user_id"], user_id);
    assert_eq!(body["data"]["pet_id"], pet_id);
    assert_eq!(body["data"]["hospital_id"], hospital_id);
    assert_eq!(body["data"]["scheduled_at"], "2026-06-15T09:30:00Z");
    assert_eq!(body["data"]["reason"], "基础体检");
    assert_eq!(body["data"]["note"], "希望安排上午到店");
    assert_eq!(body["data"]["status"], "pending");
    let appointment_id = body["data"]["id"].as_str().expect("appointment id");
    uuid::Uuid::parse_str(appointment_id).expect("appointment id should be uuid");
}

#[tokio::test]
async fn samecity_hospital_booking_cancel_marks_current_user_appointment_cancelled() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138123").await;
    seed_his_partner_hospital(&app, "毛伙伴闭环验证医院").await;

    let create_pet_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "奶糖",
                "species": "cat",
                "breed": "布偶",
                "sex": "female",
                "birthday": "2025-01-01"
            }),
            Some(&user_id),
        ))
        .await
        .expect("create pet");
    assert_eq!(create_pet_response.status(), StatusCode::CREATED);
    let pet_body = response_json(create_pet_response).await;
    let pet_id = pet_body["data"]["id"].as_str().expect("pet id");

    let hospitals_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            "/api/v1/same-city/hospitals?city=毛伙伴市",
            Some(&user_id),
        ))
        .await
        .expect("list hospitals");
    let hospitals_body = response_json(hospitals_response).await;
    let hospital_id = hospitals_body["data"]["hospitals"][0]["id"]
        .as_str()
        .expect("hospital id");

    let create_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/same-city/hospital-appointments",
            json!({
                "hospital_id": hospital_id,
                "pet_id": pet_id,
                "scheduled_at": "2026-06-16T09:30:00Z",
                "reason": "异常后就医",
                "note": "取消预约合同测试"
            }),
            Some(&user_id),
        ))
        .await
        .expect("book hospital");
    assert_eq!(create_response.status(), StatusCode::CREATED);
    let create_body = response_json(create_response).await;
    let appointment_id = create_body["data"]["id"].as_str().expect("appointment id");

    let cancel_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/same-city/hospital-appointments/{appointment_id}/cancel"),
            json!({}),
            Some(&user_id),
        ))
        .await
        .expect("cancel hospital appointment");

    assert_eq!(cancel_response.status(), StatusCode::OK);
    let body = response_json(cancel_response).await;
    assert_eq!(body["success"], true);
    assert_eq!(body["code"], "samecity.hospital_appointment_cancelled");
    assert_eq!(body["message"], "医院预约已取消");
    assert_eq!(body["data"]["id"], appointment_id);
    assert_eq!(body["data"]["status"], "cancelled");

    let persisted_status: String =
        sqlx::query_scalar("SELECT status FROM samecity_hospital_appointments WHERE id = $1")
            .bind(uuid::Uuid::parse_str(appointment_id).expect("appointment uuid"))
            .fetch_one(app.pool())
            .await
            .expect("load appointment status");
    assert_eq!(persisted_status, "cancelled");
}

#[tokio::test]
async fn samecity_hospital_booking_rejects_non_his_partner_hospital() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138122").await;

    let hospital_id = uuid::Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO samecity_hospitals (
            id,
            name,
            city,
            district,
            address,
            service_tags,
            verification_status,
            partnership_status,
            his_enabled,
            his_tenant_id,
            appointment_enabled,
            medical_record_return_enabled
        )
        VALUES (
            $1,
            '认证但未接入 HIS 的医院',
            '毛伙伴市',
            '验证区',
            '毛伙伴市验证区测试街 3 号',
            ARRAY['体检']::text[],
            'verified',
            'candidate',
            false,
            NULL,
            true,
            false
        )
        "#,
    )
    .bind(hospital_id)
    .execute(app.pool())
    .await
    .expect("insert non his hospital");

    let response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/same-city/hospital-appointments",
            json!({
                "hospital_id": hospital_id,
                "scheduled_at": "2026-06-15T09:30:00Z",
                "reason": "基础体检",
                "note": "绕过列表直接提交"
            }),
            Some(&user_id),
        ))
        .await
        .expect("book hospital");

    assert_eq!(response.status(), StatusCode::NOT_FOUND);
    let body = response_json(response).await;
    assert_eq!(body["success"], false);
    assert_eq!(body["code"], "samecity.hospital_not_found");
}
