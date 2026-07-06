#![allow(clippy::needless_pass_by_value)]

use axum::{
    body::{Body, to_bytes},
    http::{Request, StatusCode},
};
use chrono::{Duration, Utc};
use serde_json::{Value, json};
use tower::ServiceExt;
use uuid::Uuid;

/// json_request 构造 JSON 请求
/// 核心职责：
/// - 固定测试请求的 JSON 形态
/// - 注入真实登录后端签发的 Bearer token
fn json_request(method: &str, uri: &str, body: Value, token: Option<&str>) -> Request<Body> {
    let mut builder = Request::builder()
        .method(method)
        .uri(uri)
        .header("content-type", "application/json");
    if let Some(token) = token {
        builder = builder.header("authorization", format!("Bearer {token}"));
    }
    builder
        .body(Body::from(body.to_string()))
        .expect("build json request")
}

/// empty_request 构造空请求
/// 核心职责：
/// - 支持 GET 合同测试
/// - 注入真实登录后端签发的 Bearer token
fn empty_request(method: &str, uri: &str, token: Option<&str>) -> Request<Body> {
    let mut builder = Request::builder().method(method).uri(uri);
    if let Some(token) = token {
        builder = builder.header("authorization", format!("Bearer {token}"));
    }
    builder.body(Body::empty()).expect("build empty request")
}

/// response_json 读取 JSON 响应
/// 核心职责：
/// - 校验响应体可解析
/// - 为 HIS 合同测试提供统一断言入口
async fn response_json(response: axum::response::Response) -> Value {
    let bytes = to_bytes(response.into_body(), 1024 * 1024)
        .await
        .expect("read response body");
    serde_json::from_slice(&bytes).expect("parse response json")
}

/// login_user 使用真实验证码登录
/// 核心职责：
/// - 复用现有认证链路签发 access token
/// - 返回用户 ID 与 token 供 HIS 受保护接口测试
async fn login_user(
    app: &maohuoban_rust::test_support::AuthTestApp,
    phone: &str,
) -> (Uuid, String) {
    let send_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/auth/phone/code",
            json!({
                "phone": phone,
                "agreement_accepted": true,
                "device": {
                    "device_id": format!("web-his-contract-{phone}"),
                    "device_name": "Web HIS",
                    "platform": "Web",
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
                    "device_id": format!("web-his-contract-{phone}"),
                    "device_name": "Web HIS",
                    "platform": "Web",
                    "app_version": "1.0"
                }
            }),
            None,
        ))
        .await
        .expect("verify phone code");
    assert_eq!(verify_response.status(), StatusCode::OK);
    let verify_body = response_json(verify_response).await;
    let user_id = Uuid::parse_str(verify_body["data"]["user"]["id"].as_str().expect("user id"))
        .expect("user id uuid");
    let access_token = verify_body["data"]["access_token"]
        .as_str()
        .expect("access token")
        .to_owned();
    (user_id, access_token)
}

