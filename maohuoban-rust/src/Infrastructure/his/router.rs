use axum::{
    Json, Router,
    extract::{Path, Query, State},
    response::Response,
    routing::{get, post},
};
use maohuoban_auth_http::auth::extractor::AuthenticatedUser;
use serde::Deserialize;
use serde_json::json;
use sqlx::PgPool;
use uuid::Uuid;

use super::{
    queries::{
        load_appointments_for_tenant, load_patient_detail, load_patients_for_tenant,
        load_staff_context,
    },
    response::{HisError, error_response, ok_response},
};

/// build_his_router 构建 Web HIS 真实数据路由
/// 核心职责：
/// - 使用已鉴权用户解析 HIS 员工与租户上下文
/// - 从真实业务表投影医院工作台、患者和空业务板块
pub fn build_his_router(pool: PgPool) -> Router {
    Router::new()
        .route("/api/v1/his/session/context-options", get(context_options))
        .route("/api/v1/his/session/context", post(select_context))
        .route("/api/v1/his/dashboard/today", get(today_dashboard))
        .route(
            "/api/v1/his/patients",
            get(list_patients).post(create_patient),
        )
        .route("/api/v1/his/patients/{patient_id}", get(patient_detail))
        .route("/api/v1/his/encounters", get(list_encounters))
        .route("/api/v1/his/encounters/{encounter_id}", get(get_encounter))
        .route(
            "/api/v1/his/encounters/{encounter_id}/start",
            post(start_encounter),
        )
        .route(
            "/api/v1/his/encounters/{encounter_id}/save",
            post(save_encounter),
        )
        .route("/api/v1/his/invoices", get(list_invoices))
        .route("/api/v1/his/invoices/{invoice_id}/pay", post(pay_invoice))
        .route(
            "/api/v1/his/invoices/{invoice_id}/refund",
            post(refund_invoice),
        )
        .route("/api/v1/his/pharmacy", get(pharmacy_board))
        .route(
            "/api/v1/his/pharmacy/{encounter_id}/dispense",
            post(dispense_encounter),
        )
        .route(
            "/api/v1/his/health-record-publications",
            get(list_publications),
        )
        .route(
            "/api/v1/his/health-record-publications/{publication_id}/{action}",
            post(update_publication),
        )
        .route("/api/v1/his/audit-logs", get(audit_logs))
        .route("/api/v1/his/settings", get(settings_board))
        .with_state(HisHttpState { pool })
}

#[derive(Clone)]
struct HisHttpState {
    pool: PgPool,
}

async fn context_options(State(state): State<HisHttpState>, actor: AuthenticatedUser) -> Response {
    let context = match load_staff_context(&state.pool, actor.user_id()).await {
        Ok(context) => context,
        Err(error) => return error_response(error),
    };
    ok_response(
        "his.context_options_loaded",
        "医院上下文已加载",
        json!({
            "tenants": [context.tenant],
            "sites": context.sites,
            "members": [context.member]
        }),
    )
}

async fn select_context(
    State(state): State<HisHttpState>,
    actor: AuthenticatedUser,
    Json(request): Json<SelectContextRequest>,
) -> Response {
    let context = match load_staff_context(&state.pool, actor.user_id()).await {
        Ok(context) => context,
        Err(error) => return error_response(error),
    };
    if request.tenant_id != context.tenant_id
        || !context.sites.iter().any(|site| {
            site.get("id").and_then(serde_json::Value::as_str) == Some(&request.site_id.to_string())
        })
    {
        return error_response(HisError::Forbidden);
    }
    let site = context.sites.into_iter().find(|site| {
        site.get("id").and_then(serde_json::Value::as_str) == Some(&request.site_id.to_string())
    });
    ok_response(
        "his.context_selected",
        "医院工作上下文已选择",
        json!({
            "member": context.member,
            "tenant": context.tenant,
            "site": site,
            "role": request.role.unwrap_or(context.role),
            "accessToken": serde_json::Value::Null,
            "refreshToken": serde_json::Value::Null
        }),
    )
}

async fn today_dashboard(State(state): State<HisHttpState>, actor: AuthenticatedUser) -> Response {
    let context = match load_staff_context(&state.pool, actor.user_id()).await {
        Ok(context) => context,
        Err(error) => return error_response(error),
    };
    let appointments = match load_appointments_for_tenant(&state.pool, context.tenant_id).await {
        Ok(appointments) => appointments,
        Err(error) => return error_response(error),
    };
    ok_response(
        "his.dashboard_loaded",
        "今日工作台已加载",
        json!({
            "summary": {
                "appointments": appointments.len(),
                "pendingEncounter": 0,
                "pendingBilling": 0,
                "pendingDispense": 0,
                "pendingPublication": 0
            },
            "appointments": appointments,
            "encounters": [],
            "invoices": [],
            "inventoryRisks": [],
            "publications": []
        }),
    )
}

