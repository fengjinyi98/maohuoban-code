use async_trait::async_trait;
use maohuoban_recommendation_domain::recommendation::{
    HomePartnerRecommendation, HomeRecommendedContent, RecommendationResult,
};
use uuid::Uuid;

/// HomeRecommendationContext 首页推荐上下文
/// 核心职责：
/// - 汇总当前用户、当前宠物和城市上下文
/// - 让推荐策略不依赖首页聚合实现细节
#[derive(Debug, Clone)]
pub struct HomeRecommendationContext {
    pub user_id: Uuid,
    pub selected_pet_id: Uuid,
    pub city: Option<String>,
}

/// RecommendationRepository 推荐仓储端口
/// 核心职责：
/// - 读取可解释宠物关系推荐
/// - 读取新用户空态辅助内容
#[async_trait]
pub trait RecommendationRepository: Send + Sync {
    async fn find_home_partner(
        &self,
        context: &HomeRecommendationContext,
    ) -> RecommendationResult<Option<HomePartnerRecommendation>>;

    async fn list_empty_state_content(
        &self,
        city: Option<&str>,
        limit: i64,
    ) -> RecommendationResult<Vec<HomeRecommendedContent>>;
}
