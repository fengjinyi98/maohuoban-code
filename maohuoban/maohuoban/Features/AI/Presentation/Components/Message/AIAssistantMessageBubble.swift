import SwiftUI
import MaohuobanDesignSystem

// AIAssistantMessageBubble AI 助手消息气泡
// 核心职责：
// - 按消息角色渲染用户、助手和系统提示
// - 展示回答引用来源标签
// - 流式输出时展示打字光标
struct AIAssistantMessageBubble: View {
    let message: AIAssistantMessage
    let showsEmptyStreamingIndicator: Bool
    let onOpenReference: (AIAssistantReference) -> Void

    init(
        message: AIAssistantMessage,
        showsEmptyStreamingIndicator: Bool = true,
        onOpenReference: @escaping (AIAssistantReference) -> Void = { _ in }
    ) {
        self.message = message
        self.showsEmptyStreamingIndicator = showsEmptyStreamingIndicator
        self.onOpenReference = onOpenReference
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: MHBTheme.Spacing.s2) {
            if message.role == .user {
                Spacer(minLength: 60)
            }

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
                let presentation = AIAssistantMessageBubblePresentation(message: message)

                if presentation.shouldShowContentBlocks {
                    AIAssistantContentBlockList(blocks: message.contentBlocks)
                }

                if presentation.shouldShowText {
                    streamingText
                } else if presentation.shouldShowEmptyStreamingIndicator {
                    if showsEmptyStreamingIndicator {
                        AIAssistantThinkingStatus(displayText: nil)
                    }
                }

                if !message.isStreaming && message.role == .assistant {
                    if message.references.isEmpty == false {
                        AIAssistantMessageActionsBar(
                            messageText: message.text,
                            references: message.references,
                            onOpenReference: onOpenReference
                        )
                    } else if message.referenceChips.isEmpty == false {
                        AIAssistantLegacyReferenceChipFlow(chips: message.referenceChips)
                    }
                }
            }
            .padding(message.role == .assistant ? 0 : MHBTheme.Spacing.s4)
            .frame(maxWidth: message.role == .assistant ? .infinity : nil, alignment: .leading)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: message.role == .assistant ? 0 : MHBTheme.Radius.large, style: .continuous))
            .overlay {
                if message.role != .assistant && borderColor != .clear {
                    RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                }
            }

            if message.role == .system {
                Spacer(minLength: MHBTheme.Spacing.s8)
            }
        }
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var streamingText: some View {
        AIAssistantInlineTextView(
            text: message.text,
            showsStreamingCursor: message.isStreaming
        )
    }

    private var backgroundColor: Color {
        switch message.role {
        case .assistant:
            Color.clear
        case .user:
            MHBTheme.ColorToken.background.color
        case .system:
            MHBTheme.ColorToken.primaryBackgroundSoft.color
        }
    }

    private var foregroundColor: Color {
        switch message.role {
        case .user:
            MHBTheme.ColorToken.labelPrimary.color
        case .assistant, .system:
            MHBTheme.ColorToken.labelPrimary.color
        }
    }

    private var borderColor: Color {
        switch message.role {
        case .user:
            Color.clear
        case .assistant, .system:
            Color.clear
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

// AIAssistantThinkingStatus AI 回复生成进度提示
// 核心职责：
// - 展示轻量加载动画
// - 消费后端提供的安全进度文案
struct AIAssistantThinkingStatus: View {
    let displayText: String?

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s2) {
            ThinkingDots()
            if let displayText, displayText.isEmpty == false {
                Text(displayText)
                    .font(MHBTheme.Typography.callout.weight(.regular))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("ai.assistant.message.activity")
    }
}
