use axum::http::StatusCode;
use axum::{body::Body, http::Request};
use base64::{Engine as _, engine::general_purpose::STANDARD};
use maohuoban_diagnostics::{
    CapturePolicy, CleanupPolicy, Diagnostics, DiagnosticsConfig, FileSegmentStore, PrivacyPolicy,
};
use serde_json::{Value, json};
use tower::ServiceExt;

use crate::{
    authorized_get_request, authorized_json_request, authorized_multipart_media_request,
    response_json, response_text,
};

/// `unauthorized_ai_sessions_request` 构造未认证历史列表请求
/// 核心职责：
/// - 固定未登录列表接口合同测试的 GET 请求
pub fn unauthorized_ai_sessions_request() -> Request<Body> {
    Request::builder()
        .method("GET")
        .uri("/api/v1/ai/chat-sessions")
        .body(Body::empty())
        .expect("build request")
}

/// `unauthorized_session_messages_request` 构造未认证历史消息请求
/// 核心职责：
/// - 固定未登录消息接口合同测试的 GET 请求
pub fn unauthorized_session_messages_request(session_id: uuid::Uuid) -> Request<Body> {
    Request::builder()
        .method("GET")
        .uri(format!("/api/v1/ai/chat-sessions/{session_id}/messages"))
        .body(Body::empty())
        .expect("build request")
}

/// `upload_pending_avatar` 上传待绑定宠物头像
/// 核心职责：
/// - 为 AI 历史契约创建真实媒体资产
/// - 返回可绑定到宠物档案的 asset id
pub async fn upload_pending_avatar(
    app: &maohuoban_rust::test_support::AuthTestApp,
    access_token: &str,
) -> String {
    let avatar_bytes = STANDARD
        .decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC")
        .expect("avatar png bytes");
    let response = app
        .router()
        .clone()
        .oneshot(authorized_multipart_media_request(
            "/api/v1/pet-media/avatar",
            "ai-history-avatar.png",
            "image/png",
            &avatar_bytes,
            "ios",
            access_token,
        ))
        .await
        .expect("upload pending avatar");

    assert_eq!(response.status(), StatusCode::CREATED);
    let body = response_json(response).await;
    body["data"]["asset"]["id"]
        .as_str()
        .expect("avatar asset id")
        .to_owned()
}

/// `create_pet_with_avatar` 创建带头像的宠物档案
/// 核心职责：
/// - 复用真实宠物创建接口绑定头像资产
/// - 返回后续 AI 会话使用的宠物档案数据
pub async fn create_pet_with_avatar(
    app: &maohuoban_rust::test_support::AuthTestApp,
    access_token: &str,
    name: &str,
    avatar_asset_id: &str,
) -> Value {
    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/pets",
            access_token,
            json!({
                "name": name,
                "species": "cat",
                "breed": "英短",
                "sex": "male",
                "birthday": "2024-01-01",
                "arrival_date": "2024-03-01",
                "avatar_asset_id": avatar_asset_id
            }),
        ))
        .await
        .expect("create pet with avatar");

    let status = response.status();
    let body = response_json(response).await;
    assert_eq!(status, StatusCode::CREATED, "create pet body: {body}");
    body["data"].clone()
}

/// `create_chat_session` 通过真实聊天流创建 AI 会话
/// 核心职责：
/// - 复用当前历史契约的会话创建路径
/// - 返回最新会话 ID 供后续会话操作接口测试
pub async fn create_chat_session(
    app: &maohuoban_rust::test_support::AuthTestApp,
    access_token: &str,
    message: &str,
) -> String {
    let response = app
        .router()
        .clone()
        .oneshot(authorized_json_request(
            "POST",
            "/api/v1/ai/chat/stream",
            access_token,
            json!({
                "message": message,
                "surface": "home_private"
            }),
        ))
        .await
        .expect("send chat stream");
    assert_eq!(response.status(), StatusCode::OK);
    let _ = response_text(response).await;

    let body = list_chat_sessions(app, access_token).await;
    body["data"][0]["id"]
        .as_str()
        .expect("session id")
        .to_owned()
}

/// `list_chat_sessions` 读取当前用户 AI 历史列表
/// 核心职责：
/// - 固定历史契约测试的列表请求
/// - 返回完整 JSON 方便测试断言排序和字段
pub async fn list_chat_sessions(
    app: &maohuoban_rust::test_support::AuthTestApp,
    access_token: &str,
) -> Value {
    let response = app
        .router()
        .clone()
        .oneshot(authorized_get_request(
            "/api/v1/ai/chat-sessions",
            access_token,
        ))
        .await
        .expect("get sessions");

    assert_eq!(response.status(), StatusCode::OK);
    response_json(response).await
}

