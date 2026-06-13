use axum::{
    body::{Body, to_bytes},
    http::{Request, StatusCode},
};
use serde_json::Value;
use tower::ServiceExt;

/// `get_request` 构造 GET HTTP 请求
/// 核心职责：
/// - 固定测试请求的 URI
/// - 生成可直接传入 axum router 的空 body 请求
fn get_request(uri: &str) -> Request<Body> {
    Request::builder()
        .method("GET")
        .uri(uri)
        .body(Body::empty())
        .expect("build get request")
}

/// `response_json` 读取 JSON 响应
/// 核心职责：
/// - 校验测试响应 body 可被解析为 JSON
/// - 为接口契约断言提供统一入口
async fn response_json(response: axum::response::Response) -> Value {
    let bytes = to_bytes(response.into_body(), 1024 * 1024)
        .await
        .expect("read response body");
    serde_json::from_slice(&bytes).expect("parse response json")
}

#[tokio::test]
async fn legal_documents_are_served_as_backend_managed_html() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;

    let user_agreement_response = app
        .router()
        .oneshot(get_request("/api/v1/legal-documents/user_agreement"))
        .await
        .expect("fetch user agreement");
    assert_eq!(user_agreement_response.status(), StatusCode::OK);

    let user_agreement_body = response_json(user_agreement_response).await;
    assert_eq!(user_agreement_body["success"], true);
    assert_eq!(user_agreement_body["code"], "legal.document_loaded");
    assert_eq!(user_agreement_body["message"], "文档已加载");
    assert_eq!(user_agreement_body["data"]["kind"], "user_agreement");
    assert_eq!(user_agreement_body["data"]["title"], "用户服务协议");
    assert_eq!(user_agreement_body["data"]["version"], "2026-06-13");
    assert!(
        user_agreement_body["data"]["html"]
            .as_str()
            .expect("user agreement html")
            .contains("宠物主体协同服务规则")
    );

    let privacy_response = app
        .router()
        .oneshot(get_request("/api/v1/legal-documents/privacy_policy"))
        .await
        .expect("fetch privacy policy");
    assert_eq!(privacy_response.status(), StatusCode::OK);

    let privacy_body = response_json(privacy_response).await;
    assert_eq!(privacy_body["success"], true);
    assert_eq!(privacy_body["data"]["kind"], "privacy_policy");
    assert_eq!(privacy_body["data"]["title"], "用户隐私政策");
    assert_eq!(privacy_body["data"]["version"], "2026-06-13");
    assert!(
        privacy_body["data"]["html"]
            .as_str()
            .expect("privacy policy html")
            .contains("医疗与保险理赔数据特别声明")
    );
}

#[tokio::test]
async fn unknown_legal_document_kind_returns_not_found() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;

    let response = app
        .router()
        .oneshot(get_request("/api/v1/legal-documents/deprecated_terms"))
        .await
        .expect("fetch unknown legal document");
    assert_eq!(response.status(), StatusCode::NOT_FOUND);

    let body = response_json(response).await;
    assert_eq!(body["success"], false);
    assert_eq!(body["code"], "legal.document_not_found");
    assert_eq!(body["message"], "文档不存在");
}
