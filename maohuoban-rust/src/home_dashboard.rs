use std::sync::Arc;

use crate::home_event_projection::{
    care_summary_from_events, reminders_from_events, timeline_event_summary,
};
use chrono::{Datelike, NaiveDate, Utc};
use maohuoban_home_application::home::{
    HomeDashboardContext, HomeDashboardProvider, HomeError, HomeResult, new_user_home_snapshot,
    pet_owner_home_snapshot,
};
use maohuoban_home_domain::home::{
    HomeAction, HomeActionKind, HomeDashboardSnapshot, HomeIdentity, HomeIdentityKind,
    HomeReminder, HomeReminderKind, MerchantDashboardSummary as HomeMerchantDashboardSummary,
    MerchantLitterSummary as HomeMerchantLitterSummary, MerchantPetStatus,
    MerchantStatusCount as HomeMerchantStatusCount, PartnerRecommendation, PartnerRelationshipKind,
    PetHeroSummary, PetSex as HomePetSex, PetSpecies as HomePetSpecies, PetSwitchItem,
    RecommendedContent, RecommendedContentKind,
};
use maohuoban_pet_application::pet::{
    MerchantDashboardSummary as AppMerchantDashboardSummary, PetService,
};
use maohuoban_pet_domain::pet::{
    ManagedPetStatus, PetError, PetProfile, PetSex as DomainPetSex, PetSpecies as DomainPetSpecies,
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
/// - 无用户上下文时保留开发 seed 快照
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
    /// - 支持首页契约测试切换开发 seed
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
            return Ok(snapshot);
        };

        let timeline = self
            .pet_service
            .load_pet_timeline(user_id, selected_pet.id)
            .await
            .map_err(|error| to_home_error(&error))?;

        let mut snapshot = pet_owner_home_snapshot();
        snapshot.identity = HomeIdentity {
            kind: HomeIdentityKind::PetOwner,
            display_name: "毛伙伴用户".to_owned(),
            city: None,
            verification_badge: None,
        };
        snapshot.selected_pet = Some(pet_hero_summary(selected_pet));
        snapshot.pet_switcher = pets
            .iter()
            .map(|pet| pet_switch_item(pet, pet.id == selected_pet.id))
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

fn pet_hero_summary(pet: &PetProfile) -> PetHeroSummary {
    let days_since_created = (Utc::now().date_naive() - pet.created_at.date_naive())
        .num_days()
        .max(0);
    let companionship_days = Some(i32::try_from(days_since_created).unwrap_or(i32::MAX));

    PetHeroSummary {
        id: pet.id,
        name: pet.name.clone(),
        species: home_pet_species(pet.species),
        breed: pet.breed.clone().unwrap_or_else(|| "未填写品种".to_owned()),
        sex: home_pet_sex(pet.sex),
        age_text: pet_age_text(pet.birthday),
        status_text: "记录正在形成可信档案".to_owned(),
        updated_text: "档案已同步".to_owned(),
        avatar_url: None,
        birthday: pet.birthday,
        companionship_days,
    }
}

fn pet_switch_item(pet: &PetProfile, is_selected: bool) -> PetSwitchItem {
    PetSwitchItem {
        id: pet.id,
        name: pet.name.clone(),
        species: home_pet_species(pet.species),
        avatar_url: None,
        is_selected,
    }
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
