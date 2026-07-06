use chrono::{Datelike, Utc};
use serde_json::{Value, json};
use sqlx::{PgPool, Row};
use uuid::Uuid;

use super::response::{HisError, to_infrastructure_error};

/// StaffContext HIS 员工上下文
/// 核心职责：
/// - 承载当前已登录员工的真实租户、院区和成员 JSON
/// - 为 Web HIS 所有受保护接口提供租户边界
#[derive(Debug, Clone)]
pub struct StaffContext {
    pub tenant_id: Uuid,
    pub tenant: Value,
    pub sites: Vec<Value>,
    pub member: Value,
    pub role: String,
}

/// load_staff_context 读取真实 HIS 员工上下文
/// 核心职责：
/// - 根据当前用户绑定 his_staff_members
/// - 只允许 active 员工进入 active HIS 租户
pub async fn load_staff_context(pool: &PgPool, user_id: Uuid) -> Result<StaffContext, HisError> {
    let row = sqlx::query(
        r#"
        SELECT
            s.id AS member_id,
            s.tenant_id,
            s.display_name,
            s.role,
            t.name AS tenant_name,
            t.tenant_tier,
            i.identifier AS account
        FROM his_staff_members s
        JOIN his_hospital_tenants t ON t.id = s.tenant_id
        JOIN user_identities i ON i.user_id = s.user_id AND i.provider = 'phone'
        WHERE s.user_id = $1
          AND s.status = 'active'
          AND t.status = 'active'
        ORDER BY s.created_at ASC
        LIMIT 1
        "#,
    )
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .map_err(to_infrastructure_error)?
    .ok_or(HisError::Forbidden)?;

    let tenant_id: Uuid = row.get("tenant_id");
    let sites = load_sites_for_tenant(pool, tenant_id).await?;
    if sites.is_empty() {
        return Err(HisError::Forbidden);
    }
    let site_ids: Vec<Value> = sites
        .iter()
        .filter_map(|site| site.get("id").cloned())
        .collect();
    let role = map_role(row.get::<String, _>("role").as_str()).to_owned();
    let tenant = json!({
        "id": tenant_id,
        "name": row.get::<String, _>("tenant_name"),
        "tier": row.get::<String, _>("tenant_tier")
    });
    let member = json!({
        "id": row.get::<Uuid, _>("member_id"),
        "tenantId": tenant_id,
        "siteIds": site_ids,
        "name": row.get::<String, _>("display_name"),
        "account": row.get::<String, _>("account"),
        "role": role,
        "enabled": true
    });
    Ok(StaffContext {
        tenant_id,
        tenant,
        sites,
        member,
        role,
    })
}

/// load_sites_for_tenant 读取 HIS 租户下真实合作医院院区
/// 核心职责：
/// - 将 samecity_hospitals 中接入 HIS 的合作医院投影为 Web HIS site
/// - 保证医院端上下文只来自真实合作医院
pub async fn load_sites_for_tenant(pool: &PgPool, tenant_id: Uuid) -> Result<Vec<Value>, HisError> {
    let rows = sqlx::query(
        r#"
        SELECT id, his_tenant_id AS tenant_id, name, city
        FROM samecity_hospitals
        WHERE his_tenant_id = $1
          AND partnership_status = 'active'
          AND his_enabled = true
          AND appointment_enabled = true
        ORDER BY name ASC
        "#,
    )
    .bind(tenant_id)
    .fetch_all(pool)
    .await
    .map_err(to_infrastructure_error)?;
    Ok(rows
        .into_iter()
        .map(|row| {
            json!({
                "id": row.get::<Uuid, _>("id"),
                "tenantId": row.get::<Uuid, _>("tenant_id"),
                "name": row.get::<String, _>("name"),
                "city": row.get::<String, _>("city")
            })
        })
        .collect())
}

/// load_appointments_for_tenant 读取 HIS 租户预约队列
/// 核心职责：
/// - 从 App 合作医院预约表读取医院端工作台队列
/// - 按 his_tenant_id 保证医院租户隔离
pub async fn load_appointments_for_tenant(
    pool: &PgPool,
    tenant_id: Uuid,
) -> Result<Vec<Value>, HisError> {
    let rows = sqlx::query(
        r#"
        SELECT
            a.id,
            a.pet_id,
            COALESCE(p.name, '未关联宠物') AS patient_name,
            COALESCE(up.display_name, ui.identifier, '宠物主') AS owner_name,
            a.scheduled_at,
            a.reason,
            a.status
        FROM samecity_hospital_appointments a
        JOIN samecity_hospitals h ON h.id = a.hospital_id
        LEFT JOIN pet_profiles p ON p.id = a.pet_id
        LEFT JOIN user_profiles up ON up.user_id = a.owner_user_id
        LEFT JOIN user_identities ui ON ui.user_id = a.owner_user_id AND ui.provider = 'phone'
        WHERE h.his_tenant_id = $1
          AND h.partnership_status = 'active'
          AND h.his_enabled = true
        ORDER BY a.scheduled_at ASC
        "#,
    )
    .bind(tenant_id)
    .fetch_all(pool)
    .await
    .map_err(to_infrastructure_error)?;
    Ok(rows
        .into_iter()
        .map(|row| {
            json!({
                "id": row.get::<Uuid, _>("id"),
                "patientId": row.get::<Option<Uuid>, _>("pet_id"),
                "patientName": row.get::<String, _>("patient_name"),
                "ownerName": row.get::<String, _>("owner_name"),
                "startsAt": format_time(row.get("scheduled_at")),
                "reason": row.get::<String, _>("reason"),
                "status": appointment_status(row.get::<String, _>("status").as_str())
            })
        })
        .collect())
}

