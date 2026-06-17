use std::{collections::HashMap, sync::Arc};

use crate::home_event_projection::{
    care_summary_from_events, reminders_from_events, timeline_event_summary,
};
use chrono::{Datelike, NaiveDate, Utc};
use maohuoban_home_application::home::{
    HomeDashboardContext, HomeDashboardProvider, HomeError, HomeResult, new_user_home_snapshot,
    pet_owner_home_template,
};
use maohuoban_home_domain::home::{
    HomeAction, HomeActionKind, HomeDashboardSnapshot, HomeIdentity, HomeIdentityKind,
    HomeReminder, HomeReminderKind, MerchantDashboardSummary as HomeMerchantDashboardSummary,
    MerchantLitterSummary as HomeMerchantLitterSummary, MerchantPetStatus,
    MerchantStatusCount as HomeMerchantStatusCount, PartnerRecommendation, PartnerRelationshipKind,
    PetHeroSummary, PetNameEditPolicy as HomePetNameEditPolicy,
    PetNeuterStatus as HomePetNeuterStatus, PetSex as HomePetSex, PetSpecies as HomePetSpecies,
    PetSwitchItem, RecommendedContent, RecommendedContentKind,
};
use maohuoban_pet_application::pet::{
    HomeDashboardDiagnosticSnapshot, MediaAssetDisplayMetadata,
    MerchantDashboardSummary as AppMerchantDashboardSummary, PetService,
    record_home_dashboard_snapshot,
};
use maohuoban_pet_domain::pet::{
    ManagedPetStatus, PetBackgroundMediaKind, PetError,
    PetNameEditPolicy as DomainPetNameEditPolicy, PetNeuterStatus as DomainPetNeuterStatus,
    PetProfile, PetSex as DomainPetSex, PetSpecies as DomainPetSpecies,
};
use maohuoban_recommendation_application::recommendation::{
    HomeRecommendationContext, RecommendationService,
};
use maohuoban_recommendation_domain::recommendation::{
    HomePartnerRecommendation, HomeRecommendedContent,
    HomeRecommendedContentKind as RecommendationContentKind,
    HomeRelationshipKind as RecommendationRelationshipKind,
};
use tokio::sync::RwLock;
use uuid::Uuid;

/// InMemoryHomeDashboardProvider 内存首页快照提供器
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

    /// replace_snapshot 替换首页快照
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

/// HybridHomeDashboardProvider 混合首页快照提供器
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

    /// replace_snapshot 替换无上下文首页快照
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
            return Ok(snapshot);
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
        let selected_summary = pet_hero_summary(selected_pet, &media_metadata);
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
        snapshot.recent_timeline = timeline
            .events
            .iter()
            .take(3)
            .map(timeline_event_summary)
            .collect();
        snapshot.care_summary = Some(care_summary_from_events(&timeline.events));
        snapshot.reminders = reminders_from_events(&timeline.events);
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
        snapshot.merchant_dashboard = None;
        snapshot.empty_state = None;
        snapshot.recommended_content = Vec::new();
        Ok(snapshot)
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

fn selected_pet(pets: &[PetProfile], selected_pet_id: Option<Uuid>) -> Option<&PetProfile> {
    selected_pet_id
        .and_then(|pet_id| pets.iter().find(|pet| pet.id == pet_id))
        .or_else(|| pets.first())
}

/// record_home_pet_list 记录首页宠物列表读取结果
/// 核心职责：
/// - 捕获用户上下文下可见宠物数量
/// - 保留当前选择宠物参数的脱敏标识
fn record_home_pet_list(user_id: Uuid, selected_pet_id: Option<Uuid>, pet_count: usize) {
    record_home_dashboard_snapshot(HomeDashboardDiagnosticSnapshot {
        stage: "provider.list_pets",
        user_id: Some(user_id),
        selected_pet_id,
        pet_count,
        background_asset_id: None,
        background_media_kind: None,
        metadata_present: false,
        hero_image_present: false,
        hero_video_present: false,
        hero_video_width: None,
        hero_video_height: None,
        hero_theme_color_hex: None,
    });
}

/// record_home_empty_state 记录首页空态输出
/// 核心职责：
/// - 标记后端已进入无宠物空态
/// - 为前端误显示添加宠物页提供后端证据
fn record_home_empty_state(user_id: Uuid) {
    record_home_dashboard_snapshot(HomeDashboardDiagnosticSnapshot {
        stage: "provider.empty_state",
        user_id: Some(user_id),
        selected_pet_id: None,
        pet_count: 0,
        background_asset_id: None,
        background_media_kind: None,
        metadata_present: false,
        hero_image_present: false,
        hero_video_present: false,
        hero_video_width: None,
        hero_video_height: None,
        hero_theme_color_hex: None,
    });
}

