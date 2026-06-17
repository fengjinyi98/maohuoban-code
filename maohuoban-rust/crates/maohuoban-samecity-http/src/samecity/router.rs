use std::sync::Arc;

use axum::{
    Json, Router,
    extract::{Query, State},
    http::HeaderMap,
    response::Response,
    routing::{get, post},
};
use maohuoban_samecity_application::samecity::SameCityService;
use uuid::Uuid;

use super::{
    dto::{BookHospitalAppointmentRequest, HospitalAppointmentData, HospitalsData, HospitalsQuery},
    response::{created_response, error_response, ok_response, unauthorized_response},
};

/// SameCityHttpState 同城 HTTP 状态
/// 核心职责：
/// - 持有同城应用服务
/// - 作为 axum handler 的共享状态
#[derive(Clone)]
pub struct SameCityHttpState {
    samecity: Arc<SameCityService>,
}

impl SameCityHttpState {
    #[must_use]
    pub const fn new(samecity: Arc<SameCityService>) -> Self {
        Self { samecity }
    }
}

/// build_samecity_router 构建同城路由
/// 核心职责：
/// - 注册同城医院列表和医院预约接口
/// - 将 HTTP 层限制在 DTO、用户上下文和响应转换范围内
pub fn build_samecity_router(samecity: Arc<SameCityService>) -> Router {
    Router::new()
        .route("/api/v1/same-city/hospitals", get(list_hospitals))
        .route(
            "/api/v1/same-city/hospital-appointments",
            post(create_hospital_appointment),
        )
        .with_state(SameCityHttpState::new(samecity))
}

async fn list_hospitals(
    State(state): State<SameCityHttpState>,
    headers: HeaderMap,
    Query(query): Query<HospitalsQuery>,
) -> Response {
    let Ok(_) = current_user_id(&headers) else {
        return unauthorized_response();
    };

    match state.samecity.list_verified_hospitals(&query.city).await {
        Ok(hospitals) => ok_response(
            "samecity.hospitals_loaded",
            "同城医院已加载",
            HospitalsData::new(query.city, hospitals),
        ),
        Err(error) => error_response(&error),
    }
}

async fn create_hospital_appointment(
    State(state): State<SameCityHttpState>,
    headers: HeaderMap,
    Json(request): Json<BookHospitalAppointmentRequest>,
) -> Response {
    let Ok(owner_user_id) = current_user_id(&headers) else {
        return unauthorized_response();
    };

    let input = request.into_input(owner_user_id);
    match state.samecity.create_hospital_appointment(input).await {
        Ok(appointment) => created_response(
            "samecity.hospital_appointment_created",
            "医院预约已提交",
            HospitalAppointmentData::from(appointment),
        ),
        Err(error) => error_response(&error),
    }
}

fn current_user_id(headers: &HeaderMap) -> Result<Uuid, ()> {
    headers
        .get("x-maohuoban-user-id")
        .and_then(|value| value.to_str().ok())
        .and_then(|value| Uuid::parse_str(value).ok())
        .ok_or(())
}
