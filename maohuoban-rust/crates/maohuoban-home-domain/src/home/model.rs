use serde::{Deserialize, Serialize};

mod activity;
mod attention_hint;
mod diet_trend;
mod gallery;
mod identity;
mod merchant;
mod pantry;
mod pet;

pub use activity::{
    HomeAction, HomeActionKind, HomeEmptyState, HomeEmptyStateKind, HomeReminder, HomeReminderKind,
    HomeTimelineEvent, HomeTimelineEventKind, PartnerRecommendation, PartnerRelationshipKind,
    RecommendedContent, RecommendedContentKind,
};
pub use attention_hint::{
    AttentionHint, AttentionHintCreator, AttentionHintKind, AttentionHintRoute,
    AttentionHintRouteKind, AttentionHintStatus, AttentionHintTone,
};
pub use diet_trend::{
    HomeDietTrendCalibration, HomeDietTrendConfidence, HomeDietTrendExplanation,
    HomeDietTrendHealthContext, HomeDietTrendSegment, HomeDietTrendSummary,
};
pub use gallery::HomeGalleryAlbumSummary;
pub use identity::{HomeIdentity, HomeIdentityKind};
pub use merchant::{
    MerchantDashboardSummary, MerchantLitterSummary, MerchantPetStatus, MerchantStatusCount,
};
pub use pantry::HomePantryPreviewItem;
pub use pet::{
    HeroLivePhotoCrop, HeroLivePhotoSummary, PetHeroStats, PetHeroSummary, PetNameEditPolicy,
    PetNeuterStatus, PetSex, PetSpecies, PetSwitchItem, PreventiveCareKind, PreventiveCareSummary,
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
    pub reminders: Vec<HomeReminder>,
    pub attention_hints: Vec<AttentionHint>,
    pub quick_actions: Vec<HomeAction>,
    pub partner_recommendation: Option<PartnerRecommendation>,
    pub recent_timeline: Vec<HomeTimelineEvent>,
    pub gallery_albums: Vec<HomeGalleryAlbumSummary>,
    pub merchant_dashboard: Option<MerchantDashboardSummary>,
    pub empty_state: Option<HomeEmptyState>,
    pub recommended_content: Vec<RecommendedContent>,
    pub pantry_items: Vec<HomePantryPreviewItem>,
    pub diet_trend_summary: Option<HomeDietTrendSummary>,
}
