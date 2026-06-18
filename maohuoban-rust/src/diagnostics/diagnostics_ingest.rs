use std::{
    path::PathBuf,
    sync::{Arc, Mutex},
};

use axum::{
    Json, Router,
    body::Bytes,
    extract::State,
    http::{HeaderMap, StatusCode, header::CONTENT_TYPE},
    response::{IntoResponse, Response},
    routing::post,
};
use maohuoban_diagnostics::{
    CapturePolicy, DiagnosticEvent, EventStore, FileSegmentStore, PrivacyPolicy,
};
use serde::{Deserialize, Serialize};

use super::{DEFAULT_MAX_BODY_BYTES, backend_privacy_policy};

/// DiagnosticsIngestConfig 本地诊断回流配置
/// 核心职责：
/// - 描述 Debug ingest 的写入目录、鉴权 token 和 body 上限
/// - 让后端启动配置与 axum 路由装配保持解耦
#[derive(Clone, Debug)]
pub struct DiagnosticsIngestConfig {
    pub segments_directory: PathBuf,
    pub token: String,
    pub max_body_bytes: usize,
}

impl DiagnosticsIngestConfig {
    #[must_use]
    pub fn local(segments_directory: impl Into<PathBuf>, token: impl Into<String>) -> Self {
        Self {
            segments_directory: segments_directory.into(),
            token: token.into(),
            max_body_bytes: DEFAULT_MAX_BODY_BYTES,
        }
    }
}

#[derive(Clone)]
struct DiagnosticsIngestState {
    store: Arc<Mutex<FileSegmentStore>>,
    token: String,
    max_body_bytes: usize,
    privacy: PrivacyPolicy,
    capture: CapturePolicy,
}

#[derive(Deserialize)]
#[serde(untagged)]
enum DiagnosticsIngestPayload {
    Single(DiagnosticEvent),
    Batch(Vec<DiagnosticEvent>),
}

impl DiagnosticsIngestPayload {
    fn into_events(self) -> Vec<DiagnosticEvent> {
        match self {
            Self::Single(event) => vec![event],
            Self::Batch(events) => events,
        }
    }
}

#[derive(Serialize)]
struct DiagnosticsIngestResponse {
    ok: bool,
    accepted: usize,
    dropped: usize,
}

/// build_diagnostics_ingest_router 构建 Debug 诊断回流路由
/// 核心职责：
/// - 接收 iOS Debug mirror 回流事件
/// - 复用隐私与采集策略后写入 workspace segments
///
/// # Errors
///
/// 当段文件存储无法创建时返回错误。
pub fn build_diagnostics_ingest_router(
    config: DiagnosticsIngestConfig,
) -> Result<Router, maohuoban_diagnostics::DiagnosticsError> {
    let state = DiagnosticsIngestState {
        store: Arc::new(Mutex::new(FileSegmentStore::new(
            config.segments_directory,
            1024 * 1024,
        )?)),
        token: config.token,
        max_body_bytes: config.max_body_bytes,
        privacy: backend_privacy_policy(),
        capture: CapturePolicy::default(),
    };
    Ok(Router::new()
        .route(
            "/internal/diagnostics/ingest",
            post(handle_diagnostics_ingest),
        )
        .with_state(state))
}

async fn handle_diagnostics_ingest(
    State(state): State<DiagnosticsIngestState>,
    headers: HeaderMap,
    body: Bytes,
) -> Response {
    if !is_json_content_type(&headers) {
        return diagnostics_ingest_error(StatusCode::UNSUPPORTED_MEDIA_TYPE);
    }
    if !diagnostics_token_matches(&headers, &state.token) {
        return diagnostics_ingest_error(StatusCode::UNAUTHORIZED);
    }
    if body.len() > state.max_body_bytes {
        return diagnostics_ingest_error(StatusCode::PAYLOAD_TOO_LARGE);
    }

    let Ok(payload) = serde_json::from_slice::<DiagnosticsIngestPayload>(&body) else {
        return diagnostics_ingest_error(StatusCode::BAD_REQUEST);
    };
    let mut accepted = 0;
    let mut dropped = 0;
    let Ok(mut store) = state.store.lock() else {
        return diagnostics_ingest_error(StatusCode::INTERNAL_SERVER_ERROR);
    };
    for event in payload.into_events() {
        let Some(event) = state.capture.apply(&event) else {
            dropped += 1;
            continue;
        };
        let event = state.privacy.apply(&event);
        if store.append(&event).is_ok() {
            accepted += 1;
        } else {
            dropped += 1;
        }
    }
    (
        StatusCode::ACCEPTED,
        Json(DiagnosticsIngestResponse {
            ok: true,
            accepted,
            dropped,
        }),
    )
        .into_response()
}

fn diagnostics_ingest_error(status: StatusCode) -> Response {
    (
        status,
        Json(DiagnosticsIngestResponse {
            ok: false,
            accepted: 0,
            dropped: 0,
        }),
    )
        .into_response()
}

fn is_json_content_type(headers: &HeaderMap) -> bool {
    headers
        .get(CONTENT_TYPE)
        .and_then(|value| value.to_str().ok())
        .is_some_and(|value| {
            value.split(';').next().is_some_and(|content_type| {
                content_type.trim().eq_ignore_ascii_case("application/json")
            })
        })
}

fn diagnostics_token_matches(headers: &HeaderMap, token: &str) -> bool {
    headers
        .get("x-maohuoban-diagnostics-token")
        .and_then(|value| value.to_str().ok())
        .is_some_and(|value| value == token)
}
