use super::*;

/// `login_user_id` 使用真实验证码登录获取用户 id
/// 核心职责：
/// - 复用认证契约的开发验证码
/// - 为首页真实聚合提供当前用户上下文
pub(crate) async fn login_user_id(
    app: &maohuoban_rust::test_support::AuthTestApp,
    phone: &str,
) -> String {
    let send_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/auth/phone/code",
            json!({
                "phone": phone,
                "agreement_accepted": true,
                "device": {
                    "device_id": "ios-simulator-home-contract",
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
                    "device_id": "ios-simulator-home-contract",
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
    remember_access_token(user_id.clone(), access_token);
    user_id
}

/// `create_home_test_pet` 创建首页契约测试宠物
/// 核心职责：
/// - 复用标准宠物档案输入
/// - 返回后续事件和首页断言需要的宠物 ID
pub(crate) async fn create_home_test_pet(
    app: &maohuoban_rust::test_support::AuthTestApp,
    user_id: &str,
) -> String {
    create_named_home_test_pet(app, user_id, "糯米").await
}

/// `create_named_home_test_pet` 创建指定名称的测试宠物
/// 核心职责：
/// - 支持首页推荐契约区分当前宠物和伙伴宠物
/// - 复用标准宠物档案输入
pub(crate) async fn create_named_home_test_pet(
    app: &maohuoban_rust::test_support::AuthTestApp,
    user_id: &str,
    name: &str,
) -> String {
    let response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": name,
                "species": "dog",
                "breed": "比熊犬",
                "sex": "female",
                "birthday": "2024-04-01"
            }),
            Some(user_id),
        ))
        .await
        .expect("create pet");
    assert_eq!(response.status(), StatusCode::CREATED);
    let body = response_json(response).await;
    body["data"]["id"].as_str().expect("pet id").to_owned()
}

/// `append_home_test_event` 写入首页契约测试宠物事件
/// 核心职责：
/// - 固定事件写入请求路径
/// - 让首页派生测试聚焦响应契约
pub(crate) async fn append_home_test_event(
    app: &maohuoban_rust::test_support::AuthTestApp,
    user_id: &str,
    pet_id: &str,
    event: Value,
) {
    let response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/events"),
            event,
            Some(user_id),
        ))
        .await
        .expect("create pet event");
    assert_eq!(response.status(), StatusCode::CREATED);
}

/// `append_home_test_weight_record` 写入首页契约测试体重记录
/// 核心职责：
/// - 固定体重记录请求路径
/// - 让首页 state 卡片聚合测试复用真实 CRUD 接口
pub(crate) async fn append_home_test_weight_record(
    app: &maohuoban_rust::test_support::AuthTestApp,
    user_id: &str,
    pet_id: &str,
    weight_grams: i32,
    occurred_at: &str,
) {
    let response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/weight-records"),
            json!({
                "weight_grams": weight_grams,
                "occurred_at": occurred_at
            }),
            Some(user_id),
        ))
        .await
        .expect("create pet weight record");
    assert_eq!(response.status(), StatusCode::CREATED);
}

/// `load_home_test_weight_record_ids` 读取首页契约测试体重记录 ID
/// 核心职责：
/// - 复用真实体重记录列表接口
/// - 支持首页聚合测试删除初始体重记录
pub(crate) async fn load_home_test_weight_record_ids(
    app: &maohuoban_rust::test_support::AuthTestApp,
    user_id: &str,
    pet_id: &str,
) -> Vec<String> {
    let response = app
        .router()
        .oneshot(contextual_empty_request(
            "GET",
            &format!("/api/v1/pets/{pet_id}/weight-records"),
            Some(user_id),
        ))
        .await
        .expect("load pet weight records");
    assert_eq!(response.status(), StatusCode::OK);
    let body = response_json(response).await;
    body["data"]["items"]
        .as_array()
        .expect("weight record items")
        .iter()
        .map(|item| item["id"].as_str().expect("weight record id").to_owned())
        .collect()
}

/// `delete_home_test_weight_record` 删除首页契约测试体重记录
/// 核心职责：
/// - 复用真实体重记录删除接口
/// - 保持首页 state 卡片测试覆盖体重账本删除语义
pub(crate) async fn delete_home_test_weight_record(
    app: &maohuoban_rust::test_support::AuthTestApp,
    user_id: &str,
    record_id: &str,
) {
    let response = app
        .router()
        .oneshot(contextual_empty_request(
            "DELETE",
            &format!("/api/v1/pet-weight-records/{record_id}"),
            Some(user_id),
        ))
        .await
        .expect("delete pet weight record");
    assert_eq!(response.status(), StatusCode::OK);
}

/// `load_user_home_dashboard` 读取带用户上下文的首页快照
/// 核心职责：
/// - 固定首页读取请求
/// - 返回已解析 JSON 供契约断言
pub(crate) async fn load_user_home_dashboard(
    app: &maohuoban_rust::test_support::AuthTestApp,
    user_id: &str,
) -> Value {
    let response = app
        .router()
        .oneshot(contextual_empty_request(
            "GET",
            "/api/v1/home/dashboard",
            Some(user_id),
        ))
        .await
        .expect("load pet owner dashboard");
    assert_eq!(response.status(), StatusCode::OK);
    response_json(response).await
}

/// `load_user_home_dashboard_for_pet` 读取指定宠物上下文的首页快照
/// 核心职责：
/// - 固定多宠切换查询参数
/// - 验证首页聚合可按用户选择切换当前宠物
pub(crate) async fn load_user_home_dashboard_for_pet(
    app: &maohuoban_rust::test_support::AuthTestApp,
    user_id: &str,
    selected_pet_id: &str,
) -> Value {
    let response = app
        .router()
        .oneshot(contextual_empty_request(
            "GET",
            &format!("/api/v1/home/dashboard?selected_pet_id={selected_pet_id}"),
            Some(user_id),
        ))
        .await
        .expect("load selected pet dashboard");
    assert_eq!(response.status(), StatusCode::OK);
    response_json(response).await
}
