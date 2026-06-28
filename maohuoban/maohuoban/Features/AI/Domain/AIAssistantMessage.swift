import Foundation

// AIAssistantMessage AI 助手消息模型
// 核心职责：
// - 表达用户、助手和系统边界提示消息
// - 携带前端可展示的引用标签和稳定身份
// - 通过 isStreaming / streamingRevision 支持流式增量渲染 diff
struct AIAssistantMessage: Identifiable, Hashable {
    enum Role: Hashable {
        case assistant
        case user
        case system
    }

    let id: UUID
    let role: Role
    var text: String {
        didSet {
            streamingRevision += 1
        }
    }
    var referenceChips: [String]
    var isStreaming: Bool
    var activityText: String? {
        didSet {
            streamingRevision += 1
        }
    }
    private(set) var streamingRevision: Int

    init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        referenceChips: [String] = [],
        isStreaming: Bool = false,
        activityText: String? = nil,
        streamingRevision: Int = 0
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.referenceChips = referenceChips
        self.isStreaming = isStreaming
        self.activityText = activityText
        self.streamingRevision = streamingRevision
    }
}
