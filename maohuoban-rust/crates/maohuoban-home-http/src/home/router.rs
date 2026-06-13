use std::sync::Arc;

use axum::{
    Json, Router,
    extract::State,
    http::StatusCode,
    response::{IntoResponse, Response},
    routing::get,
};
use maohuoban_home_application::home::{HomeDashboardService, HomeError};
use maohuoban_home_domain::home::HomeDashboardSnapshot;
use serde::Serialize;
use serde_json::Value;

/// HomeHttpState 首页 HTTP 状态
/// 核心职责：
/// - 持有首页聚合应用服务
/// - 作为 axum handler 的共享状态
#[derive(Clone)]
pub struct HomeHttpState {
    home: Arc<HomeDashboardService>,
}

impl HomeHttpState {
    #[must_use]
    pub const fn new(home: Arc<HomeDashboardService>) -> Self {
        Self { home }
    }
}

/// build_home_router 构建首页路由
/// 核心职责：
/// - 注册首页聚合快照接口
/// - 将 HTTP 层限制在统一响应和 DTO 转换范围内
#[must_use]
pub fn build_home_router(home: Arc<HomeDashboardService>) -> Router {
    Router::new()
        .route("/api/v1/home/dashboard", get(get_home_dashboard))
        .with_state(HomeHttpState::new(home))
}

async fn get_home_dashboard(State(state): State<HomeHttpState>) -> Response {
    match state.home.get_dashboard_snapshot().await {
        Ok(snapshot) => ok_response(
            "home.dashboard_loaded",
            "首页已加载",
            HomeDashboardData::from(snapshot),
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

fn error_response(error: &HomeError) -> Response {
    let (status, code, message) = match error {
        HomeError::Infrastructure(_) => (
            StatusCode::INTERNAL_SERVER_ERROR,
            "home.internal_error",
            "首页暂时不可用，请稍后再试".to_owned(),
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

/// ApiResponse 统一接口响应
/// 核心职责：
/// - 固定 success、code、message、data 格式
/// - 与认证和法务接口保持一致的客户端契约
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

/// HomeDashboardData 首页快照响应数据
/// 核心职责：
/// - 返回客户端首页渲染所需聚合数据
/// - 隔离领域模型和 HTTP JSON 结构
#[derive(Debug, Serialize)]
struct HomeDashboardData {
    #[serde(flatten)]
    snapshot: HomeDashboardSnapshot,
}

impl From<HomeDashboardSnapshot> for HomeDashboardData {
    fn from(snapshot: HomeDashboardSnapshot) -> Self {
        Self { snapshot }
    }
}