/// load_patients_for_tenant 读取 HIS 租户患者列表
/// 核心职责：
/// - 从已预约到本 HIS 租户的宠物档案投影患者
/// - 支持患者列表关键词过滤
pub async fn load_patients_for_tenant(
    pool: &PgPool,
    tenant_id: Uuid,
    keyword: Option<&str>,
) -> Result<Vec<Value>, HisError> {
    let rows = sqlx::query(
        r#"
        SELECT DISTINCT
            p.id,
            p.profile_number,
            p.name,
            p.species,
            COALESCE(p.breed, '') AS breed,
            p.sex,
            p.birthday,
            p.weight_grams,
            p.owner_user_id,
            COALESCE(up.display_name, ui.identifier, '宠物主') AS owner_name,
            COALESCE(ui.identifier, '') AS owner_phone,
            p.note,
            MAX(a.scheduled_at) OVER (PARTITION BY p.id) AS last_visit_at
        FROM samecity_hospital_appointments a
        JOIN samecity_hospitals h ON h.id = a.hospital_id
        JOIN pet_profiles p ON p.id = a.pet_id
        LEFT JOIN user_profiles up ON up.user_id = p.owner_user_id
        LEFT JOIN user_identities ui ON ui.user_id = p.owner_user_id AND ui.provider = 'phone'
        WHERE h.his_tenant_id = $1
          AND h.partnership_status = 'active'
          AND h.his_enabled = true
          AND p.deleted_at IS NULL
          AND (
              $2::text IS NULL
              OR p.name ILIKE '%' || $2 || '%'
              OR COALESCE(up.display_name, '') ILIKE '%' || $2 || '%'
              OR COALESCE(ui.identifier, '') ILIKE '%' || $2 || '%'
              OR COALESCE(p.profile_number, '') ILIKE '%' || $2 || '%'
              OR COALESCE(p.breed, '') ILIKE '%' || $2 || '%'
          )
        ORDER BY last_visit_at DESC NULLS LAST, p.name ASC
        "#,
    )
    .bind(tenant_id)
    .bind(keyword.filter(|value| !value.trim().is_empty()))
    .fetch_all(pool)
    .await
    .map_err(to_infrastructure_error)?;
    Ok(rows.into_iter().map(patient_json).collect())
}

/// load_patient_detail 读取 HIS 患者详情
/// 核心职责：
/// - 复用患者列表投影并校验租户权限
/// - 暂以真实空接诊/收费集合替代 mock 明细
pub async fn load_patient_detail(
    pool: &PgPool,
    tenant_id: Uuid,
    patient_id: Uuid,
) -> Result<Value, HisError> {
    let patients = load_patients_for_tenant(pool, tenant_id, None).await?;
    let patient = patients
        .into_iter()
        .find(|patient| patient.get("id").and_then(Value::as_str) == Some(&patient_id.to_string()))
        .ok_or_else(|| HisError::NotFound("患者不存在".to_owned()))?;
    Ok(json!({
        "patient": patient,
        "encounters": [],
        "invoices": []
    }))
}

fn patient_json(row: sqlx::postgres::PgRow) -> Value {
    json!({
        "id": row.get::<Uuid, _>("id"),
        "medicalRecordNo": row.get::<String, _>("profile_number"),
        "name": row.get::<String, _>("name"),
        "species": species_label(row.get::<String, _>("species").as_str()),
        "breed": row.get::<String, _>("breed"),
        "ageText": age_text(row.get("birthday")),
        "sex": sex_label(row.get::<String, _>("sex").as_str()),
        "weightKg": row.get::<Option<i32>, _>("weight_grams").map_or(0.0, |grams| f64::from(grams) / 1000.0),
        "ownerId": row.get::<Option<Uuid>, _>("owner_user_id"),
        "ownerName": row.get::<String, _>("owner_name"),
        "ownerPhone": row.get::<String, _>("owner_phone"),
        "allergies": [],
        "chronicDiseases": [],
        "currentMedications": [],
        "lastVisitAt": row.get::<Option<chrono::DateTime<Utc>>, _>("last_visit_at").map_or_else(|| "暂无就诊".to_owned(), format_date_time),
        "notes": row.get::<Option<String>, _>("note").unwrap_or_default()
    })
}

fn map_role(value: &str) -> &'static str {
    match value {
        "admin" => "admin",
        "doctor" => "doctor",
        "front_desk" => "frontdesk",
        "nurse" => "assistant",
        _ => "assistant",
    }
}

fn species_label(value: &str) -> &'static str {
    match value {
        "cat" => "猫",
        "dog" => "狗",
        _ => "其他",
    }
}

fn sex_label(value: &str) -> &'static str {
    match value {
        "female" => "雌性",
        "male" => "雄性",
        _ => "未知",
    }
}

fn appointment_status(value: &str) -> &'static str {
    match value {
        "confirmed" => "arrived",
        "cancelled" => "cancelled",
        _ => "scheduled",
    }
}

fn age_text(birthday: Option<chrono::NaiveDate>) -> String {
    let Some(birthday) = birthday else {
        return "未知".to_owned();
    };
    let now = Utc::now().date_naive();
    let mut years = now.year() - birthday.year();
    if now.ordinal() < birthday.ordinal() {
        years -= 1;
    }
    if years > 0 {
        format!("{years}岁")
    } else {
        let months = ((now.year() - birthday.year()) * 12 + now.month() as i32
            - birthday.month() as i32)
            .max(0);
        format!("{months}个月")
    }
}

fn format_time(value: chrono::DateTime<Utc>) -> String {
    value.format("%H:%M").to_string()
}

fn format_date_time(value: chrono::DateTime<Utc>) -> String {
    value.format("%Y-%m-%d %H:%M").to_string()
}
