import Foundation

// HomeDashboardSnapshot 首页聚合快照
// 核心职责：
// - 承载后端首页聚合接口返回的稳定读模型
// - 为首页各 section 提供窄输入来源
struct HomeDashboardSnapshot: Decodable, Equatable {
    let identity: Identity
    let selectedPet: PetHeroSummary?
    let petSwitcher: [PetSwitchItem]
    let careSummary: CareSummary?
    let reminders: [Reminder]
    let quickActions: [Action]
    let partnerRecommendation: PartnerRecommendation?
    let recentTimeline: [TimelineEvent]
    let merchantDashboard: MerchantDashboardSummary?
    let emptyState: EmptyState?
    let recommendedContent: [RecommendedContent]
    let petAlbums: [PetAlbumItem]?
    let galleryAlbums: [PetGalleryAlbum]?

    init(
        identity: Identity,
        selectedPet: PetHeroSummary?,
        petSwitcher: [PetSwitchItem],
        careSummary: CareSummary?,
        reminders: [Reminder],
        quickActions: [Action],
        partnerRecommendation: PartnerRecommendation? = nil,
        recentTimeline: [TimelineEvent],
        merchantDashboard: MerchantDashboardSummary?,
        emptyState: EmptyState?,
        recommendedContent: [RecommendedContent],
        petAlbums: [PetAlbumItem]? = nil,
        galleryAlbums: [PetGalleryAlbum]? = nil
    ) {
        self.identity = identity
        self.selectedPet = selectedPet
        self.petSwitcher = petSwitcher
        self.careSummary = careSummary
        self.reminders = reminders
        self.quickActions = quickActions
        self.partnerRecommendation = partnerRecommendation
        self.recentTimeline = recentTimeline
        self.merchantDashboard = merchantDashboard
        self.emptyState = emptyState
        self.recommendedContent = recommendedContent
        self.petAlbums = petAlbums
        self.galleryAlbums = galleryAlbums
    }

    enum CodingKeys: String, CodingKey {
        case identity
        case selectedPet = "selected_pet"
        case petSwitcher = "pet_switcher"
        case careSummary = "care_summary"
        case reminders
        case quickActions = "quick_actions"
        case partnerRecommendation = "partner_recommendation"
        case recentTimeline = "recent_timeline"
        case merchantDashboard = "merchant_dashboard"
        case emptyState = "empty_state"
        case recommendedContent = "recommended_content"
        case petAlbums = "pet_albums"
        case galleryAlbums = "gallery_albums"
    }
}

extension HomeDashboardSnapshot {
    // Identity 首页身份摘要
    // 核心职责：
    // - 表达当前首页形态
    // - 驱动普通用户、空态和商家工作台渲染分支
    struct Identity: Decodable, Equatable {
        let kind: IdentityKind
        let displayName: String
        let city: String?
        let verificationBadge: String?
        let avatarURL: String?

        init(
            kind: IdentityKind,
            displayName: String,
            city: String?,
            verificationBadge: String?,
            avatarURL: String? = nil
        ) {
            self.kind = kind
            self.displayName = displayName
            self.city = city
            self.verificationBadge = verificationBadge
            self.avatarURL = avatarURL
        }

        enum CodingKeys: String, CodingKey {
            case kind
            case displayName = "display_name"
            case city
            case verificationBadge = "verification_badge"
            case avatarURL = "avatar_url"
        }
    }

    // IdentityKind 首页身份类型
    // 核心职责：
    // - 固定首页身份枚举
    // - 为客户端切换首页结构提供稳定语义
    enum IdentityKind: String, Decodable, Equatable {
        case newUser = "new_user"
        case petOwner = "pet_owner"
        case familyCaretaker = "family_caretaker"
        case certifiedMerchant = "certified_merchant"
        case unverifiedMerchant = "unverified_merchant"
    }

    // PetHeroSummary 宠物主卡摘要
    // 核心职责：
    // - 承载首页首屏宠物主体信息
    // - 避免首页依赖完整宠物档案字段
    struct PetHeroSummary: Decodable, Equatable, Identifiable {
        let id: String
        let name: String
        let species: Species
        let breed: String
        let sex: Sex
        let ageText: String
        let statusText: String
        let updatedText: String
        let avatarURL: String?
        let heroImageAssetName: String?
        let birthday: String?
        let companionshipDays: Int?
        let stats: PetHeroStats?

        init(
            id: String,
            name: String,
            species: Species,
            breed: String,
            sex: Sex,
            ageText: String,
            statusText: String,
            updatedText: String,
            avatarURL: String?,
            heroImageAssetName: String?,
            birthday: String? = nil,
            companionshipDays: Int? = nil,
            stats: PetHeroStats? = nil
        ) {
            self.id = id
            self.name = name
            self.species = species
            self.breed = breed
            self.sex = sex
            self.ageText = ageText
            self.statusText = statusText
            self.updatedText = updatedText
            self.avatarURL = avatarURL
            self.heroImageAssetName = heroImageAssetName
            self.birthday = birthday
            self.companionshipDays = companionshipDays
            self.stats = stats
        }

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case species
            case breed
            case sex
            case ageText = "age_text"
            case statusText = "status_text"
            case updatedText = "updated_text"
            case avatarURL = "avatar_url"
            case heroImageAssetName = "hero_image_asset_name"
            case birthday
            case companionshipDays = "companionship_days"
            case stats
        }
    }

    // PetHeroStats 宠物主卡核心指标 (Mock 数据支持)
    struct PetHeroStats: Decodable, Equatable {
        let weightVal: String
        let weightChange: String
        let recordDays: Int
        let recordStreakText: String
        let vaccineDaysLeft: Int
        let vaccineDate: String
        let dewormingDaysLeft: Int
        let dewormingDate: String

        enum CodingKeys: String, CodingKey {
            case weightVal = "weight_val"
            case weightChange = "weight_change"
            case recordDays = "record_days"
            case recordStreakText = "record_streak_text"
            case vaccineDaysLeft = "vaccine_days_left"
            case vaccineDate = "vaccine_date"
            case dewormingDaysLeft = "deworming_days_left"
            case dewormingDate = "deworming_date"
        }

        static let mock = PetHeroStats(
            weightVal: "3.6",
            weightChange: "较上周 +0.2",
            recordDays: 27,
            recordStreakText: "连续记录",
            vaccineDaysLeft: 14,
            vaccineDate: "2026.06.08",
            dewormingDaysLeft: 3,
            dewormingDate: "2026.05.28"
        )
    }

    // Species 宠物物种
    // 核心职责：
    // - 约束首页宠物物种表达
    // - 支持图标和文案按物种区分
    enum Species: String, Decodable, Equatable {
        case dog
        case cat
        case other
    }

    // Sex 宠物性别
    // 核心职责：
    // - 约束首页宠物性别表达
    // - 支持未知性别展示
    enum Sex: String, Decodable, Equatable {
        case female
        case male
        case unknown
    }

    // PetSwitchItem 宠物切换项
    // 核心职责：
    // - 承载多宠切换入口
    // - 表达当前选中宠物
    struct PetSwitchItem: Decodable, Equatable, Identifiable {
        let id: String
        let name: String
        let species: Species
        let avatarURL: String?
        let isSelected: Bool

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case species
            case avatarURL = "avatar_url"
            case isSelected = "is_selected"
        }
    }
}
