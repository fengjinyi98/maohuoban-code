import Foundation

// AttentionHint 首页轻提示读模型
// 核心职责：
// - 承载后端 attention_hints 字段的稳定解码结构
// - 含 kind、tone、priority、sourceRef、route，让客户端可直接映射展示
// - 边界：attention_hints 是待处理信号，不是事实账本；与 Reminder 独立
extension HomeDashboardSnapshot {
    struct AttentionHint: Decodable, Equatable, Identifiable {
        let id: String
        let petID: String
        let kind: Kind
        let title: String
        let subtitle: String
        let icon: String
        let tone: Tone
        let priority: Int
        let status: Status
        let sourceRefType: String?
        let sourceRefID: String?
        let route: Route
        let displayFrom: String?
        let displayUntil: String?
        let createdBy: String
        let createdAt: String
        let updatedAt: String
        let resolvedAt: String?

        enum CodingKeys: String, CodingKey {
            case id
            case petID = "pet_id"
            case kind
            case title
            case subtitle
            case icon
            case tone
            case priority
            case status
            case sourceRefType = "source_ref_type"
            case sourceRefID = "source_ref_id"
            case route
            case displayFrom = "display_from"
            case displayUntil = "display_until"
            case createdBy = "created_by"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
            case resolvedAt = "resolved_at"
        }
    }
}

extension HomeDashboardSnapshot.AttentionHint {
    // Kind 轻提示类型
    // 核心职责：
    // - 映射后端 attention_hints.kind 枚举
    // - 让客户端按类型选择图标和路由
    enum Kind: String, Decodable, Equatable {
        case openAbnormalEpisode = "open_abnormal_episode"
        case abnormalFollowupDue = "abnormal_followup_due"
        case dietChangeConfirmation = "diet_change_confirmation"
        case preventiveCareDue = "preventive_care_due"
        case reminderDue = "reminder_due"
        case weightStale = "weight_stale"
        case feedingPatternChanged = "feeding_pattern_changed"
    }

    // Tone 轻提示色调
    enum Tone: String, Decodable, Equatable {
        case info
        case notice
        case warning
        case critical
    }

    // Status 轻提示状态
    enum Status: String, Decodable, Equatable {
        case active
        case dismissed
        case resolved
        case expired
    }

    // Route 轻提示点击路由
    struct Route: Decodable, Equatable {
        let kind: RouteKind
        let payload: AttentionHintRoutePayload?

        enum CodingKeys: String, CodingKey {
            case kind
            case payload
        }
    }

    enum RouteKind: String, Decodable, Equatable {
        case abnormalDetail = "abnormal_detail"
        case confirmationTask = "confirmation_task"
        case reminderDetail = "reminder_detail"
        case preventiveCareDetail = "preventive_care_detail"
        case weightRecord = "weight_record"
        case aiChat = "ai_chat"
        case pantryItemDetail = "pantry_item_detail"
    }
}

// RoutePayload 轻提示路由参数
// 核心职责：
// - 承载 route_payload 中的 episode_id、record_id、task_id 等路由参数
// - 使用宽松解码，未知的 key 自动忽略
struct AttentionHintRoutePayload: Decodable, Equatable {
    let episodeID: String?
    let recordID: String?
    let taskID: String?
    let sourceHintID: String?
    let foodItemID: String?
    let inventoryPromptKind: String?

    enum CodingKeys: String, CodingKey {
        case episodeID = "episode_id"
        case recordID = "record_id"
        case taskID = "task_id"
        case sourceHintID = "source_hint_id"
        case foodItemID = "food_item_id"
        case inventoryPromptKind = "inventory_prompt_kind"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        episodeID = try container.decodeIfPresent(String.self, forKey: .episodeID)
        recordID = try container.decodeIfPresent(String.self, forKey: .recordID)
        taskID = try container.decodeIfPresent(String.self, forKey: .taskID)
        sourceHintID = try container.decodeIfPresent(String.self, forKey: .sourceHintID)
        foodItemID = try container.decodeIfPresent(String.self, forKey: .foodItemID)
        inventoryPromptKind = try container.decodeIfPresent(String.self, forKey: .inventoryPromptKind)
    }
}
