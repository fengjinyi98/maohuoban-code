use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// HomePartnerRecommendation 首页今日伙伴推荐
/// 核心职责：
/// - 表达一条可解释的宠物关系推荐
/// - 为首页和后续宠物世界共用推荐语义
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct HomePartnerRecommendation {
    pub pet_id: Uuid,
    pub pet_name: String,
    pub relationship_kind: HomeRelationshipKind,
    pub title: String,
    pub subtitle: String,
    pub distance_text: Option<String>,
}

/// HomeRelationshipKind 首页关系推荐类型
/// 核心职责：
/// - 固定首页可解释关系标签
/// - 保持推荐策略和首页展示解耦
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum HomeRelationshipKind {
    SameLitter,
    SameCity,
    SameCondition,
    SameHospital,
    SameSource,
}

/// HomeRecommendedContent 首页辅助推荐内容
/// 核心职责：
/// - 为新用户空态提供补充内容
/// - 保持首页主操作仍指向创建宠物档案
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct HomeRecommendedContent {
    pub id: Uuid,
    pub kind: HomeRecommendedContentKind,
    pub title: String,
    pub source_text: String,
}

/// HomeRecommendedContentKind 首页辅助内容类型
/// 核心职责：
/// - 固定新用户空态可展示内容来源
/// - 支持 UGC、指南和本地服务渐进扩展
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum HomeRecommendedContentKind {
    Ugc,
    Guide,
    LocalService,
}
