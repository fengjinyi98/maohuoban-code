mod diagnostics;
mod merchant_summary;
mod pet_summary;
mod recommendation_summary;

use std::{
    collections::{HashMap, HashSet},
    sync::Arc,
};

use crate::home_dashboard::{
    diagnostics::{
        record_home_empty_state, record_home_media_metadata, record_home_pet_list,
        record_home_selected_pet_output,
    },
    merchant_summary::merchant_home_snapshot_from_workspace,
    pet_summary::{
        HomeWeightProjection, home_pet_stats, home_weight_projection, media_asset_ids,
        pet_hero_summary, pet_switch_item, selected_pet,
    },
    recommendation_summary::{partner_recommendation_summary, recommended_content_summary},
};
use crate::home_event_projection::{reminders_from_events, timeline_entry_summary};
use maohuoban_home_application::home::{
    HomeDashboardContext, HomeDashboardProvider, HomeError, HomeResult, new_user_home_snapshot,
    pet_owner_home_template,
};
use maohuoban_home_domain::home::{
    AttentionHint, AttentionHintCreator, AttentionHintKind, AttentionHintRoute,
    AttentionHintRouteKind, AttentionHintStatus, AttentionHintTone, HomeDashboardSnapshot,
    HomeDietTrendAnalysis, HomeDietTrendCalibration, HomeDietTrendConfidence,
    HomeDietTrendExplanation, HomeDietTrendHealthContext, HomeDietTrendSegment,
    HomeDietTrendSummary, HomeGalleryAlbumSummary, HomeIdentity, HomeIdentityKind,
    HomePantryPreviewItem, HomeTimelineEvent,
};
use maohuoban_pet_application::pet::{MediaAssetDisplayMetadata, PetService};
use maohuoban_pet_domain::pet::{
    FoodInventoryCategory, FoodInventoryItem, FoodScopeType, PetError, PetProfile, PetTimeline,
};
use maohuoban_recommendation_application::recommendation::{
    HomeRecommendationContext, RecommendationService,
};
use tokio::sync::RwLock;
use uuid::Uuid;

const FOOD_INVENTORY_LOW_REMAINING_SCORE_RATIO: f64 = 0.2;

/// `InMemoryHomeDashboardProvider` 内存首页快照提供器
/// 核心职责：
/// - 为开发和契约测试提供可替换首页快照
/// - 保持首页应用服务依赖端口而非具体数据库实现
#[derive(Clone)]
pub struct InMemoryHomeDashboardProvider {
    snapshot: Arc<RwLock<HomeDashboardSnapshot>>,
}

impl InMemoryHomeDashboardProvider {
    #[must_use]
    pub fn new(snapshot: HomeDashboardSnapshot) -> Self {
        Self {
            snapshot: Arc::new(RwLock::new(snapshot)),
        }
    }

    /// `replace_snapshot` 替换首页快照
    /// 核心职责：
    /// - 为测试和开发种子切换首页形态
    /// - 通过写锁保证读取和替换的一致性
    pub async fn replace_snapshot(&self, snapshot: HomeDashboardSnapshot) {
        *self.snapshot.write().await = snapshot;
    }
}

#[async_trait::async_trait]
impl HomeDashboardProvider for InMemoryHomeDashboardProvider {
    async fn get_dashboard_snapshot(
        &self,
        _context: HomeDashboardContext,
    ) -> HomeResult<HomeDashboardSnapshot> {
        Ok(self.snapshot.read().await.clone())
    }
}

/// `HybridHomeDashboardProvider` 混合首页快照提供器
/// 核心职责：
/// - 无用户上下文时返回真实空态快照
/// - 有用户上下文时读取宠物档案、商家窝次和事件生成真实首页聚合
#[derive(Clone)]
pub struct HybridHomeDashboardProvider {
    fallback: InMemoryHomeDashboardProvider,
    pet_service: Arc<PetService>,
    recommendation_service: Arc<RecommendationService>,
}