/// `get_session_messages` 读取指定 AI 会话消息
/// 核心职责：
/// - 固定历史契约测试的消息详情请求
/// - 返回完整 JSON 供不同测试断言消息内容
pub async fn get_session_messages(
    app: &maohuoban_rust::test_support::AuthTestApp,
    access_token: &str,
    session_id: &str,
) -> Value {
    let response = app
        .router()
        .clone()
        .oneshot(authorized_get_request(
            &format!("/api/v1/ai/chat-sessions/{session_id}/messages"),
            access_token,
        ))
        .await
        .expect("get messages");

    assert_eq!(response.status(), StatusCode::OK);
    response_json(response).await
}

/// `current_user_id` 读取测试登录用户 ID
/// 核心职责：
/// - 让历史契约测试可直接插入归属当前用户的会话 fixture
pub async fn current_user_id(pool: &sqlx::PgPool, phone: &str) -> uuid::Uuid {
    sqlx::query_scalar::<_, uuid::Uuid>(
        r"
        SELECT user_id
        FROM user_identities
        WHERE provider = 'phone' AND identifier = $1
        ",
    )
    .bind(phone)
    .fetch_one(pool)
    .await
    .expect("read current user id")
}

/// `insert_persisted_content_blocks_fixture` 写入历史消息内容块夹具
/// 核心职责：
/// - 创建归属当前用户的 AI 会话
/// - 写入带 `pet_profile_card` 的 assistant 消息用于回放验证
pub async fn insert_persisted_content_blocks_fixture(
    pool: &sqlx::PgPool,
    actor_user_id: uuid::Uuid,
    session_id: uuid::Uuid,
    message_id: uuid::Uuid,
) {
    sqlx::query(
        r"
        INSERT INTO ai_chat_sessions
            (id, actor_user_id, surface, title, status, created_at, updated_at)
        VALUES ($1, $2, 'home_private', '宠物信息', 'active', now(), now())
        ",
    )
    .bind(session_id)
    .bind(actor_user_id)
    .execute(pool)
    .await
    .expect("insert session fixture");

    sqlx::query(
        r"
        INSERT INTO ai_messages
            (id, session_id, role, content, status, citations, content_blocks, created_at)
        VALUES ($1, $2, 'assistant', '这是梅录的宠物信息', 'completed', '[]'::jsonb, $3, now())
        ",
    )
    .bind(message_id)
    .bind(session_id)
    .bind(json!([
        {
            "type": "section_heading",
            "id": "pet-profile-heading",
            "text": "这是梅录的宠物信息"
        },
        {
            "type": "pet_profile_card",
            "id": "pet-profile-card",
            "pet": {
                "id": "pet-1",
                "name": "梅录",
                "species": "cat",
                "species_text": "猫",
                "sex": "female",
                "sex_text": "母猫",
                "breed": "英短",
                "avatar_url": null,
                "birth_date": "2024-06-17",
                "arrival_date": "2025-06-17"
            },
            "computed": {
                "age_text": "当前年龄约 2岁15天",
                "companionship_text": "到家陪伴 380 天"
            },
            "narrative": {
                "birth": "梅录在 2024-06-17 来到这个世界。",
                "arrival": "2025-06-17 是梅录到家的日子。"
            }
        }
    ]))
    .execute(pool)
    .await
    .expect("insert message fixture");
}

/// `install_ai_history_test_diagnostics` 安装 AI 历史测试诊断运行时
/// 核心职责：
/// - 为单个历史合同测试创建隔离的诊断存储目录
/// - 固定测试诊断运行时的服务名、环境和隐私策略
pub fn install_ai_history_test_diagnostics() -> Diagnostics {
    let root = std::env::temp_dir().join(format!(
        "maohuoban-ai-history-diagnostics-{}",
        uuid::Uuid::new_v4()
    ));
    let store = FileSegmentStore::new(root.join("segments"), 1024 * 1024).expect("store");
    Diagnostics::install(DiagnosticsConfig {
        service_name: "maohuoban-rust".to_owned(),
        environment: "test".to_owned(),
        privacy: PrivacyPolicy::default(),
        capture: CapturePolicy::default(),
        cleanup: CleanupPolicy::default(),
        store: Box::new(store),
    })
    .expect("install diagnostics")
}
