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
    }
}

// RoutePayload 轻提示路由参数
// 核心职责：
// - 承载 route_payload 中的 event_id、episode_id、record_id、task_id 等路由参数
// - 使用宽松解码，未知的 key 自动忽略
struct AttentionHintRoutePayload: Decodable, Equatable {
    let eventID: String?
    let episodeID: String?
    let agentFollowupID: String?
    let defaultAction: String?
    let actions: [AttentionHintAction]
    let recordID: String?
    let taskID: String?
    let sourceHintID: String?

    enum CodingKeys: String, CodingKey {
        case eventID = "event_id"
        case episodeID = "episode_id"
        case agentFollowupID = "agent_followup_id"
        case defaultAction = "default_action"
        case actions
        case recordID = "record_id"
        case taskID = "task_id"
        case sourceHintID = "source_hint_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        eventID = try container.decodeIfPresent(String.self, forKey: .eventID)
        episodeID = try container.decodeIfPresent(String.self, forKey: .episodeID)
        agentFollowupID = try container.decodeIfPresent(String.self, forKey: .agentFollowupID)
        defaultAction = try container.decodeIfPresent(String.self, forKey: .defaultAction)
        actions = try container.decodeIfPresent([AttentionHintAction].self, forKey: .actions) ?? []
        recordID = try container.decodeIfPresent(String.self, forKey: .recordID)
        taskID = try container.decodeIfPresent(String.self, forKey: .taskID)
        sourceHintID = try container.decodeIfPresent(String.self, forKey: .sourceHintID)
    }
}

// AttentionHintAction 轻提示动作
// 核心职责：
// - 承载后端下发的轻提醒动作语义
// - 让首页 UI 可渲染多个文字按钮并按动作路由
struct AttentionHintAction: Decodable, Equatable, Identifiable {
    let id: String
    let title: String
    let routeKind: HomeDashboardSnapshot.AttentionHint.RouteKind
    let presentation: AttentionHintActionPresentation?
    let chatContext: AttentionHintChatContext?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case routeKind = "route_kind"
        case presentation
        case chatContext = "chat_context"
    }
}

// AttentionHintActionPresentation 轻提示动作呈现参数
// 核心职责：
// - 承载前端路由后的呈现意图
// - 例如进入异常详情后自动打开追加观察 Sheet
struct AttentionHintActionPresentation: Decodable, Equatable {
    let autoOpenSheet: String?

    enum CodingKeys: String, CodingKey {
        case autoOpenSheet = "auto_open_sheet"
    }
}

// AttentionHintChatContext 轻提示聊天上下文
// 核心职责：
// - 绑定由轻提醒进入的 Agent 会话上下文
// - 保留 episode 与 followup 关联，供后续聊天页渲染事件卡片
struct AttentionHintChatContext: Decodable, Equatable {
    let kind: String?
    let episodeID: String?
    let sourceHintID: String?
    let agentFollowupID: String?

    enum CodingKeys: String, CodingKey {
        case kind
        case episodeID = "episode_id"
        case sourceHintID = "source_hint_id"
        case agentFollowupID = "agent_followup_id"
    }
}
