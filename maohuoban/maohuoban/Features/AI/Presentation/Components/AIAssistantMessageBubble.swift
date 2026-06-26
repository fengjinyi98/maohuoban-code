import SwiftUI
import MaohuobanDesignSystem

// AIAssistantMessageBubble AI 助手消息气泡
// 核心职责：
// - 按消息角色渲染用户、助手和系统提示
// - 展示回答引用来源标签
// - 流式输出时展示打字光标
struct AIAssistantMessageBubble: View {
    let message: AIAssistantMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: MHBTheme.Spacing.s2) {
            if message.role == .user {
                Spacer(minLength: MHBTheme.Spacing.s8)
            }

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
                if message.text.isEmpty && message.isStreaming {
                    HStack(spacing: 4) {
                        ThinkingDots()
                    }
                } else {
                    streamingText
                        .font(MHBTheme.Typography.body)
                        .foregroundStyle(foregroundColor)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if message.referenceChips.isEmpty == false && !message.isStreaming {
                    AIAssistantReferenceChipFlow(chips: message.referenceChips)
                }
            }
            .padding(MHBTheme.Spacing.s4)
            .frame(maxWidth: 310, alignment: .leading)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            }

            if message.role != .user {
                Spacer(minLength: MHBTheme.Spacing.s8)
            }
        }
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var streamingText: Text {
        Text(message.text) + Text(message.isStreaming ? " ▋" : "")
    }

    private var backgroundColor: Color {
        switch message.role {
        case .assistant:
            MHBTheme.ColorToken.cardSolid.color
        case .user:
            MHBTheme.ColorToken.primary.color
        case .system:
            MHBTheme.ColorToken.primaryBackgroundSoft.color
        }
    }

    private var foregroundColor: Color {
        switch message.role {
        case .user:
            .white
        case .assistant, .system:
            MHBTheme.ColorToken.labelPrimary.color
        }
    }

    private var borderColor: Color {
        switch message.role {
        case .user:
            Color.clear
        case .assistant, .system:
            MHBTheme.ColorToken.separator.color
        }
    }

    private var accessibilityIdentifier: String {
        switch message.role {
        case .assistant:
            "ai.assistant.message.assistant"
        case .user:
            "ai.assistant.message.user"
        case .system:
            "ai.assistant.message.system"
        }
    }
}