impl HybridHomeDashboardProvider {
    #[must_use]
    pub fn new(
        fallback: InMemoryHomeDashboardProvider,
        pet_service: Arc<PetService>,
        recommendation_service: Arc<RecommendationService>,
    ) -> Self {
        Self {
            fallback,
            pet_service,
            recommendation_service,
        }
    }

    /// `replace_snapshot` 替换无上下文首页快照
    /// 核心职责：
    /// - 支持首页契约测试切换内存快照
    /// - 不影响带用户上下文的真实聚合路径
    pub async fn replace_snapshot(&self, snapshot: HomeDashboardSnapshot) {
        self.fallback.replace_snapshot(snapshot).await;
    }

    async fn snapshot_for_user(
        &self,
        user_id: Uuid,
        selected_pet_id: Option<Uuid>,
    ) -> HomeResult<HomeDashboardSnapshot> {
        if let Some(merchant_dashboard) = self
            .pet_service
            .load_merchant_dashboard(user_id)
            .await
            .map_err(|error| to_home_error(&error))?
        {
            return Ok(merchant_home_snapshot_from_workspace(&merchant_dashboard));
        }

        let pets = self
            .pet_service
            .list_pet_profiles(user_id)
            .await
            .map_err(|error| to_home_error(&error))?;
        record_home_pet_list(user_id, selected_pet_id, pets.len());
        let Some(selected_pet) = selected_pet(&pets, selected_pet_id) else {
            return Ok(self.empty_state_snapshot(user_id).await);
        };
        let media_metadata = self
            .pet_service
            .list_media_display_metadata(&media_asset_ids(&pets))
            .await
            .map_err(|error| to_home_error(&error))?
            .into_iter()
            .map(|metadata| (metadata.asset_id, metadata))
            .collect::<HashMap<_, _>>();
        record_home_media_metadata(user_id, selected_pet, pets.len(), &media_metadata);

        let timeline = self
            .pet_service
            .load_pet_timeline(user_id, selected_pet.id)
            .await
            .map_err(|error| to_home_error(&error))?;
        let food_inventory_items = self
            .pet_service
            .list_food_inventory_items(FoodScopeType::User, user_id, None, None)
            .await
            .map_err(|error| to_home_error(&error))?;
        let diet_role_labels = self
            .pet_service
            .load_pet_current_diet_context(user_id, selected_pet.id)
            .await
            .map(diet_role_labels)
            .map_err(|error| to_home_error(&error))?;
        let mut snapshot = pet_owner_snapshot_base(
            user_id,
            &pets,
            selected_pet,
            &media_metadata,
            &timeline,
            &food_inventory_items,
            &diet_role_labels,
        );
        snapshot.gallery_albums = self
            .gallery_album_summaries(user_id, selected_pet.id)
            .await?;
        let mut stored_attention_hints = self
            .pet_service
            .load_attention_hints(selected_pet.id)
            .await
            .map_err(|error| to_home_error(&error))?
            .into_iter()
            .filter_map(|value| serde_json::from_value(value).ok())
            .collect();
        snapshot.attention_hints.append(&mut stored_attention_hints);
        snapshot.attention_hints.sort_by(|left, right| {
            right
                .priority
                .cmp(&left.priority)
                .then_with(|| right.created_at.cmp(&left.created_at))
        });
        snapshot.partner_recommendation = self
            .recommendation_service
            .recommend_home_partner(HomeRecommendationContext {
                user_id,
                selected_pet_id: selected_pet.id,
                city: snapshot.identity.city.clone(),
            })
            .await
            .unwrap_or_default()
            .map(partner_recommendation_summary);
        snapshot.diet_trend_summary = Some(
            self.pet_service
                .load_pet_diet_trend_summary(user_id, selected_pet.id)
                .await
                .map_err(|error| to_home_error(&error))
                .map(home_diet_trend_summary)?,
        );
        snapshot.merchant_dashboard = None;
        snapshot.empty_state = None;
        snapshot.recommended_content = Vec::new();
        Ok(snapshot)
    }

