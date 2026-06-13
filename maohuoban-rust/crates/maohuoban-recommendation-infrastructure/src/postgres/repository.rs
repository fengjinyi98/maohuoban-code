use async_trait::async_trait;
use maohuoban_recommendation_application::recommendation::{
    HomeRecommendationContext, RecommendationRepository,
};
use maohuoban_recommendation_domain::recommendation::{
    HomePartnerRecommendation, HomeRecommendedContent, HomeRecommendedContentKind,
    HomeRelationshipKind, RecommendationError, RecommendationResult,
};
use sqlx::{FromRow, PgPool};
use uuid::Uuid;

/// PostgresRecommendationRepository PostgreSQL 推荐仓储
/// 核心职责：
/// - 读取可解释宠物关系和公开事件
/// - 为首页今日伙伴和新用户空态提供推荐数据
#[derive(Debug, Clone)]
pub struct PostgresRecommendationRepository {
    pool: PgPool,
}

impl PostgresRecommendationRepository {
    #[must_use]
    pub const fn new(pool: PgPool) -> Self {
        Self { pool }
    }
}

#[async_trait]
impl RecommendationRepository for PostgresRecommendationRepository {
    async fn find_home_partner(
        &self,
        context: &HomeRecommendationContext,
    ) -> RecommendationResult<Option<HomePartnerRecommendation>> {
        if let Some(relationship) = find_relationship_partner(&self.pool, context).await? {
            return Ok(Some(relationship));
        }

        find_public_event_partner(&self.pool, context).await
    }

