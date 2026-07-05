import SwiftUI
import MaohuobanDesignSystem

// AIAssistantLegacyReferenceChipFlow 旧式引用标签流
// 核心职责：
// - 展示缺少 source_id 的普通引用标签
// - 保持诊断和旧测试消息的轻量展示
struct AIAssistantLegacyReferenceChipFlow: View {
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