async fn list_patients(
    State(state): State<HisHttpState>,
    actor: AuthenticatedUser,
    Query(query): Query<PatientsQuery>,
) -> Response {
    let context = match load_staff_context(&state.pool, actor.user_id()).await {
        Ok(context) => context,
        Err(error) => return error_response(error),
    };
    match load_patients_for_tenant(&state.pool, context.tenant_id, query.keyword.as_deref()).await {
        Ok(patients) => ok_response("his.patients_loaded", "患者已加载", patients),
        Err(error) => error_response(error),
    }
}

async fn patient_detail(
    State(state): State<HisHttpState>,
    actor: AuthenticatedUser,
    Path(patient_id): Path<Uuid>,
) -> Response {
    let context = match load_staff_context(&state.pool, actor.user_id()).await {
        Ok(context) => context,
        Err(error) => return error_response(error),
    };
    match load_patient_detail(&state.pool, context.tenant_id, patient_id).await {
        Ok(detail) => ok_response("his.patient_detail_loaded", "患者详情已加载", detail),
        Err(error) => error_response(error),
    }
}

async fn create_patient() -> Response {
    error_response(HisError::Conflict(
        "患者创建尚未接入 HIS 真实写入".to_owned(),
    ))
}

async fn list_encounters(State(state): State<HisHttpState>, actor: AuthenticatedUser) -> Response {
    match load_staff_context(&state.pool, actor.user_id()).await {
        Ok(_) => ok_response("his.encounters_loaded", "接诊记录已加载", json!([])),
        Err(error) => error_response(error),
    }
}

async fn get_encounter(
    State(state): State<HisHttpState>,
    actor: AuthenticatedUser,
    Path(_encounter_id): Path<Uuid>,
) -> Response {
    match load_staff_context(&state.pool, actor.user_id()).await {
        Ok(_) => error_response(HisError::NotFound("就诊不存在".to_owned())),
        Err(error) => error_response(error),
    }
}

async fn start_encounter() -> Response {
    error_response(HisError::Conflict("接诊写入尚未接入 HIS 真实表".to_owned()))
}

async fn save_encounter() -> Response {
    error_response(HisError::Conflict("病历保存尚未接入 HIS 真实表".to_owned()))
}

async fn list_invoices(State(state): State<HisHttpState>, actor: AuthenticatedUser) -> Response {
    match load_staff_context(&state.pool, actor.user_id()).await {
        Ok(_) => ok_response("his.invoices_loaded", "收费单已加载", json!([])),
        Err(error) => error_response(error),
    }
}

async fn pay_invoice() -> Response {
    error_response(HisError::NotFound("收费单不存在".to_owned()))
}

async fn refund_invoice() -> Response {
    error_response(HisError::NotFound("收费单不存在".to_owned()))
}

async fn pharmacy_board(State(state): State<HisHttpState>, actor: AuthenticatedUser) -> Response {
    match load_staff_context(&state.pool, actor.user_id()).await {
        Ok(_) => ok_response(
            "his.pharmacy_loaded",
            "药房任务已加载",
            json!({"dispensing": [], "inventory": []}),
        ),
        Err(error) => error_response(error),
    }
}

async fn dispense_encounter() -> Response {
    error_response(HisError::NotFound("发药任务不存在".to_owned()))
}

async fn list_publications(
    State(state): State<HisHttpState>,
    actor: AuthenticatedUser,
) -> Response {
    match load_staff_context(&state.pool, actor.user_id()).await {
        Ok(_) => ok_response(
            "his.publications_loaded",
            "健康档案发布队列已加载",
            json!([]),
        ),
        Err(error) => error_response(error),
    }
}

async fn update_publication() -> Response {
    error_response(HisError::NotFound("健康档案不存在".to_owned()))
}

async fn audit_logs(
    State(state): State<HisHttpState>,
    actor: AuthenticatedUser,
    Query(query): Query<AuditQuery>,
) -> Response {
    let _filter = (query.keyword.as_deref(), query.action.as_deref());
    match load_staff_context(&state.pool, actor.user_id()).await {
        Ok(_) => ok_response(
            "his.audit_logs_loaded",
            "审计记录已加载",
            json!({"logs": [], "consents": []}),
        ),
        Err(error) => error_response(error),
    }
}

async fn settings_board(State(state): State<HisHttpState>, actor: AuthenticatedUser) -> Response {
    let context = match load_staff_context(&state.pool, actor.user_id()).await {
        Ok(context) => context,
        Err(error) => return error_response(error),
    };
    ok_response(
        "his.settings_loaded",
        "系统设置已加载",
        json!({
            "members": [context.member],
            "sites": context.sites,
            "inventory": [],
            "roles": ["admin", "doctor", "frontdesk"]
        }),
    )
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct SelectContextRequest {
    tenant_id: Uuid,
    site_id: Uuid,
    role: Option<String>,
}

#[derive(Debug, Deserialize)]
struct PatientsQuery {
    keyword: Option<String>,
}

#[derive(Debug, Deserialize)]
struct AuditQuery {
    keyword: Option<String>,
    action: Option<String>,
}
