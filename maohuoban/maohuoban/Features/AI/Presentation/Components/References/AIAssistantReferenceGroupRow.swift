import SwiftUI
import MaohuobanDesignSystem

// AIAssistantReferenceGroupRow 引用聚合行
// 核心职责：
// - 展示聚合后的引用入口
// - 展开后承载每条来源明细
struct AIAssistantReferenceGroupRow: View {
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
