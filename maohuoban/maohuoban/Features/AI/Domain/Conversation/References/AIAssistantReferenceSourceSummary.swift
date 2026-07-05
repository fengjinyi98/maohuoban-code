import Foundation

// AIAssistantReferenceSourceSummary AI 引用来源汇总
// 核心职责：
// - 将多条引用按后端来源类型汇总为消息底部入口
// - 为来源入口提供稳定图标、标题和数量文案
struct AIAssistantReferenceSourceSummary: Identifiable, Hashable {
    let sourceKind: String
    let sourceTitle: String
    let systemImage: String
    let count: Int

    var id: String { sourceKind }

    var displayText: String {
        count > 1 ? "\(sourceTitle) \(count)" : sourceTitle
    }

    static func summaries(from references: [AIAssistantReference]) -> [AIAssistantReferenceSourceSummary] {
        var summaries: [AIAssistantReferenceSourceSummary] = []

        for reference in references {
            let presentation = AIAssistantReferenceSourcePresentation(reference: reference)
            if let index = summaries.firstIndex(where: { $0.sourceKind == reference.sourceKind }) {
                let existing = summaries[index]
                summaries[index] = AIAssistantReferenceSourceSummary(
                    sourceKind: existing.sourceKind,
                    sourceTitle: existing.sourceTitle,
                    systemImage: existing.systemImage,
                    count: existing.count + 1
                )
            } else {
                summaries.append(
                    AIAssistantReferenceSourceSummary(
                        sourceKind: reference.sourceKind,
                        sourceTitle: presentation.sourceTitle,
                        systemImage: presentation.systemImage,
                        count: 1
                    )
                )
            }
        }

        return summaries
    }
}
