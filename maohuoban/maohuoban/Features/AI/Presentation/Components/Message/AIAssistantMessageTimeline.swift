import SwiftUI
import MaohuobanDesignSystem

// AIAssistantMessageTimeline AI 对话消息时间线
// 核心职责：
// - 渲染用户与助手消息
// - 展示首条消息时间和后端 agent_activity 进度
// - 承载待确认动作卡片和滚动锚点
struct AIAssistantMessageTimeline: View {
    let messages: [AIAssistantMessage]
    let activeAgentActivityText: String?
    let pendingAction: AIAssistantProposedAction?
    let bottomAnchorID: String
    let onConfirmPendingAction: () -> Void
    let onCancelPendingAction: () -> Void
    let onOpenReference: (AIAssistantReference) -> Void

    var body: some View {
        LazyVStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            if let firstMessageDate = messages.first?.createdAt {
                AIAssistantMessageTimeSeparator(
                    text: AIAssistantMessageTimePresentation(date: firstMessageDate).text
                )
            }

            ForEach(messages) { message in
                AIAssistantMessageBubble(
                    message: message,
                    showsEmptyStreamingIndicator: activeAgentActivityText == nil,
                    onOpenReference: onOpenReference
                )
            }

            if let activeAgentActivityText {
                AIAssistantThinkingStatus(displayText: activeAgentActivityText)
                    .padding(.top, MHBTheme.Spacing.s1)
            }

            if let pendingAction {
                AIAssistantProposedActionCard(
                    action: pendingAction,
                    onConfirm: onConfirmPendingAction,
                    onCancel: onCancelPendingAction
                )
            }

            Color.clear
                .frame(height: 1)
                .id(bottomAnchorID)
        }
    }
}
