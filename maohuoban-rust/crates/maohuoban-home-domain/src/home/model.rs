use serde::{Deserialize, Serialize};

mod activity;
mod identity;
mod merchant;
mod pet;

pub use activity::{
    CareMetric, CareMetricKind, CareSummary, HomeAction, HomeActionKind, HomeEmptyState,
    HomeEmptyStateKind, HomeReminder, HomeReminderKind, HomeTimelineEvent, HomeTimelineEventKind,
    PartnerRecommendation, PartnerRelationshipKind, RecommendedContent, RecommendedContentKind,
};
pub use identity::{HomeIdentity, HomeIdentityKind};
pub use merchant::{
    MerchantDashboardSummary, MerchantLitterSummary, MerchantPetStatus, MerchantStatusCount,
};
pub use pet::{
    HeroLivePhotoCrop, HeroLivePhotoSummary, PetHeroSummary, PetNameEditPolicy, PetNeuterStatus,
    PetSex, PetSpecies, PetSwitchItem,
};

/// HomeDashboardSnapshot 首页聚合快照
/// 核心职责：
/// - 承载首页所有 section 的稳定读模型
/// - 让 HTTP 和 iOS 只依赖聚合结果而非深层业务实现
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct HomeDashboardSnapshot {
    pub identity: HomeIdentity,
    pub selected_pet: Option<PetHeroSummary>,
    pub pet_switcher: Vec<PetSwitchItem>,
    pub care_summary: Option<CareSummary>,
    pub reminders: Vec<HomeReminder>,
    pub quick_actions: Vec<HomeAction>,
    pub partner_recommendation: Option<PartnerRecommendation>,
    pub recent_timeline: Vec<HomeTimelineEvent>,
    pub merchant_dashboard: Option<MerchantDashboardSummary>,
    pub empty_state: Option<HomeEmptyState>,
    pub recommended_content: Vec<RecommendedContent>,
}
