import Foundation

// AIAssistantReferenceLabelSet AI 引用标签集合
// 核心职责：
// - 清洗旧式字符串引用标签
// - 按展示顺序去重，避免同一引用标签重复渲染
enum AIAssistantReferenceLabelSet {
    static func uniqueLabels(from labels: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for label in labels {
            let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedLabel.isEmpty == false else { continue }
            guard seen.insert(trimmedLabel).inserted else { continue }
            result.append(trimmedLabel)
        }

        return result
    }
}
