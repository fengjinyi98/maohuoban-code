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
        home_weight_projection, media_asset_ids, pet_hero_summary, pet_lifecycle_timeline_events,
        pet_switch_item, selected_pet,
    },
    recommendation_summary::{partner_recommendation_summary, recommended_content_summary},
};
use crate::home_event_projection::{reminders_from_events, timeline_event_summary};
use maohuoban_home_application::home::{
    HomeDashboardContext, HomeDashboardProvider, HomeError, HomeResult, new_user_home_snapshot,
    pet_owner_home_template,
};
use maohuoban_home_domain::home::{
    HomeDashboardSnapshot, HomeGalleryAlbumSummary, HomeIdentity, HomeIdentityKind,
    HomePantryPreviewItem, HomeTimelineEvent,
};
use maohuoban_pet_application::pet::PetService;
use maohuoban_pet_domain::pet::{
    FoodInventoryCategory, FoodInventoryItem, FoodScopeType, PetError, PetEvent, PetProfile,
};
use maohuoban_recommendation_application::recommendation::{
    HomeRecommendationContext, RecommendationService,
};
use tokio::sync::RwLock;
use uuid::Uuid;

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

        let mut snapshot = pet_owner_home_template();
        snapshot.identity = HomeIdentity {
            kind: HomeIdentityKind::PetOwner,
            display_name: "毛伙伴用户".to_owned(),
            city: None,
            verification_badge: None,
        };
        let selected_summary = pet_hero_summary(
            selected_pet,
            &media_metadata,
            home_weight_projection(&timeline.events),
        );
        record_home_selected_pet_output(
            user_id,
            selected_pet,
            &selected_summary,
            pets.len(),
            &media_metadata,
        );
        snapshot.selected_pet = Some(selected_summary);
        snapshot.pet_switcher = pets
            .iter()
            .map(|pet| pet_switch_item(pet, pet.id == selected_pet.id, &media_metadata))
            .collect();
        snapshot.recent_timeline = recent_home_timeline(&timeline.events, selected_pet);
        snapshot.gallery_albums = self
            .gallery_album_summaries(user_id, selected_pet.id)
            .await?;
        snapshot.reminders = reminders_from_events(&timeline.events);
        snapshot.attention_hints = self
            .pet_service
            .load_attention_hints(selected_pet.id)
            .await
            .map_err(|error| to_home_error(&error))?
            .into_iter()
            .filter_map(|value| serde_json::from_value(value).ok())
            .collect();
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
        let diet_role_labels = self
            .pet_service
            .load_pet_current_diet_context(user_id, selected_pet.id)
            .await
            .map(diet_role_labels)
            .map_err(|error| to_home_error(&error))?;
        snapshot.pantry_items = self
            .pet_service
            .list_food_inventory_items(FoodScopeType::User, user_id, None, None)
            .await
            .map_err(|error| to_home_error(&error))?
            .into_iter()
            .filter({
                let mut seen_categories = HashSet::new();
                move |item| seen_categories.insert(item.category.as_str())
            })
            .take(4)
            .map(|item| pantry_preview_item(item, &diet_role_labels))
            .collect();
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

/// `recent_home_timeline` 生成首页最近时间线摘要
/// 核心职责：
/// - 优先展示用户真实记录
/// - 在新建宠物无记录时展示出生和到家事实
fn recent_home_timeline(events: &[PetEvent], selected_pet: &PetProfile) -> Vec<HomeTimelineEvent> {
    let recent_events = events
        .iter()
        .take(4)
        .map(timeline_event_summary)
        .collect::<Vec<_>>();
    if recent_events.is_empty() {
        return pet_lifecycle_timeline_events(selected_pet);
    }

    recent_events
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
