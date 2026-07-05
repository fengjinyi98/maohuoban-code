import SwiftUI
import MaohuobanDesignSystem

// AIAssistantQuoteBlockView AI 引用内容块
// 核心职责：
// - 渲染模型引用语义
// - 用低强调样式承载确认问题或提示语
struct AIAssistantQuoteBlockView: View {
    let block: AIAssistantQuoteBlock

    var body: some View {
        HStack(alignment: .top, spacing: MHBTheme.Spacing.s3) {
            Rectangle()
                .fill(MHBTheme.ColorToken.primary.color.opacity(0.55))
                .frame(width: 3)
                .clipShape(Capsule())
            AIAssistantRichTextLineView(
                spans: block.spans,
                font: MHBTheme.Typography.callout.weight(.regular),
                color: MHBTheme.ColorToken.labelSecondary.color,
                lineSpacing: 3
            )
        }
        .padding(.vertical, MHBTheme.Spacing.s1)
        .accessibilityIdentifier("ai.assistant.block.quote")
    }
}
