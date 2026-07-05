import Foundation

// AIAssistantTableRowBlock AI 表格行语义块
// 核心职责：
// - 承载表格一行单元格
// - 保持单元格数量与列定义一致由后端保证
struct AIAssistantTableRowBlock: Decodable, Equatable, Hashable {
    let cells: [AIAssistantRichTextLineBlock]
}
