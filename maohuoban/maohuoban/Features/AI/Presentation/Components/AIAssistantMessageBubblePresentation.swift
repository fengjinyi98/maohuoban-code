import Foundation

// AIAssistantMessageBubblePresentation AI 消息气泡展示策略
// 核心职责：
// - 决定结构化内容块与自然语言正文是否展示
// - 保证最终回答正文不会因 UI 内容块存在而被隐藏
struct AIAssistantMessageBubblePresentation {
    let message: AIAssistantMessage

    var shouldShowContentBlocks: Bool {
        message.contentBlocks.isEmpty == false
    }

    var shouldShowText: Bool {
        message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && hasParagraphContentBlock == false
    }

    var shouldShowEmptyStreamingIndicator: Bool {
        shouldShowText == false
            && message.isStreaming
            && shouldShowContentBlocks == false
    }

    private var hasParagraphContentBlock: Bool {
        message.contentBlocks.contains { block in
            if case .paragraph = block {
                return true
            }
            return false
        }
    }
}