/// record_home_media_metadata 记录首页媒体元数据读取结果
/// 核心职责：
/// - 捕获选中宠物背景资产是否读取到展示元数据
/// - 保留背景媒体类型用于图片和视频分支排查
fn record_home_media_metadata(
    user_id: Uuid,
    selected_pet: &PetProfile,
    pet_count: usize,
    media_metadata: &HashMap<Uuid, MediaAssetDisplayMetadata>,
) {
    record_home_dashboard_snapshot(HomeDashboardDiagnosticSnapshot {
        stage: "provider.media_metadata",
        user_id: Some(user_id),
        selected_pet_id: Some(selected_pet.id),
        pet_count,
        background_asset_id: selected_pet.background_asset_id,
        background_media_kind: selected_pet
            .background_media_kind
            .map(PetBackgroundMediaKind::as_str),
        metadata_present: has_background_metadata(selected_pet, media_metadata),
        hero_image_present: false,
        hero_video_present: false,
        hero_video_width: None,
        hero_video_height: None,
        hero_theme_color_hex: None,
    });
}

/// record_home_selected_pet_output 记录首页选中宠物 DTO 输出
/// 核心职责：
/// - 捕获 hero 图片或视频最终输出状态
/// - 记录前端布局消费的尺寸和主题色字段
fn record_home_selected_pet_output(
    user_id: Uuid,
    selected_pet: &PetProfile,
    selected_summary: &PetHeroSummary,
    pet_count: usize,
    media_metadata: &HashMap<Uuid, MediaAssetDisplayMetadata>,
) {
    record_home_dashboard_snapshot(HomeDashboardDiagnosticSnapshot {
        stage: "selected_pet.output",
        user_id: Some(user_id),
        selected_pet_id: Some(selected_summary.id),
        pet_count,
        background_asset_id: selected_pet.background_asset_id,
        background_media_kind: selected_pet
            .background_media_kind
            .map(PetBackgroundMediaKind::as_str),
        metadata_present: has_background_metadata(selected_pet, media_metadata),
        hero_image_present: selected_summary.hero_image_url.is_some(),
        hero_video_present: selected_summary.hero_video_url.is_some(),
        hero_video_width: selected_summary.hero_video_width,
        hero_video_height: selected_summary.hero_video_height,
        hero_theme_color_hex: selected_summary.hero_theme_color_hex.as_deref(),
    });
}

fn has_background_metadata(
    selected_pet: &PetProfile,
    media_metadata: &HashMap<Uuid, MediaAssetDisplayMetadata>,
) -> bool {
    selected_pet
        .background_asset_id
        .is_some_and(|asset_id| media_metadata.contains_key(&asset_id))
}

fn media_asset_ids(pets: &[PetProfile]) -> Vec<Uuid> {
    pets.iter()
        .flat_map(|pet| [pet.avatar_asset_id, pet.background_asset_id])
        .flatten()
        .collect()
}

fn pet_hero_summary(
    pet: &PetProfile,
    media_metadata: &HashMap<Uuid, MediaAssetDisplayMetadata>,
) -> PetHeroSummary {
    let companionship_start_date = pet
        .arrival_date
        .unwrap_or_else(|| pet.created_at.date_naive());
    let companionship_days = Some(companionship_days_since(companionship_start_date));
    let avatar_metadata = pet
        .avatar_asset_id
        .and_then(|asset_id| media_metadata.get(&asset_id));
    let background_metadata = pet
        .background_asset_id
        .and_then(|asset_id| media_metadata.get(&asset_id));
    let hero_theme_color_hex = background_metadata.and_then(|metadata| {
        metadata
            .theme_color_hex
            .as_deref()
            .filter(|value| !value.is_empty())
            .map(ToOwned::to_owned)
    });
    let hero_content_color_scheme = hero_theme_color_hex
        .as_deref()
        .and_then(hero_content_color_scheme);

    PetHeroSummary {
        id: pet.id,
        name: pet.name.clone(),
        species: home_pet_species(pet.species),
        breed: pet.breed.clone().unwrap_or_else(|| "未填写品种".to_owned()),
        sex: home_pet_sex(pet.sex),
        age_text: pet_age_text(pet.birthday),
        status_text: "记录正在形成可信档案".to_owned(),
        updated_text: "档案已同步".to_owned(),
        avatar_url: pet.avatar_asset_id.map(media_asset_url),
        avatar_width: avatar_metadata.and_then(|metadata| metadata.width),
        avatar_height: avatar_metadata.and_then(|metadata| metadata.height),
        hero_image_url: hero_image_url(pet),
        hero_image_width: hero_image_dimensions(pet, background_metadata).0,
        hero_image_height: hero_image_dimensions(pet, background_metadata).1,
        hero_video_url: hero_video_url(pet),
        hero_video_width: hero_video_dimensions(pet, background_metadata).0,
        hero_video_height: hero_video_dimensions(pet, background_metadata).1,
        hero_theme_color_hex,
        hero_content_color_scheme,
        profile_number: Some(pet.profile_number.clone()),
        microchip_number: pet.microchip_number.clone(),
        birthday: pet.birthday,
        arrival_date: pet.arrival_date,
        weight_grams: pet.weight_grams,
        neuter_status: Some(home_pet_neuter_status(pet.neuter_status)),
        personality_tags: pet.personality_tags.clone(),
        note: pet.note.clone(),
        name_edit_policy: pet.name_edit_policy.as_ref().map(home_name_edit_policy),
        companionship_days,
    }
}

