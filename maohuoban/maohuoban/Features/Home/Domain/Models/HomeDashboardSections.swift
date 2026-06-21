import Foundation

extension HomeDashboardSnapshot {
    // CareSummary 今日照护摘要
    // 核心职责：
    // - 承载首页健康与照护指标
    // - 为照护 section 提供稳定展示数据
    struct CareSummary: Decodable, Equatable {
        let title: String
        let metrics: [CareMetric]
    }

    // CareMetric 今日照护指标
    // 核心职责：
    // - 表达单个照护指标的展示值
    // - 支持客户端按类型选择图标
    struct CareMetric: Decodable, Equatable, Identifiable {
        var id: Kind { kind }
        let kind: Kind
        let title: String
        let valueText: String
        let statusText: String

        enum CodingKeys: String, CodingKey {
            case kind
            case title
            case valueText = "value_text"
            case statusText = "status_text"
        }

        enum Kind: String, Decodable, Equatable {
            case appetite
            case mood
            case excretion
            case weight
        }
    }

    // Reminder 首页提醒摘要
    // 核心职责：
    // - 承载近期待处理提醒
    // - 连接完整提醒模块入口
    struct Reminder: Decodable, Equatable, Identifiable {
        let id: String
        let kind: Kind
        let title: String
        let subtitle: String
        let dueText: String
        let remarks: String?

        enum CodingKeys: String, CodingKey {
            case id
            case kind
            case title
            case subtitle
            case dueText = "due_text"
            case remarks
        }

        enum Kind: String, Decodable, Equatable {
            case vaccine
            case deworming
            case followUp = "follow_up"
            case merchantTask = "merchant_task"
            case completeHealthRecord = "complete_health_record"
        }
    }

    // Action 首页快捷动作
    // 核心职责：
    // - 表达首页可点击业务入口
    // - 为后续路由分发提供稳定语义
    struct Action: Decodable, Equatable, Identifiable {
        var id: Kind { kind }
        let kind: Kind
        let title: String
        let subtitle: String?

        enum Kind: String, Decodable, Equatable {
            case createPet = "create_pet"
            case dailyRecord = "daily_record"
            case walk
            case healthRecord = "health_record"
            case bookHospital = "book_hospital"
            case importTradePet = "import_trade_pet"
            case addMerchantPet = "add_merchant_pet"
            case publishAvailableStatus = "publish_available_status"
        }
    }

    // PartnerRecommendation 今日伙伴推荐
    // 核心职责：
    // - 表达一条宠物关系提示
    // - 将首页关系卡和推荐流解耦
    struct PartnerRecommendation: Decodable, Equatable {
        let petID: String
        let petName: String
        let relationshipKind: RelationshipKind
        let title: String
        let subtitle: String
        let distanceText: String?
        let sex: Sex?

        enum CodingKeys: String, CodingKey {
            case petID = "pet_id"
            case petName = "pet_name"
            case relationshipKind = "relationship_kind"
            case title
            case subtitle
            case distanceText = "distance_text"
            case sex
        }

        enum RelationshipKind: String, Decodable, Equatable {
            case sameLitter = "same_litter"
            case sameCity = "same_city"
            case sameCondition = "same_condition"
            case sameHospital = "same_hospital"
            case sameSource = "same_source"
        }
    }

    // TimelineEvent 首页时间线事件
    // 核心职责：
    // - 承载最近关键事件摘要
    // - 隔离完整宠物事件账本
    struct TimelineEvent: Decodable, Equatable, Identifiable {
        let id: String
        let eventKind: Kind
        let title: String
        let subtitle: String
        let occurredText: String

        enum CodingKeys: String, CodingKey {
            case id
            case eventKind = "event_kind"
            case title
            case subtitle
            case occurredText = "occurred_text"
        }

        enum Kind: String, Decodable, Equatable {
            case daily
            case weight
            case vaccine
            case deworming
            case health
            case merchant
        }
    }

    // PetAlbumItem 宠物相册 (UGC) 相册项
    // 核心职责：
    // - 表达用户发布的、关联宠物的 UGC 相册内容
    // - 驱动首页“专辑”横滑列表渲染
    struct PetAlbumItem: Decodable, Equatable, Identifiable {
        let id: String
        let title: String
        let dateText: String
        let coverImageAssetName: String

        enum CodingKeys: String, CodingKey {
            case id
            case title
            case dateText = "date_text"
            case coverImageAssetName = "cover_image_asset_name"
        }
    }

    // PetGalleryAlbum 宠物精选相册
    // 核心职责：
    // - 表达用户创建的、用于分类整理照片的精选相册
    // - 驱动首页“相册”横滑列表渲染
    struct PetGalleryAlbum: Decodable, Equatable, Identifiable {
        let id: String
        let title: String
        let dateText: String
        let coverImageAssetName: String

        enum CodingKeys: String, CodingKey {
            case id
            case title
            case dateText = "date_text"
            case coverImageAssetName = "cover_image_asset_name"
        }
    }
}
