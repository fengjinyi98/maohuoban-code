import Foundation

// AIAssistantMessageTimelinePresentation AI 消息时间线展示策略
// 核心职责：
// - 决定异常追踪上下文中哪条助手消息展示主动追问标签
// - 保持消息标签选择为纯派生逻辑
struct AIAssistantMessageTimelinePresentation {
    let messages: [AIAssistantMessage]
    let hasAbnormalEpisodeContext: Bool

    func shouldShowProactiveFollowupBadge(for message: AIAssistantMessage) -> Bool {
        guard hasAbnormalEpisodeContext,
              message.role == .assistant,
              message.id == latestCompletedAssistantMessageID
        else {
            return false
        }
        return true
    }

    private var latestCompletedAssistantMessageID: UUID? {
        messages.reversed().first { message in
            message.role == .assistant && message.isStreaming == false
        }?.id
    }
}
