import Foundation

extension HomeDashboardSnapshot {
    // MerchantDashboardSummary 商家首页工作台摘要
    // 核心职责：
    // - 承载认证商家的多宠经营状态
    // - 为窝次、待办和在售状态提供首页入口
    struct MerchantDashboardSummary: Decodable, Equatable {
        let merchantID: String
        let merchantName: String
        let statusCounts: [StatusCount]
        let litters: [LitterSummary]
        let pendingTasks: [Reminder]
        let recentEvents: [TimelineEvent]

        enum CodingKeys: String, CodingKey {
            case merchantID = "merchant_id"
            case merchantName = "merchant_name"
            case statusCounts = "status_counts"
            case litters
            case pendingTasks = "pending_tasks"
            case recentEvents = "recent_events"
        }
    }

    // StatusCount 商家宠物状态统计
    // 核心职责：
    // - 表达多宠状态看板数量
    // - 支持按状态进入筛选
    struct StatusCount: Decodable, Equatable, Identifiable {
        var id: MerchantPetStatus { status }
        let status: MerchantPetStatus
        let title: String
        let count: Int
    }

    // MerchantPetStatus 商家宠物状态
    // 核心职责：
    // - 固定商家多宠状态枚举
    // - 支持在售、预定和待补记录等入口
    enum MerchantPetStatus: String, Decodable, Equatable {
        case available
        case reserved
        case sold
        case needsExam = "needs_exam"
        case needsRecord = "needs_record"
    }

    // LitterSummary 商家窝次摘要
    // 核心职责：
    // - 承载首页窝次入口展示数据
    // - 保留父母关系和可售数量摘要
    struct LitterSummary: Decodable, Equatable, Identifiable {
        let id: String
        let name: String
        let parentText: String
        let bornText: String
        let availableCount: Int

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case parentText = "parent_text"
            case bornText = "born_text"
            case availableCount = "available_count"
        }
    }

    // EmptyState 首页空态
    // 核心职责：
    // - 表达无宠物和商家引导场景
    // - 提供明确主操作
    struct EmptyState: Decodable, Equatable {
        let kind: Kind
        let title: String
        let subtitle: String
        let primaryAction: Action

        enum CodingKeys: String, CodingKey {
            case kind
            case title
            case subtitle
            case primaryAction = "primary_action"
        }

        enum Kind: String, Decodable, Equatable {
            case createFirstPet = "create_first_pet"
            case importTradePet = "import_trade_pet"
            case verifyMerchant = "verify_merchant"
            case addMerchantPet = "add_merchant_pet"
        }
    }

    // RecommendedContent 空态推荐内容
    // 核心职责：
    // - 为新用户首页提供辅助内容
    // - 保持创建宠物为主操作
    struct RecommendedContent: Decodable, Equatable, Identifiable {
        let id: String
        let kind: Kind
        let title: String
        let sourceText: String

        enum CodingKeys: String, CodingKey {
            case id
            case kind
            case title
            case sourceText = "source_text"
        }

        enum Kind: String, Decodable, Equatable {
            case ugc
            case guide
            case localService = "local_service"
        }
    }
}

