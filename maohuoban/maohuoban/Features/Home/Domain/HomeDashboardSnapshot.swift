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

        enum CodingKeys: String, CodingKey {
            case kind
            case displayName = "display_name"
            case city
            case verificationBadge = "verification_badge"
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
        }
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

