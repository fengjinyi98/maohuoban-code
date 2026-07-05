import SwiftUI
import MaohuobanDesignSystem

// AIAssistantReferenceChipFlow AI 回答引用标签流
// 核心职责：
// - 在消息气泡内展示可展开引用来源
// - 聚合同语义重复引用并保留明细入口
struct AIAssistantReferenceChipFlow: View {
    let chips: [String]
    let references: [AIAssistantReference]
    let onOpenReference: (AIAssistantReference) -> Void

    @State private var expandedGroupIDs: Set<String> = []

    init(
        chips: [String],
        references: [AIAssistantReference] = [],
        onOpenReference: @escaping (AIAssistantReference) -> Void = { _ in }
    ) {
        self.chips = chips
        self.references = references
        self.onOpenReference = onOpenReference
    }

    var body: some View {
        if references.isEmpty {
            AIAssistantLegacyReferenceChipFlow(chips: chips)
        } else {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                ForEach(AIAssistantReferenceGroup.groups(from: references)) { group in
                    AIAssistantReferenceGroupRow(
                        group: group,
                        isExpanded: expandedGroupIDs.contains(group.id),
                        onToggleExpanded: {
                            toggleGroup(group.id)
                        },
                        onOpenReference: onOpenReference
                    )
                }
            }
        }
    }

    private func toggleGroup(_ groupID: String) {
        if expandedGroupIDs.contains(groupID) {
            expandedGroupIDs.remove(groupID)
        } else {
            expandedGroupIDs.insert(groupID)
        }
    }
}