/// `companionship_days_since` 计算宠物陪伴天数
/// 核心职责：
/// - 按业务起始日期派生首页陪伴天数
/// - 保证未来日期不会产生负数展示
fn companionship_days_since(start_date: chrono::NaiveDate) -> i32 {
    let days = (Utc::now().date_naive() - start_date).num_days().max(0);
    i32::try_from(days).unwrap_or(i32::MAX)
}

fn pet_switch_item(
    pet: &PetProfile,
    is_selected: bool,
    media_metadata: &HashMap<Uuid, MediaAssetDisplayMetadata>,
) -> PetSwitchItem {
    let avatar_metadata = pet
        .avatar_asset_id
        .and_then(|asset_id| media_metadata.get(&asset_id));

    PetSwitchItem {
        id: pet.id,
        name: pet.name.clone(),
        species: home_pet_species(pet.species),
        breed: pet.breed.clone().unwrap_or_default(),
        avatar_url: pet.avatar_asset_id.map(media_asset_url),
        avatar_width: avatar_metadata.and_then(|metadata| metadata.width),
        avatar_height: avatar_metadata.and_then(|metadata| metadata.height),
        profile_number: Some(pet.profile_number.clone()),
        microchip_number: pet.microchip_number.clone(),
        birthday: pet.birthday,
        arrival_date: pet.arrival_date,
        weight_grams: pet.weight_grams,
        neuter_status: Some(home_pet_neuter_status(pet.neuter_status)),
        personality_tags: pet.personality_tags.clone(),
        note: pet.note.clone(),
        name_edit_policy: pet.name_edit_policy.as_ref().map(home_name_edit_policy),
        is_selected,
    }
}

fn home_name_edit_policy(policy: &DomainPetNameEditPolicy) -> HomePetNameEditPolicy {
    HomePetNameEditPolicy {
        max_count: policy.max_count,
        used_count: policy.used_count,
        remaining_count: policy.remaining_count,
        window_days: policy.window_days,
        window_ends_at: policy.window_ends_at,
        display_text: policy.display_text.clone(),
    }
}

fn hero_image_url(pet: &PetProfile) -> Option<String> {
    match pet.background_media_kind {
        Some(PetBackgroundMediaKind::Image) => pet.background_asset_id.map(media_asset_url),
        _ => None,
    }
}

fn hero_video_url(pet: &PetProfile) -> Option<String> {
    match pet.background_media_kind {
        Some(PetBackgroundMediaKind::Video) => pet.background_asset_id.map(media_asset_url),
        _ => None,
    }
}

fn hero_image_dimensions(
    pet: &PetProfile,
    metadata: Option<&MediaAssetDisplayMetadata>,
) -> (Option<i32>, Option<i32>) {
    match pet.background_media_kind {
        Some(PetBackgroundMediaKind::Image) => media_dimensions(metadata),
        _ => (None, None),
    }
}

fn hero_video_dimensions(
    pet: &PetProfile,
    metadata: Option<&MediaAssetDisplayMetadata>,
) -> (Option<i32>, Option<i32>) {
    match pet.background_media_kind {
        Some(PetBackgroundMediaKind::Video) => media_dimensions(metadata),
        _ => (None, None),
    }
}

fn media_dimensions(metadata: Option<&MediaAssetDisplayMetadata>) -> (Option<i32>, Option<i32>) {
    metadata.map_or((None, None), |metadata| (metadata.width, metadata.height))
}

