import SwiftUI
import MaohuobanDesignSystem

// AIAssistantReferenceChipFlow AI 回答引用标签流
// 核心职责：
// - 在消息气泡内展示紧凑来源标签
// - 支持标签自动换行以适配窄屏
struct AIAssistantReferenceChipFlow: View {
    let chips: [String]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: MHBTheme.Spacing.s2) {
                referenceChips
            }

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                referenceChips
            }
        }
    }

    private var referenceChips: some View {
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
