import SwiftUI
import Foundation
import MaohuobanDesignSystem

// AIAssistantParagraphBlockView AI 正文段落
// 核心职责：
// - 将语义段落渲染为对话流正文
// - 保持与普通 AI 回复一致的阅读节奏
struct AIAssistantParagraphBlockView: View {
    let text: String
    let spans: [AIAssistantInlineTextSpan]

    init(
        text: String,
        spans: [AIAssistantInlineTextSpan]
    ) {
        self.text = text
        self.spans = spans
    }

    var body: some View {
        Text(paragraphAttributedText)
            .font(MHBTheme.Typography.headline.weight(.regular))
            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("ai.assistant.block.paragraph")
    }

    private var paragraphAttributedText: AttributedString {
        spans.reduce(into: AttributedString()) { partial, span in
            var attributedSpan = AttributedString(span.text)
            if span.style == .strong {
                attributedSpan.inlinePresentationIntent = .stronglyEmphasized
            }
            partial += attributedSpan
        }
    }
}