fn hero_content_color_scheme(hex: &str) -> Option<String> {
    let (red, green, blue) = parse_hex_rgb(hex)?;
    let luminance = relative_luminance(red, green, blue);
    Some(if luminance > 0.46 { "light" } else { "dark" }.to_owned())
}

fn parse_hex_rgb(hex: &str) -> Option<(u8, u8, u8)> {
    let value = hex.strip_prefix('#').unwrap_or(hex);
    if value.len() != 6 {
        return None;
    }
    let red = u8::from_str_radix(&value[0..2], 16).ok()?;
    let green = u8::from_str_radix(&value[2..4], 16).ok()?;
    let blue = u8::from_str_radix(&value[4..6], 16).ok()?;
    Some((red, green, blue))
}

fn relative_luminance(red: u8, green: u8, blue: u8) -> f64 {
    fn linear_channel(value: u8) -> f64 {
        let normalized = f64::from(value) / 255.0;
        if normalized <= 0.03928 {
            normalized / 12.92
        } else {
            ((normalized + 0.055) / 1.055).powf(2.4)
        }
    }

    0.2126 * linear_channel(red) + 0.7152 * linear_channel(green) + 0.0722 * linear_channel(blue)
}

fn media_asset_url(asset_id: Uuid) -> String {
    format!("/api/v1/media/assets/{asset_id}/content")
}

fn merchant_home_snapshot_from_workspace(
    workspace: &AppMerchantDashboardSummary,
) -> HomeDashboardSnapshot {
    HomeDashboardSnapshot {
        identity: HomeIdentity {
            kind: HomeIdentityKind::CertifiedMerchant,
            display_name: workspace.merchant.name.clone(),
            city: workspace.merchant.city.clone(),
            verification_badge: Some("已认证".to_owned()),
        },
        selected_pet: None,
        pet_switcher: Vec::new(),
        care_summary: None,
        reminders: Vec::new(),
        quick_actions: vec![
            HomeAction {
                kind: HomeActionKind::AddMerchantPet,
                title: "新增宠物".to_owned(),
                subtitle: Some("录入店内宠物或窝次".to_owned()),
            },
            HomeAction {
                kind: HomeActionKind::PublishAvailableStatus,
                title: "发布可售状态".to_owned(),
                subtitle: Some("更新买家可见信息".to_owned()),
            },
        ],
        partner_recommendation: None,
        recent_timeline: Vec::new(),
        merchant_dashboard: Some(HomeMerchantDashboardSummary {
            merchant_id: workspace.merchant.id,
            merchant_name: workspace.merchant.name.clone(),
            status_counts: workspace
                .status_counts
                .iter()
                .filter_map(merchant_status_count_summary)
                .collect(),
            litters: workspace
                .litters
                .iter()
                .map(merchant_litter_summary)
                .collect(),
            pending_tasks: merchant_pending_tasks(workspace),
            recent_events: workspace
                .recent_events
                .iter()
                .take(3)
                .map(timeline_event_summary)
                .collect(),
        }),
        empty_state: None,
        recommended_content: Vec::new(),
    }
}

fn merchant_status_count_summary(
    count: &maohuoban_pet_domain::pet::MerchantStatusCount,
) -> Option<HomeMerchantStatusCount> {
    Some(HomeMerchantStatusCount {
        status: home_merchant_status(count.status)?,
        title: merchant_status_title(count.status).to_owned(),
        count: count.count,
    })
}

fn home_merchant_status(status: ManagedPetStatus) -> Option<MerchantPetStatus> {
    match status {
        ManagedPetStatus::Available => Some(MerchantPetStatus::Available),
        ManagedPetStatus::Reserved => Some(MerchantPetStatus::Reserved),
        ManagedPetStatus::Sold => Some(MerchantPetStatus::Sold),
        ManagedPetStatus::NeedsExam => Some(MerchantPetStatus::NeedsExam),
        ManagedPetStatus::NeedsRecord => Some(MerchantPetStatus::NeedsRecord),
        _ => None,
    }
}

fn merchant_status_title(status: ManagedPetStatus) -> &'static str {
    match status {
        ManagedPetStatus::Available => "在售",
        ManagedPetStatus::Reserved => "预定",
        ManagedPetStatus::Sold => "已售",
        ManagedPetStatus::NeedsExam => "待体检",
        ManagedPetStatus::NeedsRecord => "待补记录",
        _ => "其他",
    }
}

