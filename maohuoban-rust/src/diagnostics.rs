use std::{
    path::PathBuf,
    sync::{Arc, Mutex},
    time::{Duration, Instant},
};

use axum::{
    Json, Router,
    body::Bytes,
    extract::{MatchedPath, Request, State},
    http::{HeaderMap, HeaderValue, StatusCode, header::CONTENT_TYPE},
    middleware::Next,
    response::{IntoResponse, Response},
    routing::post,
};
use maohuoban_diagnostics::{
    CapturePolicy, CleanupPolicy, DiagnosticEvent, Diagnostics, DiagnosticsBootstrapConfig,
    EventStore, FileSegmentStore, NetworkSummary, PrivacyPolicy, TraceContext,
};
use serde::{Deserialize, Serialize};
use serde_json::json;

const DEFAULT_INGEST_TOKEN: &str = "maohuoban-local-diagnostics";
const DEFAULT_MAX_BODY_BYTES: usize = 256 * 1024;
const DEFAULT_CLEANUP_MAX_TOTAL_BYTES: u64 = 10 * 1024 * 1024;
const DEFAULT_CLEANUP_MAX_SEGMENT_AGE_HOURS: u64 = 24;
const DEFAULT_CLEANUP_MAX_EXPORT_AGE_HOURS: u64 = 6;
const DEFAULT_CLEANUP_INTERVAL_MINS: u64 = 30;

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

/// backend_diagnostics_bootstrap_config 构建后端 SDK 启动配置
/// 核心职责：
/// - 读取本地环境变量覆盖项
/// - 默认写入 workspace `.maohuoban-diagnostics/segments`
#[must_use]
pub fn backend_diagnostics_bootstrap_config() -> DiagnosticsBootstrapConfig {
    let segments_directory = diagnostics_segments_directory_from_env();
    let mut config = DiagnosticsBootstrapConfig::new("maohuoban-rust", "local", segments_directory);
    config.privacy = backend_privacy_policy();
    config.capture.max_message_length = 16 * 1024;
    config.capture.max_metadata_value_length = 1024;
    config.cleanup = cleanup_policy_from_env();
    config
}

/// cleanup_policy_from_env 读取本地诊断清理策略
/// 核心职责：
/// - 为 LLM 排障保留较短的默认事件窗口
/// - 支持本地环境变量临时放宽或收紧清理阈值
#[must_use]
pub fn cleanup_policy_from_env() -> CleanupPolicy {
    cleanup_policy_from_env_values(
        std::env::var("MAOHUOBAN_DIAGNOSTICS_MAX_TOTAL_BYTES")
            .ok()
            .as_deref(),
        std::env::var("MAOHUOBAN_DIAGNOSTICS_MAX_SEGMENT_AGE_HOURS")
            .ok()
            .as_deref(),
        std::env::var("MAOHUOBAN_DIAGNOSTICS_MAX_EXPORT_AGE_HOURS")
            .ok()
            .as_deref(),
    )
}

/// cleanup_policy_from_env_values 从环境变量值构造清理策略
/// 核心职责：
/// - 固化本地开发默认保留窗口
/// - 让测试不需要修改真实进程环境
#[must_use]
pub fn cleanup_policy_from_env_values(
    max_total_bytes: Option<&str>,
    max_segment_age_hours: Option<&str>,
    max_export_age_hours: Option<&str>,
) -> CleanupPolicy {
    CleanupPolicy {
        max_total_bytes: parse_u64_or(max_total_bytes, DEFAULT_CLEANUP_MAX_TOTAL_BYTES),
        max_segment_age: Duration::from_hours(parse_u64_or(
            max_segment_age_hours,
            DEFAULT_CLEANUP_MAX_SEGMENT_AGE_HOURS,
        )),
        max_export_age: Duration::from_hours(parse_u64_or(
            max_export_age_hours,
            DEFAULT_CLEANUP_MAX_EXPORT_AGE_HOURS,
        )),
    }
}

/// cleanup_interval_from_env 读取周期清理间隔
/// 核心职责：
/// - 控制长时间开发时的 segments 后台收敛频率
/// - 保留环境变量覆盖入口
#[must_use]
pub fn cleanup_interval_from_env() -> Duration {
    cleanup_interval_from_env_value(
        std::env::var("MAOHUOBAN_DIAGNOSTICS_CLEANUP_INTERVAL_MINS")
            .ok()
            .as_deref(),
    )
}

/// cleanup_interval_from_env_value 从环境变量值读取周期清理间隔
/// 核心职责：
/// - 提供测试友好的纯函数入口
/// - 避免非法值关闭默认清理
#[must_use]
pub fn cleanup_interval_from_env_value(value: Option<&str>) -> Duration {
    Duration::from_mins(parse_u64_or(value, DEFAULT_CLEANUP_INTERVAL_MINS).max(1))
}