/// seed_his_context 写入 HIS 合同测试真实数据
/// 核心职责：
/// - 使用业务表准备医院租户、合作医院、员工和预约
/// - 避免依赖 Web HIS mock fixture 或迁移 seed
async fn seed_his_context(
    app: &maohuoban_rust::test_support::AuthTestApp,
    staff_user_id: Uuid,
    owner_user_id: Uuid,
) -> (Uuid, Uuid, Uuid, Uuid) {
    let tenant_id = Uuid::new_v4();
    let hospital_id = Uuid::new_v4();
    let pet_id = Uuid::new_v4();
    let appointment_id = Uuid::new_v4();

    sqlx::query(
        r#"
        INSERT INTO his_hospital_tenants (id, name, tenant_tier, status)
        VALUES ($1, '毛伙伴闭环验证医院', 'standard_saas', 'active')
        "#,
    )
    .bind(tenant_id)
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
            '毛伙伴闭环验证医院',
            '成都',
            '高新区',
            '成都市高新区天府大道中段 188 号',
            '028-88880088',
            ARRAY['异常接诊', '诊前资料包', '病历回流']::text[],
            'verified',
            'active',
            true,
            $2,
            true,
            true
        )
        "#,
    )
    .bind(hospital_id)
    .bind(tenant_id)
    .execute(app.pool())
    .await
    .expect("insert his hospital");

    sqlx::query(
        r#"
        INSERT INTO his_staff_members (id, tenant_id, user_id, display_name, role, status)
        VALUES ($1, $2, $3, '闭环验证医生', 'doctor', 'active')
        "#,
    )
    .bind(Uuid::new_v4())
    .bind(tenant_id)
    .bind(staff_user_id)
    .execute(app.pool())
    .await
    .expect("insert his staff");

    sqlx::query(
        r#"
        INSERT INTO pet_profiles (
            id,
            owner_user_id,
            name,
            species,
            breed,
            sex,
            birthday,
            profile_number,
            arrival_date,
            weight_grams
        )
        VALUES (
            $1,
            $2,
            '馒头',
            'cat',
            '英短',
            'male',
            '2024-05-01',
            '2026070700000001',
            '2024-08-01',
            4200
        )
        "#,
    )
    .bind(pet_id)
    .bind(owner_user_id)
    .execute(app.pool())
    .await
    .expect("insert pet");

    sqlx::query(
        r#"
        INSERT INTO samecity_hospital_appointments (
            id,
            owner_user_id,
            pet_id,
            hospital_id,
            scheduled_at,
            reason,
            note,
            status
        )
        VALUES (
            $1,
            $2,
            $3,
            $4,
            $5,
            '异常后就医',
            '从 App 预约合作医院',
            'pending'
        )
        "#,
    )
    .bind(appointment_id)
    .bind(owner_user_id)
    .bind(pet_id)
    .bind(hospital_id)
    .bind(Utc::now() + Duration::hours(2))
    .execute(app.pool())
    .await
    .expect("insert appointment");

    (tenant_id, hospital_id, pet_id, appointment_id)
}

#[tokio::test]
async fn his_session_and_dashboard_read_real_partner_hospital_data() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let (staff_user_id, staff_token) = login_user(&app, "13900000001").await;
    let (owner_user_id, _) = login_user(&app, "13800139001").await;
    let (tenant_id, hospital_id, pet_id, appointment_id) =
        seed_his_context(&app, staff_user_id, owner_user_id).await;

    let options_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            "/api/v1/his/session/context-options",
            Some(&staff_token),
        ))
        .await
        .expect("load his context options");
    assert_eq!(options_response.status(), StatusCode::OK);
    let options_body = response_json(options_response).await;
    assert_eq!(options_body["success"], true);
    assert_eq!(
        options_body["data"]["tenants"][0]["id"],
        tenant_id.to_string()
    );
    assert_eq!(
        options_body["data"]["sites"][0]["id"],
        hospital_id.to_string()
    );
    assert_eq!(options_body["data"]["members"][0]["name"], "闭环验证医生");

    let dashboard_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            "/api/v1/his/dashboard/today",
            Some(&staff_token),
        ))
        .await
        .expect("load his dashboard");
    assert_eq!(dashboard_response.status(), StatusCode::OK);
    let dashboard_body = response_json(dashboard_response).await;
    assert_eq!(dashboard_body["success"], true);
    assert_eq!(dashboard_body["data"]["summary"]["appointments"], 1);
    assert_eq!(
        dashboard_body["data"]["appointments"][0]["id"],
        appointment_id.to_string()
    );
    assert_eq!(
        dashboard_body["data"]["appointments"][0]["patientId"],
        pet_id.to_string()
    );
    assert_eq!(
        dashboard_body["data"]["appointments"][0]["patientName"],
        "馒头"
    );
    assert_eq!(
        dashboard_body["data"]["appointments"][0]["reason"],
        "异常后就医"
    );
}