fn merchant_litter_summary(
    litter: &maohuoban_pet_application::pet::MerchantLitterSummary,
) -> HomeMerchantLitterSummary {
    HomeMerchantLitterSummary {
        id: litter.id,
        name: litter.name.clone(),
        parent_text: merchant_parent_text(litter),
        born_text: format!("{} 出生", litter.born_at),
        available_count: litter.available_count,
    }
}

fn merchant_parent_text(litter: &maohuoban_pet_application::pet::MerchantLitterSummary) -> String {
    let sire_name = litter.sire_name.as_deref().unwrap_or("未知父亲");
    let dam_name = litter.dam_name.as_deref().unwrap_or("未知母亲");
    format!("父亲 {sire_name} · 母亲 {dam_name}")
}

fn merchant_pending_tasks(workspace: &AppMerchantDashboardSummary) -> Vec<HomeReminder> {
    let Some(needs_record) = workspace
        .status_counts
        .iter()
        .find(|count| count.status == ManagedPetStatus::NeedsRecord)
    else {
        return Vec::new();
    };
    if needs_record.count == 0 {
        return Vec::new();
    }

    vec![HomeReminder {
        id: workspace.merchant.id,
        kind: HomeReminderKind::CompleteHealthRecord,
        title: "补齐健康记录".to_owned(),
        subtitle: format!("{} 只宠物待补健康或成长记录", needs_record.count),
        due_text: "今天".to_owned(),
    }]
}

fn partner_recommendation_summary(
    recommendation: HomePartnerRecommendation,
) -> PartnerRecommendation {
    PartnerRecommendation {
        pet_id: recommendation.pet_id,
        pet_name: recommendation.pet_name,
        relationship_kind: home_relationship_kind(recommendation.relationship_kind),
        title: recommendation.title,
        subtitle: recommendation.subtitle,
        distance_text: recommendation.distance_text,
    }
}

fn home_relationship_kind(kind: RecommendationRelationshipKind) -> PartnerRelationshipKind {
    match kind {
        RecommendationRelationshipKind::SameLitter => PartnerRelationshipKind::SameLitter,
        RecommendationRelationshipKind::SameCity => PartnerRelationshipKind::SameCity,
        RecommendationRelationshipKind::SameCondition => PartnerRelationshipKind::SameCondition,
        RecommendationRelationshipKind::SameHospital => PartnerRelationshipKind::SameHospital,
        RecommendationRelationshipKind::SameSource => PartnerRelationshipKind::SameSource,
    }
}

fn recommended_content_summary(content: HomeRecommendedContent) -> RecommendedContent {
    RecommendedContent {
        id: content.id,
        kind: home_recommended_content_kind(content.kind),
        title: content.title,
        source_text: content.source_text,
    }
}

fn home_recommended_content_kind(kind: RecommendationContentKind) -> RecommendedContentKind {
    match kind {
        RecommendationContentKind::Ugc => RecommendedContentKind::Ugc,
        RecommendationContentKind::Guide => RecommendedContentKind::Guide,
        RecommendationContentKind::LocalService => RecommendedContentKind::LocalService,
    }
}

fn home_pet_species(species: DomainPetSpecies) -> HomePetSpecies {
    match species {
        DomainPetSpecies::Dog => HomePetSpecies::Dog,
        DomainPetSpecies::Cat => HomePetSpecies::Cat,
        DomainPetSpecies::Other => HomePetSpecies::Other,
    }
}

fn home_pet_sex(sex: DomainPetSex) -> HomePetSex {
    match sex {
        DomainPetSex::Female => HomePetSex::Female,
        DomainPetSex::Male => HomePetSex::Male,
        DomainPetSex::Unknown => HomePetSex::Unknown,
    }
}

fn home_pet_neuter_status(status: DomainPetNeuterStatus) -> HomePetNeuterStatus {
    match status {
        DomainPetNeuterStatus::Unknown => HomePetNeuterStatus::Unknown,
        DomainPetNeuterStatus::Intact => HomePetNeuterStatus::Intact,
        DomainPetNeuterStatus::Neutered => HomePetNeuterStatus::Neutered,
    }
}

fn pet_age_text(birthday: Option<NaiveDate>) -> String {
    let Some(birthday) = birthday else {
        return "未填写年龄".to_owned();
    };
    let today = Utc::now().date_naive();
    if birthday > today {
        return "未填写年龄".to_owned();
    }
    let mut years = today.year() - birthday.year();
    if (today.month(), today.day()) < (birthday.month(), birthday.day()) {
        years -= 1;
    }
    if years > 0 {
        format!("{years}岁")
    } else {
        "未满1岁".to_owned()
    }
}

fn to_home_error(error: &PetError) -> HomeError {
    HomeError::Infrastructure(error.to_string())
}