fn parse_u64_or(value: Option<&str>, fallback: u64) -> u64 {
    value
        .and_then(|value| value.parse().ok())
        .unwrap_or(fallback)
}

/// diagnostics_segments_directory_from_env 读取诊断段文件目录
/// 核心职责：
/// - 支持环境变量覆盖 workspace segments 位置
/// - 为后端 SDK 和 Debug ingest 使用同一默认目录
#[must_use]
pub fn diagnostics_segments_directory_from_env() -> PathBuf {
    std::env::var("MAOHUOBAN_DIAGNOSTICS_SEGMENTS_DIR").map_or_else(
        |_| PathBuf::from(".maohuoban-diagnostics/segments"),
        PathBuf::from,
    )
}

/// diagnostics_ingest_config_from_env 读取 Debug ingest 配置
/// 核心职责：
/// - 支持本地环境变量开启和鉴权 token 覆盖
/// - 约束真机回流写入 workspace 段文件
#[must_use]
pub fn diagnostics_ingest_config_from_env() -> DiagnosticsIngestConfig {
    DiagnosticsIngestConfig {
        segments_directory: diagnostics_segments_directory_from_env(),
        token: std::env::var("MAOHUOBAN_DIAGNOSTICS_INGEST_TOKEN")
            .unwrap_or_else(|_| DEFAULT_INGEST_TOKEN.to_owned()),
        max_body_bytes: std::env::var("MAOHUOBAN_DIAGNOSTICS_INGEST_MAX_BODY_BYTES")
            .ok()
            .and_then(|value| value.parse().ok())
            .unwrap_or(DEFAULT_MAX_BODY_BYTES),
    }
}

fn backend_privacy_policy() -> PrivacyPolicy {
    PrivacyPolicy::default()
        .redact_key("authorization")
        .redact_key("password")
        .redact_key("token")
        .redact_key("cookie")
        .redact_query_item("token")
        .redact_query_item("access_token")
}

/// record_http_network 记录后端 HTTP 网络摘要
/// 核心职责：
/// - 在 axum 入口统一捕获请求方法、路径、状态码和耗时
/// - 保留授权上下文是否存在，避免记录 token 和查询参数明文
pub async fn record_http_network(request: Request, next: Next) -> Response {
    let method = request.method().as_str().to_owned();
    let path = request.uri().path().to_owned();
    let path_template = request.extensions().get::<MatchedPath>().map_or_else(
        || path.clone(),
        |matched_path| matched_path.as_str().to_owned(),
    );
    let query_count = request.uri().query().map_or(0, |query| {
        query.split('&').filter(|item| !item.is_empty()).count()
    });
    let has_authorization = has_authorization_header(request.headers());
    let trace_context = request
        .headers()
        .get("traceparent")
        .and_then(|value| value.to_str().ok())
        .and_then(TraceContext::parse_traceparent)
        .unwrap_or_else(|| TraceContext::generate(true));
    let traceparent = trace_context.traceparent();
    let request_id = request
        .headers()
        .get("x-request-id")
        .and_then(|value| value.to_str().ok())
        .map_or_else(|| uuid::Uuid::new_v4().to_string(), ToOwned::to_owned);
    let started_at = Instant::now();
    let mut response = next.run(request).await;
    let status = response.status().as_u16();
    insert_response_header(response.headers_mut(), "traceparent", &traceparent);
    insert_response_header(response.headers_mut(), "x-request-id", &request_id);
    if let Some(diagnostics) = Diagnostics::current() {
        let mut summary = NetworkSummary::new(method, path)
            .status_code(status)
            .duration_ms(started_at.elapsed().as_millis())
            .trace_context(trace_context)
            .metadata("path_template", json!(path_template))
            .metadata("request_id", json!(request_id))
            .metadata("query_count", json!(query_count))
            .metadata("has_authorization", json!(has_authorization));
        if status >= 500 {
            summary = summary.metadata("response_error_kind", json!("server"));
        } else if status >= 400 {
            summary = summary.metadata("response_error_kind", json!("client"));
        }
        diagnostics.network(summary);
    }
    response
}

fn insert_response_header(headers: &mut HeaderMap, name: &'static str, value: &str) {
    if let Ok(value) = HeaderValue::from_str(value) {
        headers.insert(name, value);
    }
}

fn has_authorization_header(headers: &HeaderMap) -> bool {
    headers
        .get("authorization")
        .and_then(|value| value.to_str().ok())
        .is_some_and(|value| value.starts_with("Bearer ") && value.len() > "Bearer ".len())
}
