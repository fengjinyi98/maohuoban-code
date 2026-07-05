import Foundation

// AIAssistantTableBlock AI 表格语义块
// 核心职责：
// - 承载模型 Markdown 表格的列和行
// - 为移动端横向滚动表格提供稳定 DTO
struct AIAssistantTableBlock: Decodable, Equatable, Hashable, Identifiable {
    let id: String
    let columns: [String]
    let rows: [AIAssistantTableRowBlock]
}
