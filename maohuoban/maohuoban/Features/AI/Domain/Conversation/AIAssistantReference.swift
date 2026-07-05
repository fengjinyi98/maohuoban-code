import Foundation

// AIAssistantReference AI 回答引用
// 核心职责：
// - 承载回答引用的来源类型、来源 ID 和展示标签
// - 作为实时消息和历史消息的统一引用模型
struct AIAssistantReference: Identifiable, Hashable {
    let sourceKind: String
    let sourceID: UUID
    let label: String

    var id: String {
        "\(sourceKind):\(sourceID.uuidString)"
    }

    var normalizedTitle: String {
        let parts = label.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        return String(parts.first ?? Substring(label)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedSubtitle: String? {
        let parts = label.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        let subtitle = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
        return subtitle.isEmpty ? nil : subtitle
    }
}
