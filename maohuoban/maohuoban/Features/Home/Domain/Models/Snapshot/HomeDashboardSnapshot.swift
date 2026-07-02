import Foundation

// HomeDashboardSnapshot 首页聚合快照
// 核心职责：
// - 承载后端首页聚合接口返回的稳定读模型
// - 为首页各 section 提供窄输入来源
struct HomeDashboardSnapshot: Decodable, Equatable {
    let identity: Identity
    let selectedPet: PetHeroSummary?
    let petSwitcher: [PetSwitchItem]
    let reminders: [Reminder]
    let quickActions: [Action]
    let partnerRecommendation: PartnerRecommendation?
    let recentTimeline: [TimelineEvent]
    let merchantDashboard: MerchantDashboardSummary?
    let emptyState: EmptyState?
    let recommendedContent: [RecommendedContent]
    let petAlbums: [PetAlbumItem]?
    let galleryAlbums: [PetGalleryAlbum]?
    let pantryItems: [PantryPreviewItem]?
    let attentionHints: [AttentionHint]

    init(
        identity: Identity,
        selectedPet: PetHeroSummary?,
        petSwitcher: [PetSwitchItem],
        reminders: [Reminder],
        quickActions: [Action],
        partnerRecommendation: PartnerRecommendation? = nil,
        recentTimeline: [TimelineEvent],
        merchantDashboard: MerchantDashboardSummary?,
        emptyState: EmptyState?,
        recommendedContent: [RecommendedContent],
        petAlbums: [PetAlbumItem]? = nil,
        galleryAlbums: [PetGalleryAlbum]? = nil,
        pantryItems: [PantryPreviewItem]? = nil,
        attentionHints: [AttentionHint] = []
    ) {
        self.identity = identity
        self.selectedPet = selectedPet
        self.petSwitcher = petSwitcher
        self.reminders = reminders
        self.quickActions = quickActions
        self.partnerRecommendation = partnerRecommendation
        self.recentTimeline = recentTimeline
        self.merchantDashboard = merchantDashboard
        self.emptyState = emptyState
        self.recommendedContent = recommendedContent
        self.petAlbums = petAlbums
        self.galleryAlbums = galleryAlbums
        self.pantryItems = pantryItems
        self.attentionHints = attentionHints
    }

    enum CodingKeys: String, CodingKey {
        case identity
        case selectedPet = "selected_pet"
        case petSwitcher = "pet_switcher"
        case reminders
        case quickActions = "quick_actions"
        case partnerRecommendation = "partner_recommendation"
        case recentTimeline = "recent_timeline"
        case merchantDashboard = "merchant_dashboard"
        case emptyState = "empty_state"
        case recommendedContent = "recommended_content"
        case petAlbums = "pet_albums"
        case galleryAlbums = "gallery_albums"
        case pantryItems = "pantry_items"
        case attentionHints = "attention_hints"
    }
}
