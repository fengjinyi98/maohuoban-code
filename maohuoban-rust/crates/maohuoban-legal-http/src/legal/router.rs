use std::sync::Arc;

use axum::{
    Json, Router,
    extract::{Path, State},
    http::StatusCode,
    response::{IntoResponse, Response},
    routing::get,
};
use maohuoban_legal_application::legal::LegalDocumentService;
use maohuoban_legal_domain::legal::{LegalDocument, LegalError};
use serde::Serialize;
use serde_json::Value;

/// `LegalHttpState` 法务文档 HTTP 状态
/// 核心职责：
/// - 持有法务文档应用服务
/// - 作为 axum handler 的共享状态
#[derive(Clone)]
pub struct LegalHttpState {
    legal: Arc<LegalDocumentService>,
}

impl LegalHttpState {
    #[must_use]
    pub const fn new(legal: Arc<LegalDocumentService>) -> Self {
        Self { legal }
    }
}

/// `build_legal_router` 构建法务文档路由
/// 核心职责：
/// - 注册用户协议和隐私政策读取接口
/// - 将 HTTP 层限制在 DTO 和响应转换范围内
pub fn build_legal_router(legal: Arc<LegalDocumentService>) -> Router {
    Router::new()
        .route("/api/v1/legal-documents/{kind}", get(get_legal_document))
        .with_state(LegalHttpState::new(legal))
}

async fn get_legal_document(
    State(state): State<LegalHttpState>,
    Path(kind): Path<String>,
) -> Response {
    match state.legal.get_document(&kind).await {
        Ok(document) => ok_response(
            "legal.document_loaded",
            "文档已加载",
            LegalDocumentData::from(document),
        ),
        Err(error) => error_response(&error),
    }
}

fn ok_response<T>(code: &'static str, message: &'static str, data: T) -> Response
where
    T: Serialize,
{
    (
        StatusCode::OK,
        Json(ApiResponse {
            success: true,
            code,
            message: message.to_owned(),
            data: Some(data),
        }),
    )
        .into_response()
}

fn error_response(error: &LegalError) -> Response {
    let (status, code, message) = match error {
        LegalError::DocumentNotFound => (
            StatusCode::NOT_FOUND,
            "legal.document_not_found",
            "文档不存在".to_owned(),
        ),
        LegalError::Infrastructure(_) => (
            StatusCode::INTERNAL_SERVER_ERROR,
            "legal.internal_error",
            "文档暂时不可用，请稍后再试".to_owned(),
        ),
    };

    (
        status,
        Json(ApiResponse::<Value> {
            success: false,
            code,
            message,
            data: None,
        }),
    )
        .into_response()
}

/// `ApiResponse` 统一接口响应
/// 核心职责：
/// - 固定 success、code、message、data 格式
/// - 与认证接口保持一致的客户端契约
#[derive(Debug, Serialize)]
struct ApiResponse<T>
where
    T: Serialize,
{
    success: bool,
    code: &'static str,
    message: String,
    data: Option<T>,
}

/// `LegalDocumentData` 法务文档响应数据
/// 核心职责：
/// - 返回客户端 `WebView` 展示所需字段
/// - 隔离领域模型和 HTTP JSON 结构
#[derive(Debug, Serialize)]
struct LegalDocumentData {
    kind: &'static str,
    title: String,
    version: String,
    effective_date: String,
    published_at: String,
    updated_at: String,
    html: String,
}

impl From<LegalDocument> for LegalDocumentData {
    fn from(document: LegalDocument) -> Self {
        Self {
            kind: document.kind.as_str(),
            title: document.title,
            version: document.version,
            effective_date: document.effective_date.to_string(),
            published_at: document.published_at.to_rfc3339(),
            updated_at: document.updated_at.to_rfc3339(),
            html: document.html,
        }
    }
}
