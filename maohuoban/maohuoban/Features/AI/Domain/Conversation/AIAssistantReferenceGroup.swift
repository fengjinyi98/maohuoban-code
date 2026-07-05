import Foundation

// AIAssistantReferenceGroup AI 回答引用聚合
// 核心职责：
// - 将相同语义引用折叠为一条展示入口
// - 保留聚合内每条可追溯来源供展开查看
struct AIAssistantReferenceGroup: Identifiable, Hashable {
    let sourceKind: String
    let title: String
    let subtitle: String?
    var references: [AIAssistantReference]

    var id: String {
        "\(sourceKind):\(title):\(subtitle ?? "")"
    }

    var displayText: String {
        "引用了\(title)的 \(references.count) 条数据"
    }

    static func groups(from references: [AIAssistantReference]) -> [AIAssistantReferenceGroup] {
        var groups: [AIAssistantReferenceGroup] = []

        for reference in references {
            let title = reference.normalizedTitle
            let subtitle = reference.normalizedSubtitle
            if let index = groups.firstIndex(where: {
                $0.sourceKind == reference.sourceKind
                    && $0.title == title
                    && $0.subtitle == subtitle
            }) {
                var group = groups[index]
                guard group.references.contains(where: { $0.sourceID == reference.sourceID }) == false else {
                    continue
                }
                group.references.append(reference)
                groups[index] = group
            } else {
                groups.append(
                    AIAssistantReferenceGroup(
                        sourceKind: reference.sourceKind,
                        title: title,
                        subtitle: subtitle,
                        references: [reference]
                    )
                )
            }
        }

        return groups
    }
}
