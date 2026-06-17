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
    // optimisticSelectingPet 构造宠物切换的乐观首页快照
    // 核心职责：
    // - 在后端新快照返回前立即更新选中宠物入口
    // - 保持页面处于 loaded 状态，避免切换宠物时回到全屏加载态
    func optimisticallySelectingPet(id petID: String) -> HomeDashboardSnapshot? {
        guard let selectedItem = petSwitcher.first(where: { $0.id == petID }) else {
            return nil
        }

        let updatedPetSwitcher = petSwitcher.map { item in
            PetSwitchItem(
                id: item.id,
                name: item.name,
                species: item.species,
                avatarURL: item.avatarURL,
                isSelected: item.id == petID
            )
        }

        let optimisticPet = PetHeroSummary(
            id: selectedItem.id,
            name: selectedItem.name,
            species: selectedItem.species,
            breed: selectedPet?.breed ?? "",
            sex: selectedPet?.sex ?? .unknown,
            ageText: selectedPet?.ageText ?? "",
            statusText: "正在同步档案",
            updatedText: "同步中",
            avatarURL: selectedItem.avatarURL,
            heroImageAssetName: selectedPet?.heroImageAssetName,
            heroVideoResourceName: selectedPet?.heroVideoResourceName,
            birthday: selectedPet?.birthday,
            companionshipDays: selectedPet?.companionshipDays,
            stats: selectedPet?.stats
        )

        return HomeDashboardSnapshot(
            identity: identity,
            selectedPet: optimisticPet,
            petSwitcher: updatedPetSwitcher,
            careSummary: careSummary,
            reminders: reminders,
            quickActions: quickActions,
            partnerRecommendation: partnerRecommendation,
            recentTimeline: recentTimeline,
            merchantDashboard: merchantDashboard,
            emptyState: emptyState,
            recommendedContent: recommendedContent,
            petAlbums: petAlbums,
            galleryAlbums: galleryAlbums
        )
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
        // HeroMedia 首页头图媒体来源
        // 核心职责：
        // - 表达宠物头图当前使用图片或视频
        // - 为渲染层和主题取色提供统一媒体入口
        enum HeroMedia: Equatable {
            case image(assetName: String)
            case video(resourceName: String, fileExtension: String, fallbackImageAssetName: String?)
        }

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
        let heroVideoResourceName: String?
        let profileNumber: String?
        let microchipNumber: String?
        let birthday: String?
        let arrivalDate: String?
        let weightGrams: Int?
        let neuterStatus: PetNeuterStatus?
        let personalityTags: [String]
        let note: String?
        let companionshipDays: Int?
        let stats: PetHeroStats?

        var heroMedia: HeroMedia {
            if let heroVideoResourceName {
                return .video(
                    resourceName: heroVideoResourceName,
                    fileExtension: "mp4",
                    fallbackImageAssetName: heroImageAssetName
                )
            }

            return .image(assetName: heroImageAssetName ?? "HomePetHeroMock")
        }

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
            heroVideoResourceName: String? = nil,
            profileNumber: String? = nil,
            microchipNumber: String? = nil,
            birthday: String? = nil,
            arrivalDate: String? = nil,
            weightGrams: Int? = nil,
            neuterStatus: PetNeuterStatus? = nil,
            personalityTags: [String] = [],
            note: String? = nil,
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
            self.heroVideoResourceName = heroVideoResourceName
            self.profileNumber = profileNumber
            self.microchipNumber = microchipNumber
            self.birthday = birthday
            self.arrivalDate = arrivalDate
            self.weightGrams = weightGrams
            self.neuterStatus = neuterStatus
            self.personalityTags = personalityTags
            self.note = note
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
            case heroVideoResourceName = "hero_video_resource_name"
            case profileNumber = "profile_number"
            case microchipNumber = "microchip_number"
            case birthday
            case arrivalDate = "arrival_date"
            case weightGrams = "weight_grams"
            case neuterStatus = "neuter_status"
            case personalityTags = "personality_tags"
            case note
            case companionshipDays = "companionship_days"
            case stats
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            species = try container.decode(Species.self, forKey: .species)
            breed = try container.decode(String.self, forKey: .breed)
            sex = try container.decode(Sex.self, forKey: .sex)
            ageText = try container.decode(String.self, forKey: .ageText)
            statusText = try container.decode(String.self, forKey: .statusText)
            updatedText = try container.decode(String.self, forKey: .updatedText)
            avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL)
            heroImageAssetName = try container.decodeIfPresent(String.self, forKey: .heroImageAssetName)
            heroVideoResourceName = try container.decodeIfPresent(String.self, forKey: .heroVideoResourceName)
            profileNumber = try container.decodeIfPresent(String.self, forKey: .profileNumber)
            microchipNumber = try container.decodeIfPresent(String.self, forKey: .microchipNumber)
            birthday = try container.decodeIfPresent(String.self, forKey: .birthday)
            arrivalDate = try container.decodeIfPresent(String.self, forKey: .arrivalDate)
            weightGrams = try container.decodeIfPresent(Int.self, forKey: .weightGrams)
            neuterStatus = try container.decodeIfPresent(PetNeuterStatus.self, forKey: .neuterStatus)
            personalityTags = try container.decodeIfPresent([String].self, forKey: .personalityTags) ?? []
            note = try container.decodeIfPresent(String.self, forKey: .note)
            companionshipDays = try container.decodeIfPresent(Int.self, forKey: .companionshipDays)
            stats = try container.decodeIfPresent(PetHeroStats.self, forKey: .stats)
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
        let profileNumber: String?
        let microchipNumber: String?
        let birthday: String?
        let arrivalDate: String?
        let weightGrams: Int?
        let neuterStatus: PetNeuterStatus?
        let personalityTags: [String]
        let note: String?
        let isSelected: Bool

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case species
            case avatarURL = "avatar_url"
            case profileNumber = "profile_number"
            case microchipNumber = "microchip_number"
            case birthday
            case arrivalDate = "arrival_date"
            case weightGrams = "weight_grams"
            case neuterStatus = "neuter_status"
            case personalityTags = "personality_tags"
            case note
            case isSelected = "is_selected"
        }

        init(
            id: String,
            name: String,
            species: Species,
            avatarURL: String?,
            profileNumber: String? = nil,
            microchipNumber: String? = nil,
            birthday: String? = nil,
            arrivalDate: String? = nil,
            weightGrams: Int? = nil,
            neuterStatus: PetNeuterStatus? = nil,
            personalityTags: [String] = [],
            note: String? = nil,
            isSelected: Bool
        ) {
            self.id = id
            self.name = name
            self.species = species
            self.avatarURL = avatarURL
            self.profileNumber = profileNumber
            self.microchipNumber = microchipNumber
            self.birthday = birthday
            self.arrivalDate = arrivalDate
            self.weightGrams = weightGrams
            self.neuterStatus = neuterStatus
            self.personalityTags = personalityTags
            self.note = note
            self.isSelected = isSelected
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            species = try container.decode(Species.self, forKey: .species)
            avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL)
            profileNumber = try container.decodeIfPresent(String.self, forKey: .profileNumber)
            microchipNumber = try container.decodeIfPresent(String.self, forKey: .microchipNumber)
            birthday = try container.decodeIfPresent(String.self, forKey: .birthday)
            arrivalDate = try container.decodeIfPresent(String.self, forKey: .arrivalDate)
            weightGrams = try container.decodeIfPresent(Int.self, forKey: .weightGrams)
            neuterStatus = try container.decodeIfPresent(PetNeuterStatus.self, forKey: .neuterStatus)
            personalityTags = try container.decodeIfPresent([String].self, forKey: .personalityTags) ?? []
            note = try container.decodeIfPresent(String.self, forKey: .note)
            isSelected = try container.decode(Bool.self, forKey: .isSelected)
        }
    }
}
