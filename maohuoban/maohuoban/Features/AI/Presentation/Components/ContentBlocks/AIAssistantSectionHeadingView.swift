import SwiftUI
import MaohuobanDesignSystem

// AIAssistantSectionHeadingView AI 段落标题
// 核心职责：
// - 将语义标题渲染为对话流中的轻标题
// - 避免用 Markdown 解析承担标题样式
struct AIAssistantSectionHeadingView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(MHBTheme.Typography.title.weight(.bold))
            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("ai.assistant.block.heading")
    }
}
