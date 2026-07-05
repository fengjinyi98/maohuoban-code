import SwiftUI
import MaohuobanDesignSystem

// AIAssistantRichTextLineView AI 富文本行
// 核心职责：
// - 渲染受控 inline span
// - 统一段落、列表、引用和表格单元格的强调样式
struct AIAssistantRichTextLineView: View {
    let spans: [AIAssistantInlineTextSpan]
    let font: Font
    let color: Color
    let lineSpacing: CGFloat

    var body: some View {
        Text(attributedText)
            .font(font)
            .foregroundStyle(color)
            .lineSpacing(lineSpacing)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var attributedText: AttributedString {
        spans.reduce(into: AttributedString()) { partial, span in
            var attributedSpan = AttributedString(span.text)
            if span.style == .strong {
                attributedSpan.inlinePresentationIntent = .stronglyEmphasized
            }
            partial += attributedSpan
        }
    }
}
