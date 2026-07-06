import Foundation

// AIAssistantMessageBubblePresentation AI 消息气泡展示策略
// 核心职责：
// - 决定结构化内容块与自然语言正文是否展示
// - 避免正文 Markdown 投影块与原始文本重复展示
struct AIAssistantMessageBubblePresentation {
    let message: AIAssistantMessage

    var shouldShowContentBlocks: Bool {
        message.contentBlocks.isEmpty == false
    }

    var shouldShowText: Bool {
        message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && hasMarkdownAnswerContentBlock == false
    }

    var shouldShowEmptyStreamingIndicator: Bool {
        shouldShowText == false
            && message.isStreaming
            && shouldShowContentBlocks == false
    }

    private var hasMarkdownAnswerContentBlock: Bool {
        message.contentBlocks.contains { block in
            block.isMarkdownAnswerContent
        }
    }
}
