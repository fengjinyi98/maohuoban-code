import SwiftUI
import MaohuobanDesignSystem

// AIAssistantTableRowView AI 表格行
// 核心职责：
// - 按固定单元格宽度渲染一行表格
// - 区分表头与正文行的背景和文字强调
struct AIAssistantTableRowView: View {
    let cells: [AIAssistantRichTextLineBlock]
    let isHeader: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                AIAssistantTableCellView(cell: cell, isHeader: isHeader)
            }
        }
        .background(isHeader ? MHBTheme.ColorToken.separatorSoft.color : Color.clear)
    }
}
