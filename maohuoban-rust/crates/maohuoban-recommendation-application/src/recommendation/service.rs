use std::sync::Arc;

use maohuoban_recommendation_domain::recommendation::{
    HomePartnerRecommendation, HomeRecommendedContent, RecommendationError, RecommendationResult,
};

use super::{HomeRecommendationContext, RecommendationRepository};

/// RecommendationService 推荐应用服务
/// 核心职责：
/// - 承接首页今日伙伴和空态内容推荐用例
/// - 隔离推荐策略和首页聚合编排
pub struct RecommendationService {
    repository: Arc<dyn RecommendationRepository>,
}

impl RecommendationService {
    #[must_use]
    pub fn new(repository: Arc<dyn RecommendationRepository>) -> Self {
        Self { repository }
    }

    pub async fn recommend_home_partner(
        &self,
        context: HomeRecommendationContext,
    ) -> RecommendationResult<Option<HomePartnerRecommendation>> {
        if let Some(city) = &context.city {
            validate_optional_text("城市", city)?;
        }
        self.repository.find_home_partner(&context).await
    }

    pub async fn list_empty_state_content(
        &self,
        city: Option<&str>,
        limit: i64,
    ) -> RecommendationResult<Vec<HomeRecommendedContent>> {
        if let Some(city) = city {
            validate_optional_text("城市", city)?;
        }
        if limit <= 0 {
            return Ok(Vec::new());
        }
        self.repository.list_empty_state_content(city, limit).await
    }
}

fn validate_optional_text(label: &str, value: &str) -> RecommendationResult<()> {
    if value.trim().is_empty() {
        return Err(RecommendationError::InvalidInput(format!(
            "{label}不能为空"
        )));
    }
    Ok(())
}
