import SwiftUI
import MaohuobanDesignSystem

// AIAssistantTableBlockView AI 表格内容块
// 核心职责：
// - 渲染受控 Markdown 表格
// - 在窄屏中提供横向滚动承载多列内容
struct AIAssistantTableBlockView: View {
    let block: AIAssistantTableBlock

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                AIAssistantTableRowView(
                    cells: block.columns.map { column in
                        AIAssistantRichTextLineBlock(
                            text: column,
                            spans: [AIAssistantInlineTextSpan(text: column, style: .strong)]
                        )
                    },
                    isHeader: true
                )
                ForEach(Array(block.rows.enumerated()), id: \.offset) { _, row in
                    AIAssistantTableRowView(cells: row.cells, isHeader: false)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: MHBTheme.Radius.small, style: .continuous)
                    .stroke(MHBTheme.ColorToken.separator.color, lineWidth: 1)
            }
        }
        .accessibilityIdentifier("ai.assistant.block.table")
    }
}
