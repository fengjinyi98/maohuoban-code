import SwiftUI
import MaohuobanDesignSystem

// AIAssistantTableCellView AI 表格单元格
// 核心职责：
// - 渲染表格单元格富文本
// - 维持稳定宽度和边框避免流式完成后跳动
struct AIAssistantTableCellView: View {
    let cell: AIAssistantRichTextLineBlock
    let isHeader: Bool

    var body: some View {
        AIAssistantRichTextLineView(
            spans: cell.spans,
            font: MHBTheme.Typography.callout.weight(isHeader ? .semibold : .regular),
            color: MHBTheme.ColorToken.labelPrimary.color,
            lineSpacing: 2
        )
        .padding(.horizontal, MHBTheme.Spacing.s3)
        .padding(.vertical, MHBTheme.Spacing.s2)
        .frame(minWidth: 92, maxWidth: 160, alignment: .leading)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(MHBTheme.ColorToken.separator.color)
                .frame(width: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MHBTheme.ColorToken.separator.color)
                .frame(height: 1)
        }
    }
}