    async fn list_empty_state_content(
        &self,
        _city: Option<&str>,
        limit: i64,
    ) -> RecommendationResult<Vec<HomeRecommendedContent>> {
        let rows = sqlx::query_as::<_, PublicEventContentRow>(
            r#"
            SELECT
                event.id AS event_id,
                event.title,
                pet.name AS pet_name
            FROM pet_events event
            JOIN pet_profiles pet ON pet.id = event.pet_id
            WHERE event.visibility = 'public'
            ORDER BY event.occurred_at DESC, event.created_at DESC
            LIMIT $1
            "#,
        )
        .bind(limit)
        .fetch_all(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        Ok(rows
            .into_iter()
            .map(|row| HomeRecommendedContent {
                id: row.event_id,
                kind: HomeRecommendedContentKind::Ugc,
                title: row.title,
                source_text: format!("{} · 宠物世界", row.pet_name),
            })
            .collect())
    }
}

/// find_relationship_partner 读取显式关系伙伴
/// 核心职责：
/// - 优先使用同窝、同来源等可信关系边
/// - 排除当前用户自己的宠物
async fn find_relationship_partner(
    pool: &PgPool,
    context: &HomeRecommendationContext,
) -> RecommendationResult<Option<HomePartnerRecommendation>> {
    let row = sqlx::query_as::<_, RelationshipPartnerRow>(
        r#"
        SELECT
            related.id AS pet_id,
            related.name AS pet_name,
            relation.relationship_kind
        FROM pet_relationships relation
        JOIN pet_profiles related ON related.id = relation.related_pet_id
        WHERE relation.subject_pet_id = $1
          AND relation.related_pet_id IS NOT NULL
          AND (
              related.owner_user_id IS NULL
              OR related.owner_user_id <> $2
          )
        ORDER BY relation.created_at DESC
        LIMIT 1
        "#,
    )
    .bind(context.selected_pet_id)
    .bind(context.user_id)
    .fetch_optional(pool)
    .await
    .map_err(to_infrastructure_error)?;

    Ok(row.map(|row| {
        let relationship_kind = relationship_kind_from_pet_relation(&row.relationship_kind);
        HomePartnerRecommendation {
            pet_id: row.pet_id,
            pet_name: row.pet_name,
            relationship_kind,
            title: "今日伙伴".to_owned(),
            subtitle: partner_subtitle(relationship_kind),
            distance_text: relationship_distance_text(relationship_kind, context.city.as_deref()),
        }
    }))
}

/// find_public_event_partner 读取公开事件伙伴
/// 核心职责：
/// - 在没有显式关系时提供宠物世界关系入口
/// - 只使用公开事件避免泄露私密记录
async fn find_public_event_partner(
    pool: &PgPool,
    context: &HomeRecommendationContext,
) -> RecommendationResult<Option<HomePartnerRecommendation>> {
    let row = sqlx::query_as::<_, PublicEventPartnerRow>(
        r#"
        SELECT
            pet.id AS pet_id,
            pet.name AS pet_name,
            event.title AS event_title
        FROM pet_events event
        JOIN pet_profiles pet ON pet.id = event.pet_id
        WHERE event.visibility = 'public'
          AND pet.id <> $1
          AND (
              pet.owner_user_id IS NULL
              OR pet.owner_user_id <> $2
          )
        ORDER BY event.occurred_at DESC, event.created_at DESC
        LIMIT 1
        "#,
    )
    .bind(context.selected_pet_id)
    .bind(context.user_id)
    .fetch_optional(pool)
    .await
    .map_err(to_infrastructure_error)?;

    Ok(row.map(|row| HomePartnerRecommendation {
        pet_id: row.pet_id,
        pet_name: row.pet_name,
        relationship_kind: HomeRelationshipKind::SameCity,
        title: "今日伙伴".to_owned(),
        subtitle: format!("宠物世界里有一条新动态：{}", row.event_title),
        distance_text: context.city.as_deref().map_or_else(
            || Some("宠物世界".to_owned()),
            |city| Some(format!("{city} · 公开动态")),
        ),
    }))
}

#[derive(Debug, FromRow)]
struct RelationshipPartnerRow {
    pet_id: Uuid,
    pet_name: String,
    relationship_kind: String,
}

#[derive(Debug, FromRow)]
struct PublicEventPartnerRow {
    pet_id: Uuid,
    pet_name: String,
    event_title: String,
}

#[derive(Debug, FromRow)]
struct PublicEventContentRow {
    event_id: Uuid,
    title: String,
    pet_name: String,
}

fn relationship_kind_from_pet_relation(value: &str) -> HomeRelationshipKind {
    match value {
        "same_litter" => HomeRelationshipKind::SameLitter,
        "same_source" | "merchant_managed" | "transferred_from" => HomeRelationshipKind::SameSource,
        _ => HomeRelationshipKind::SameCity,
    }
}

fn partner_subtitle(kind: HomeRelationshipKind) -> String {
    match kind {
        HomeRelationshipKind::SameLitter => "找到一只可追溯的同窝伙伴".to_owned(),
        HomeRelationshipKind::SameSource => "你们有相近的来源关系".to_owned(),
        HomeRelationshipKind::SameCondition => "有相似健康记录的伙伴正在更新动态".to_owned(),
        HomeRelationshipKind::SameHospital => "有同医院就诊经历的伙伴正在更新动态".to_owned(),
        HomeRelationshipKind::SameCity => "同城有一只毛孩子也在形成可信档案".to_owned(),
    }
}

fn relationship_distance_text(kind: HomeRelationshipKind, city: Option<&str>) -> Option<String> {
    match kind {
        HomeRelationshipKind::SameLitter => Some("同窝关系".to_owned()),
        HomeRelationshipKind::SameSource => Some("同来源关系".to_owned()),
        HomeRelationshipKind::SameCondition => Some("相似健康记录".to_owned()),
        HomeRelationshipKind::SameHospital => Some("同医院关系".to_owned()),
        HomeRelationshipKind::SameCity => city.map(|city| format!("{city} · 同城")),
    }
}

fn to_infrastructure_error(error: sqlx::Error) -> RecommendationError {
    RecommendationError::Infrastructure(error.to_string())
}