    /// `empty_state_snapshot` 生成首页空态快照
    /// 核心职责：
    /// - 复用新用户首页模板和空态推荐内容
    /// - 记录用户无宠物档案时的首页诊断事件
    async fn empty_state_snapshot(&self, user_id: Uuid) -> HomeDashboardSnapshot {
        let mut snapshot = new_user_home_snapshot();
        let contents = self
            .recommendation_service
            .list_empty_state_content(snapshot.identity.city.as_deref(), 3)
            .await
            .unwrap_or_default();
        if !contents.is_empty() {
            snapshot.recommended_content = contents
                .into_iter()
                .map(recommended_content_summary)
                .collect();
        }
        record_home_empty_state(user_id);
        snapshot
    }

    async fn gallery_album_summaries(
        &self,
        user_id: Uuid,
        pet_id: Uuid,
    ) -> HomeResult<Vec<HomeGalleryAlbumSummary>> {
        self.pet_service
            .list_home_gallery_album_summaries(pet_id, user_id, 4)
            .await
            .map_err(|error| to_home_error(&error))
            .map(|summaries| summaries.into_iter().map(gallery_album_summary).collect())
    }
}

#[async_trait::async_trait]
impl HomeDashboardProvider for HybridHomeDashboardProvider {
    async fn get_dashboard_snapshot(
        &self,
        context: HomeDashboardContext,
    ) -> HomeResult<HomeDashboardSnapshot> {
        if let Some(user_id) = context.user_id {
            return self
                .snapshot_for_user(user_id, context.selected_pet_id)
                .await;
        }
        self.fallback.get_dashboard_snapshot(context).await
    }
}

/// `pet_owner_snapshot_base` 生成宠物主首页基础快照
/// 核心职责：
/// - 组装仅依赖已加载数据的首页基础区块
/// - 保持异步读取职责留在 provider 入口
fn pet_owner_snapshot_base(
    user_id: Uuid,
    pets: &[PetProfile],
    selected_pet: &PetProfile,
    media_metadata: &HashMap<Uuid, MediaAssetDisplayMetadata>,
    timeline: &PetTimeline,
    food_inventory_items: &[FoodInventoryItem],
    diet_role_labels: &HashMap<Uuid, String>,
) -> HomeDashboardSnapshot {
    let weight_projection = home_weight_projection(&timeline.events);
    let mut snapshot = pet_owner_home_template();
    snapshot.identity = HomeIdentity {
        kind: HomeIdentityKind::PetOwner,
        display_name: "毛伙伴用户".to_owned(),
        city: None,
        verification_badge: None,
    };
    let selected_summary = pet_hero_summary(
        selected_pet,
        media_metadata,
        home_pet_stats(weight_projection, food_inventory_items),
        weight_projection.map(HomeWeightProjection::latest_weight_grams),
    );
    record_home_selected_pet_output(
        user_id,
        selected_pet,
        &selected_summary,
        pets.len(),
        media_metadata,
    );
    snapshot.selected_pet = Some(selected_summary);
    snapshot.pet_switcher = pets
        .iter()
        .map(|pet| pet_switch_item(pet, pet.id == selected_pet.id, media_metadata))
        .collect();
    snapshot.recent_timeline = recent_home_timeline(&timeline.entries);
    snapshot.reminders = reminders_from_events(&timeline.events);
    snapshot.attention_hints =
        food_inventory_attention_hints(selected_pet.id, &timeline.events, food_inventory_items);
    snapshot.pantry_items =
        home_pantry_preview_items(food_inventory_items.to_vec(), diet_role_labels);
    snapshot.merchant_dashboard = None;
    snapshot.empty_state = None;
    snapshot.recommended_content = Vec::new();
    snapshot
}

/// `recent_home_timeline` 生成首页最近时间线摘要
/// 核心职责：
/// - 从统一宠物时间线条目中截取首页摘要
/// - 保持首页和完整记录列表共享同一事实来源
fn recent_home_timeline(
    entries: &[maohuoban_pet_domain::pet::PetTimelineEntry],
) -> Vec<HomeTimelineEvent> {
    entries
        .iter()
        .take(4)
        .map(timeline_entry_summary)
        .collect::<Vec<_>>()
}

