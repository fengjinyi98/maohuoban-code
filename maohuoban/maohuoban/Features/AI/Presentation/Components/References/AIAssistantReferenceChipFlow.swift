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

// AIAssistantLegacyReferenceChipFlow 旧式引用标签流
// 核心职责：
// - 展示缺少 source_id 的普通引用标签
// - 保持诊断和旧测试消息的轻量展示
private struct AIAssistantLegacyReferenceChipFlow: View {
    let chips: [String]

    var body: some View {
        let uniqueChips = AIAssistantReferenceLabelSet.uniqueLabels(from: chips)

        ViewThatFits(in: .horizontal) {
            HStack(spacing: MHBTheme.Spacing.s2) {
                chipsContent(uniqueChips)
            }

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                chipsContent(uniqueChips)
            }
        }
    }

    private func chipsContent(_ chips: [String]) -> some View {
        ForEach(chips, id: \.self) { chip in
            Text(chip)
                .font(MHBTheme.Typography.caption)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .lineLimit(1)
                .padding(.horizontal, MHBTheme.Spacing.s2)
                .frame(height: 24)
                .background(MHBTheme.ColorToken.background.color)
                .clipShape(Capsule())
        }
    }
}

// AIAssistantReferenceGroupRow 引用聚合行
// 核心职责：
// - 展示聚合后的引用入口
// - 展开后承载每条来源明细
private struct AIAssistantReferenceGroupRow: View {
    let group: AIAssistantReferenceGroup
    let isExpanded: Bool
    let onToggleExpanded: () -> Void
    let onOpenReference: (AIAssistantReference) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            Button(action: onToggleExpanded) {
                HStack(spacing: MHBTheme.Spacing.s1) {
                    Text(group.displayText)
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        .lineLimit(1)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                }
                .padding(.horizontal, MHBTheme.Spacing.s2)
                .frame(height: 24)
                .background(MHBTheme.ColorToken.background.color)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                    ForEach(group.references) { reference in
                        AIAssistantReferenceItemRow(
                            reference: reference,
                            onOpenReference: onOpenReference
                        )
                    }
                }
            }
        }
    }
}

// AIAssistantReferenceItemRow 引用来源明细行
// 核心职责：
// - 展示单条引用来源标签
// - 将点击意图交给上层路由处理
private struct AIAssistantReferenceItemRow: View {
    let reference: AIAssistantReference
    let onOpenReference: (AIAssistantReference) -> Void

    var body: some View {
        Button {
            onOpenReference(reference)
        } label: {
            HStack(spacing: MHBTheme.Spacing.s1) {
                Text(reference.label)
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .lineLimit(1)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
            }
            .padding(.leading, MHBTheme.Spacing.s2)
        }
        .buttonStyle(.plain)
    }
}