/// `food_inventory_attention_hints` 生成库存消耗轻提示
/// 核心职责：
/// - 基于当前宠物喂食事件和库存规格估算物品是否接近吃完
/// - 输出首页 `attention_hints`，不直接修改库存事实
fn food_inventory_attention_hints(
    pet_id: Uuid,
    events: &[maohuoban_pet_domain::pet::PetEvent],
    food_inventory_items: &[FoodInventoryItem],
) -> Vec<AttentionHint> {
    let items_by_id = food_inventory_items
        .iter()
        .map(|item| (item.id, item))
        .collect::<HashMap<_, _>>();
    let mut scores_by_item_id: HashMap<Uuid, f64> = HashMap::new();

    for event in events {
        if event.event_subkind.as_deref() != Some("feeding") {
            continue;
        }
        let Some(food_item_id) = event
            .event_payload
            .get("food_item_id")
            .and_then(|value| value.as_str())
            .and_then(|value| Uuid::parse_str(value).ok())
        else {
            continue;
        };
        let amount_text = event
            .event_payload
            .get("amount_text")
            .and_then(|value| value.as_str())
            .unwrap_or("正常");
        *scores_by_item_id.entry(food_item_id).or_insert(0.0) += feeding_amount_score(amount_text);
    }

    scores_by_item_id
        .into_iter()
        .filter_map(|(item_id, score)| {
            let item = *items_by_id.get(&item_id)?;
            food_inventory_attention_hint_for_item(pet_id, item, score)
        })
        .collect()
}

fn food_inventory_attention_hint_for_item(
    pet_id: Uuid,
    item: &FoodInventoryItem,
    score: f64,
) -> Option<AttentionHint> {
    if item.quantity <= 0
        || item.package_weight_grams.is_none()
        || !item.category.is_diet_context_eligible()
    {
        return None;
    }
    if item.category == FoodInventoryCategory::WetFood {
        return None;
    }

    let package_score_capacity = estimated_package_score_capacity(item.category);
    let total_score_capacity = package_score_capacity * f64::from(item.quantity);
    if total_score_capacity <= 0.0 {
        return None;
    }
    let remaining_ratio = ((total_score_capacity - score) / total_score_capacity).clamp(0.0, 1.0);
    if remaining_ratio > FOOD_INVENTORY_LOW_REMAINING_SCORE_RATIO {
        return None;
    }

    let now = chrono::Utc::now();
    Some(AttentionHint {
        id: Uuid::new_v4(),
        pet_id,
        kind: AttentionHintKind::FeedingPatternChanged,
        title: format!("{}可能快吃完了", item.name),
        subtitle: "确认后会更新库存和饮食趋势".to_owned(),
        icon: "takeoutbag.and.cup.and.straw.fill".to_owned(),
        tone: AttentionHintTone::Notice,
        priority: 40,
        status: AttentionHintStatus::Active,
        source_ref_type: Some("food_inventory_item".to_owned()),
        source_ref_id: Some(item.id),
        route: AttentionHintRoute {
            kind: AttentionHintRouteKind::PantryItemDetail,
            payload: Some(serde_json::json!({ "food_item_id": item.id })),
        },
        display_from: None,
        display_until: None,
        created_by: AttentionHintCreator::BusinessRule,
        created_at: now,
        updated_at: now,
        resolved_at: None,
    })
}

fn estimated_package_score_capacity(category: FoodInventoryCategory) -> f64 {
    match category {
        FoodInventoryCategory::MainFood => 60.0,
        FoodInventoryCategory::Treats => 24.0,
        FoodInventoryCategory::Nutrition | FoodInventoryCategory::Other => 30.0,
        FoodInventoryCategory::WetFood
        | FoodInventoryCategory::CatLitter
        | FoodInventoryCategory::Medicine => 0.0,
    }
}

fn feeding_amount_score(amount_text: &str) -> f64 {
    match amount_text.trim() {
        "少一点" => 0.75,
        "多一点" => 1.25,
        _ => 1.0,
    }
}

fn to_home_error(error: &PetError) -> HomeError {
    HomeError::Infrastructure(error.to_string())
}

fn pantry_preview_item(
    item: FoodInventoryItem,
    diet_role_labels: &HashMap<Uuid, String>,
) -> HomePantryPreviewItem {
    let diet_role_label = diet_role_labels.get(&item.id).cloned();
    HomePantryPreviewItem {
        id: item.id.to_string(),
        title: item.name,
        subtitle: pantry_category_title(item.category).to_owned(),
        category: item.category.as_str().to_owned(),
        cover_url: item.cover_url,
        diet_role_label,
    }
}

fn home_pantry_preview_items(
    items: Vec<FoodInventoryItem>,
    diet_role_labels: &HashMap<Uuid, String>,
) -> Vec<HomePantryPreviewItem> {
    items
        .into_iter()
        .filter({
            let mut seen_categories = HashSet::new();
            move |item| seen_categories.insert(item.category.as_str())
        })
        .take(4)
        .map(|item| pantry_preview_item(item, diet_role_labels))
        .collect()
}

fn diet_role_labels(
    context: maohuoban_pet_application::pet::PetCurrentDietContext,
) -> HashMap<Uuid, String> {
    let mut labels = HashMap::new();
    if let Some(current_staple) = context.current_staple {
        labels.insert(current_staple.food_item_id, "当前主粮".to_owned());
    }
    for item in context.trying_foods {
        labels.insert(item.food_item_id, "尝试中".to_owned());
    }
    for item in context.usual_treats {
        labels.insert(item.food_item_id, "常用零食".to_owned());
    }
    for item in context.usual_nutritions {
        labels.insert(item.food_item_id, "常用营养品".to_owned());
    }
    labels
}

fn gallery_album_summary(
    summary: maohuoban_pet_domain::pet::HomeGalleryAlbumSummary,
) -> HomeGalleryAlbumSummary {
    HomeGalleryAlbumSummary {
        id: summary.id,
        pet_id: summary.pet_id,
        title: summary.title,
        cover_asset_id: summary.cover_asset_id,
        cover_url: summary.cover_url,
        photo_count: summary.photo_count,
    }
}

fn home_diet_trend_summary(
    summary: maohuoban_pet_application::pet::PetDietTrendSummary,
) -> HomeDietTrendSummary {
    HomeDietTrendSummary {
        window_days: summary.window_days,
        status: summary.status,
        segments: summary
            .segments
            .into_iter()
            .map(|segment| HomeDietTrendSegment {
                category: segment.category,
                title: segment.title,
                score: segment.score,
                percentage: segment.percentage,
                baseline_score: segment.baseline_score,
                baseline_sample_days: segment.baseline_sample_days,
                current_ratio: segment.current_ratio,
                ema_score: segment.ema_score,
            })
            .collect(),
        confidence: HomeDietTrendConfidence {
            level: summary.confidence.level,
            score: summary.confidence.score,
            basis: summary.confidence.basis,
        },
        health_context: HomeDietTrendHealthContext {
            included_sample_count: summary.health_context.included_sample_count,
            excluded_sample_count: summary.health_context.excluded_sample_count,
            excluded_reasons: summary.health_context.excluded_reasons,
        },
        calibration: HomeDietTrendCalibration {
            confidence: summary.calibration.confidence,
            grams_per_score: summary.calibration.grams_per_score,
            daily_grams: summary.calibration.daily_grams,
            reason: summary.calibration.reason,
        },
        explanation: HomeDietTrendExplanation {
            title: summary.explanation.title,
            body: summary.explanation.body,
        },
        analysis: HomeDietTrendAnalysis {
            headline: summary.analysis.headline,
            summary: summary.analysis.summary,
            observations: summary.analysis.observations,
        },
    }
}

fn pantry_category_title(category: FoodInventoryCategory) -> &'static str {
    match category {
        FoodInventoryCategory::MainFood => "主食干粮",
        FoodInventoryCategory::WetFood => "湿粮/罐头",
        FoodInventoryCategory::Treats => "零食奖励",
        FoodInventoryCategory::Nutrition => "营养保健",
        FoodInventoryCategory::Other => "其他",
        FoodInventoryCategory::CatLitter => "猫砂",
        FoodInventoryCategory::Medicine => "药品",
    }
}
